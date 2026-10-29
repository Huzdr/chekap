function Export-ChekapReport {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Result,

        [Parameter(Mandatory)]
        [ValidateSet('uk', 'en')]
        [string]$Language,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [ValidateSet('Html', 'Json')]
        [string[]]$Format = @('Html', 'Json'),

        [string]$Note,

        # The PC passport from Get-ChekapSystemInfo. Without it the report has no passport.
        [hashtable]$SystemInfo
    )

    # A failed write must stop the run with one clear error: without this a failing [IO.File] call only reports the error and the
    # code after it (including the FileInfo of a file that was never written) still runs.
    $ErrorActionPreference = 'Stop'

    # .NET resolves a relative path against the process folder, not against the PowerShell location.
    $folder = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    # CreateDirectory, not New-Item -Force: New-Item stays silent when a file sits in the way of the path.
    $null = [System.IO.Directory]::CreateDirectory($folder)

    $now = Get-Date
    $computer = @($SystemInfo.ComputerName, $Result[0].ComputerName, $env:COMPUTERNAME) | Where-Object { $_ } | Select-Object -First 1
    $baseName = 'Chekap-{0}-{1}' -f $computer, $now.ToString('yyyyMMdd-HHmm', [cultureinfo]::InvariantCulture)
    # Never overwrite a report: if the html or the json of this minute exists, both files of this run take -2, -3, ...
    $suffix = 1
    while ((Test-Path -LiteralPath (Join-Path $folder "$baseName.html") -PathType Leaf) -or (Test-Path -LiteralPath (Join-Path $folder "$baseName.json") -PathType Leaf)) {
        $suffix++
        $baseName = 'Chekap-{0}-{1}-{2}' -f $computer, $now.ToString('yyyyMMdd-HHmm', [cultureinfo]::InvariantCulture), $suffix
    }

    # Every value goes through the converter first: dates become ISO 8601 text and arrays stay arrays on both engines.
    $document = [ordered]@{
        schemaVersion = 1
        chekapVersion = $ExecutionContext.SessionState.Module.Version.ToString()
        generated     = $now.ToString('o')
        language      = $Language
        computer      = [string]$computer
        note          = if ($Note) { $Note } else { $null }
        system        = ConvertTo-ChekapJsonValue -Value $SystemInfo
        results       = ConvertTo-ChekapJsonValue -Value @($Result)
    }

    $utf8 = New-Object System.Text.UTF8Encoding $false
    foreach ($kind in $Format | Select-Object -Unique) {
        if ($kind -eq 'Json') {
            $text = ConvertTo-Json -InputObject $document -Depth 8
        }
        else {
            $table = Get-ChekapStringTable -Language $Language
            $document['strings'] = [ordered]@{}
            foreach ($key in @($table.Keys | Where-Object { $_ -match '^(Report|Status|Category)\.' } | Sort-Object)) {
                $document['strings'][$key] = [string]$table[$key]
            }
            $json = ConvertTo-Json -InputObject $document -Depth 8
            $document.Remove('strings')
            $templatePath = Join-Path -Path $ExecutionContext.SessionState.Module.ModuleBase -ChildPath 'Templates/report.html'
            $template = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
            # Escaping "<" keeps "</script>" in a printer name from closing the data block. Replace(), not -replace: a "$" in the data is not a pattern.
            $text = $template.Replace('__CHEKAP_DATA__', $json.Replace('<', '\u003c'))
        }
        $path = Join-Path -Path $folder -ChildPath ('{0}.{1}' -f $baseName, $kind.ToLowerInvariant())
        [System.IO.File]::WriteAllText($path, $text, $utf8)
        New-Object System.IO.FileInfo $path
    }
}

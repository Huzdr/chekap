function Invoke-ChekapCheck {
    [CmdletBinding()]
    [OutputType('Chekap.CheckResult')]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Check,

        [Parameter(Mandatory)]
        [ValidateSet('uk', 'en')]
        [string]$Language
    )

    # Collect and Evaluate inherit this: a non-terminating error must become an Error result, not an OK with a red line.
    # An explicit -ErrorAction in a check still wins.
    $ErrorActionPreference = 'Stop'

    $strings = Get-ChekapStringTable -Language $Language
    $build = Get-ChekapOSBuild

    foreach ($item in $Check) {
        Write-Verbose (Get-ChekapText -Strings $strings -Key 'Core.Verbose.Running' -FormatArgs $item.Id)
        # Shared by every result of this check.
        $base = @{
            Check        = $item
            Title        = Get-ChekapText -Strings $strings -Key "$($item.Id).Title"
            ComputerName = $env:COMPUTERNAME
        }

        if ($item.MinBuild -gt $build) {
            New-ChekapResult @base -Status Skipped `
                -Details (Get-ChekapText -Strings $strings -Key 'Core.Skipped.OldBuild.Details' -FormatArgs $item.MinBuild, $build) `
                -Recommendation (Get-ChekapText -Strings $strings -Key 'Core.Skipped.OldBuild.Recommendation')
            continue
        }
        if ($item.RequiresAdmin -and -not (Test-ChekapAdmin)) {
            New-ChekapResult @base -Status Skipped `
                -Details (Get-ChekapText -Strings $strings -Key 'Core.Skipped.NotAdmin.Details') `
                -Recommendation (Get-ChekapText -Strings $strings -Key 'Core.Skipped.NotAdmin.Recommendation')
            continue
        }

        try {
            # Positional: blocks declare only the parameters they use.
            $data = & $item.Collect $item.Settings
        }
        catch {
            Write-Verbose $_.Exception.ToString()
            New-ChekapResult @base -Status Error `
                -Details (Get-ChekapText -Strings $strings -Key 'Core.Error.Collect.Details' -FormatArgs $_.Exception.Message) `
                -Recommendation (Get-ChekapText -Strings $strings -Key 'Core.Error.Recommendation')
            continue
        }

        try {
            # Built in full first: a bad verdict must not leave a half list of results.
            $verdicts = @(& $item.Evaluate $data $item.Settings | Where-Object { $null -ne $_ })
            $results = @(foreach ($verdict in $verdicts) {
                    $prefix = "$($item.Id).$($verdict.Message)"
                    $verdictArgs = @()
                    if ($null -ne $verdict.Args) { $verdictArgs = @($verdict.Args) }
                    New-ChekapResult @base -Status $verdict.Status -Target $verdict.Target `
                        -Details (Get-ChekapText -Strings $strings -Key "$prefix.Details" -FormatArgs $verdictArgs) `
                        -Recommendation (Get-ChekapText -Strings $strings -Key "$prefix.Recommendation" -Optional) `
                        -Evidence $(if ($verdict.ContainsKey('Evidence')) { $verdict.Evidence } else { $data })
                })
        }
        catch {
            Write-Verbose $_.Exception.ToString()
            New-ChekapResult @base -Status Error `
                -Details (Get-ChekapText -Strings $strings -Key 'Core.Error.Evaluate.Details' -FormatArgs $_.Exception.Message) `
                -Recommendation (Get-ChekapText -Strings $strings -Key 'Core.Error.Recommendation')
            continue
        }
        # A check that says nothing must not vanish from the report.
        if ($results.Count -eq 0) {
            New-ChekapResult @base -Status Error `
                -Details (Get-ChekapText -Strings $strings -Key 'Core.Error.NoVerdict.Details') `
                -Recommendation (Get-ChekapText -Strings $strings -Key 'Core.Error.Recommendation')
            continue
        }
        $results
    }
}

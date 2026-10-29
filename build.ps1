[CmdletBinding()]
param(
    [ValidateSet('Bootstrap', 'Lint', 'Test', 'Build', 'Smoke')]
    [string[]]$Task = @('Lint', 'Test'),

    [string]$TestPath
)

$ErrorActionPreference = 'Stop'

$devModules = @(
    @{ Name = 'Pester'; Version = '5.5.0'; MaxVersion = '5.99.99' }
    @{ Name = 'PSScriptAnalyzer'; Version = '1.21.0' }
    @{ Name = 'platyPS'; Version = '0.14.2'; Exact = $true }
)

# Problems of one built help file as text lines; no output means the file is good.
function Test-HelpXml {
    param(
        [string]$Path,
        [string[]]$ExpectedCommand,
        [bool]$ExpectCyrillic
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "$Path does not exist." }
    $xml = New-Object -TypeName System.Xml.XmlDocument
    try { $xml.Load($Path) }
    catch { return "$Path is not well-formed XML: $($_.Exception.Message)" }

    $actual = @($xml.GetElementsByTagName('command:name') | ForEach-Object { $_.InnerText } | Sort-Object)
    if (($actual -join ', ') -cne (($ExpectedCommand | Sort-Object) -join ', ')) {
        "$Path describes [$($actual -join ', ')] instead of the public commands [$((@($ExpectedCommand | Sort-Object)) -join ', ')]."
    }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($ExpectCyrillic -and $text -notmatch '[Ѐ-ӿ]') { "$Path has no Cyrillic text." }
    # UTF-8 bytes of Cyrillic read as Latin-1 give these letters (Ð, Ñ, Ã). No help text here uses them.
    if ($text -cmatch '[ÃÐÑ]') { "$Path looks garbled (mojibake)." }
}

foreach ($currentTask in $Task) {
    Write-Output "==> $currentTask"
    switch ($currentTask) {
        'Bootstrap' {
            # PSGallery refuses anything older than TLS 1.2, and Windows PowerShell 5.1 may still offer less (older servers). Add it, do not replace.
            if ($PSEdition -eq 'Desktop') { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
            if ($PSEdition -eq 'Desktop' -and -not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Where-Object { $_.Version -ge [version]'2.8.5.201' })) {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
            }
            foreach ($module in $devModules) {
                $wanted = [version]$module.Version
                $found = Get-Module -ListAvailable -Name $module.Name |
                    Where-Object { if ($module.Exact) { $_.Version -eq $wanted } else { $_.Version -ge $wanted -and (-not $module.MaxVersion -or $_.Version -le [version]$module.MaxVersion) } }
                if ($found) { continue }
                $versionArg = if ($module.Exact) { @{ RequiredVersion = $module.Version } } elseif ($module.MaxVersion) { @{ MinimumVersion = $module.Version; MaximumVersion = $module.MaxVersion } } else { @{ MinimumVersion = $module.Version } }
                Install-Module -Name $module.Name @versionArg -Scope CurrentUser -Force -SkipPublisherCheck
            }
        }
        'Lint' {
            # Pin Pester first: analyzing Pester test files makes PSScriptAnalyzer auto-load the newest Pester, which then blocks importing 5.x.
            Import-Module Pester -MinimumVersion 5.5.0 -MaximumVersion 5.99.99
            Import-Module PSScriptAnalyzer -MinimumVersion 1.21.0
            $findings = @(Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings (Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'))
            if ($findings.Count -gt 0) {
                $findings | Format-Table -Property Severity, RuleName, ScriptName, Line, Message -AutoSize -Wrap | Out-String -Width 200 | Write-Output
                throw "PSScriptAnalyzer reported $($findings.Count) finding(s)."
            }
        }
        'Test' {
            Import-Module Pester -MinimumVersion 5.5.0 -MaximumVersion 5.99.99
            $config = New-PesterConfiguration
            $config.Run.Path = if ($TestPath) { $TestPath } else { Join-Path $PSScriptRoot 'tests' }
            $config.Run.Exit = $true
            $config.Output.Verbosity = 'Detailed'
            $config.TestResult.Enabled = $true
            $config.TestResult.OutputPath = Join-Path $PSScriptRoot 'out/testResults.xml'
            Invoke-Pester -Configuration $config
        }
        'Build' {
            Import-Module platyPS -RequiredVersion 0.14.2
            $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'Chekap/Chekap.psd1')
            # The package holds exactly these four files next to the module folder. Check them before anything is deleted.
            $packageFiles = 'Start-Chekap.cmd', 'LICENSE', 'README.md', 'README.uk.md'
            foreach ($name in $packageFiles) {
                if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) { throw "Cannot build the package: $name is missing in the repository root." }
            }

            # Only these three are rebuilt: the rest of out/ holds real reports (out/live, out/smoke) and the test results.
            $null = New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'out') -Force
            $module = Join-Path $PSScriptRoot 'out/Chekap'
            $staging = Join-Path $PSScriptRoot 'out/staging'
            $zip = Join-Path $PSScriptRoot "out/Chekap-$($manifest.ModuleVersion).zip"
            foreach ($path in $module, $staging, $zip) {
                if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
            }

            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Chekap') -Destination $module -Recurse
            $docsFolder = @{ 'en-US' = 'en'; 'uk-UA' = 'uk' }
            foreach ($culture in $docsFolder.Keys) {
                $null = New-ExternalHelp -Path (Join-Path $PSScriptRoot "docs/$($docsFolder[$culture])") -OutputPath (Join-Path $module $culture) -Encoding ([System.Text.Encoding]::UTF8) -Force
            }

            # System.IO.Compression instead of Compress-Archive: the one in Windows PowerShell 5.1 is slow and mishandles some paths.
            # The entries are added one by one: CreateFromDirectory writes backslashes in the entry names there, and other tools then unpack flat files.
            $null = New-Item -ItemType Directory -Path $staging
            $staging = [System.IO.Path]::GetFullPath($staging)
            Copy-Item -LiteralPath $module -Destination (Join-Path $staging 'Chekap') -Recurse
            foreach ($name in $packageFiles) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $staging }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
            try {
                foreach ($file in Get-ChildItem -LiteralPath $staging -Recurse -File) {
                    $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $file.FullName.Substring($staging.Length + 1).Replace('\', '/'))
                }
            }
            finally {
                $archive.Dispose()
            }
            Remove-Item -LiteralPath $staging -Recurse -Force

            $problems = New-Object -TypeName 'System.Collections.Generic.List[string]'
            foreach ($culture in $docsFolder.Keys) {
                foreach ($problem in @(Test-HelpXml -Path (Join-Path $module "$culture/Chekap-help.xml") -ExpectedCommand $manifest.FunctionsToExport -ExpectCyrillic ($culture -eq 'uk-UA'))) { $problems.Add($problem) }
            }
            $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
            try {
                $names = @($archive.Entries | ForEach-Object { $_.FullName })
                if (@($names | Where-Object { $_.Contains('\') }).Count -gt 0) { $problems.Add('The zip has entry names with a backslash.') }
                $top = @($names | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique)
                $expectedTop = @('Chekap') + $packageFiles
                if (@(Compare-Object -ReferenceObject $expectedTop -DifferenceObject $top -CaseSensitive).Count -gt 0) { $problems.Add("The zip holds [$($top -join ', ')] instead of [$($expectedTop -join ', ')].") }
                foreach ($culture in $docsFolder.Keys) {
                    if ($names -notcontains "Chekap/$culture/Chekap-help.xml") { $problems.Add("The zip has no Chekap/$culture/Chekap-help.xml.") }
                }
                $launcher = $archive.GetEntry('Start-Chekap.cmd')
                if ($null -eq $launcher) { $problems.Add('The zip has no Start-Chekap.cmd.') }
                else {
                    $memory = New-Object -TypeName System.IO.MemoryStream
                    $stream = $launcher.Open()
                    try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
                    $original = [System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'Start-Chekap.cmd'))
                    if ([Convert]::ToBase64String($memory.ToArray()) -cne [Convert]::ToBase64String($original)) { $problems.Add('Start-Chekap.cmd in the zip differs from the file in the repository.') }
                }
            }
            finally {
                $archive.Dispose()
            }
            if ($problems.Count -gt 0) {
                # A bad package must not be left where it could be taken for a good one.
                Remove-Item -LiteralPath $zip -Force
                throw "Build self-check failed:`n - $($problems -join "`n - ")"
            }
            Write-Output "Built out/Chekap-$($manifest.ModuleVersion).zip"
        }
        'Smoke' {
            $built = Join-Path $PSScriptRoot 'out/Chekap/Chekap.psd1'
            if (-not (Test-Path -LiteralPath $built -PathType Leaf)) { throw "$built not found. Run build.ps1 -Task Build first." }
            Import-Module $built -Force
            # A real audit of this PC. Its reports stay in out/smoke (git-ignored).
            $results = @(Invoke-ChekapAudit -OutputPath (Join-Path $PSScriptRoot 'out/smoke'))
            Remove-Module Chekap
            # Invoke-ChekapAudit returns silently when no check is loaded: a broken package must not pass.
            if ($results.Count -eq 0) { throw 'Smoke failed: the audit returned no results.' }
            Write-Output ('Smoke: {0} findings. {1}' -f $results.Count, ((@($results | Group-Object -Property Status | Sort-Object -Property Name | ForEach-Object { '{0} {1}' -f $_.Name, $_.Count })) -join ', '))
            $failed = @($results | Where-Object { $_.Status -eq 'Error' })
            foreach ($result in $failed) { Write-Output ('{0}: {1}' -f $result.CheckId, $result.Details) }
            if ($failed.Count -gt 0) { throw "Smoke failed: $($failed.Count) check(s) returned Error." }
        }
    }
}

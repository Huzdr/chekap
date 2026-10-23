[CmdletBinding()]
param(
    [ValidateSet('Bootstrap', 'Lint', 'Test')]
    [string[]]$Task = @('Lint', 'Test'),

    [string]$TestPath
)

$ErrorActionPreference = 'Stop'

$devModules = @(
    @{ Name = 'Pester'; Version = '5.5.0' }
    @{ Name = 'PSScriptAnalyzer'; Version = '1.21.0' }
    @{ Name = 'platyPS'; Version = '0.14.2'; Exact = $true }
)

foreach ($currentTask in $Task) {
    Write-Output "==> $currentTask"
    switch ($currentTask) {
        'Bootstrap' {
            if ($PSEdition -eq 'Desktop' -and -not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Where-Object { $_.Version -ge [version]'2.8.5.201' })) {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
            }
            foreach ($module in $devModules) {
                $wanted = [version]$module.Version
                $found = Get-Module -ListAvailable -Name $module.Name |
                    Where-Object { if ($module.Exact) { $_.Version -eq $wanted } else { $_.Version -ge $wanted } }
                if ($found) { continue }
                $versionArg = if ($module.Exact) { @{ RequiredVersion = $module.Version } } else { @{ MinimumVersion = $module.Version } }
                Install-Module -Name $module.Name @versionArg -Scope CurrentUser -Force -SkipPublisherCheck
            }
        }
        'Lint' {
            Import-Module PSScriptAnalyzer -MinimumVersion 1.21.0
            $findings = @(Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings (Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'))
            if ($findings.Count -gt 0) {
                $findings | Format-Table -Property Severity, RuleName, ScriptName, Line, Message -AutoSize -Wrap | Out-String -Width 200 | Write-Output
                throw "PSScriptAnalyzer reported $($findings.Count) finding(s)."
            }
        }
        'Test' {
            Import-Module Pester -MinimumVersion 5.5.0
            $config = New-PesterConfiguration
            $config.Run.Path = if ($TestPath) { $TestPath } else { Join-Path $PSScriptRoot 'tests' }
            $config.Run.Exit = $true
            $config.Output.Verbosity = 'Detailed'
            $config.TestResult.Enabled = $true
            $config.TestResult.OutputPath = Join-Path $PSScriptRoot 'out/testResults.xml'
            Invoke-Pester -Configuration $config
        }
    }
}

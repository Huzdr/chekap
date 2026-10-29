function Invoke-ChekapAudit {
    # .ExternalHelp Chekap-help.xml
    [CmdletBinding()]
    [OutputType('Chekap.CheckResult')]
    param(
        [ValidateSet('System', 'Network', 'Printing')]
        [string[]]$Category,

        [string[]]$CheckId,

        [ValidateSet('uk', 'en')]
        [string]$Language,

        [string]$OutputPath,

        [ValidateSet('Html', 'Json')]
        [string[]]$Format = @('Html', 'Json'),

        [string]$Note
    )

    # One clear terminating error for a bad folder or a failed write, like the runner does for its checks.
    $ErrorActionPreference = 'Stop'

    $lang = Resolve-ChekapLanguage -Language $Language
    $checks = @(Select-ChekapCheck -Category $Category -CheckId $CheckId -Language $lang)
    # An unknown ID has already been reported by a warning; there is nothing to run and no report to write.
    if ($checks.Count -eq 0) { return }

    if ($OutputPath) {
        # A bad folder must fail now, not after the checks have run for several seconds.
        $OutputPath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        $null = [System.IO.Directory]::CreateDirectory($OutputPath)
    }

    $results = @(Invoke-ChekapCheck -Check $checks -Language $lang)

    if ($OutputPath) {
        $strings = Get-ChekapStringTable -Language $lang
        $files = Export-ChekapReport -Result $results -Language $lang -OutputPath $OutputPath -Format $Format -Note $Note -SystemInfo (Get-ChekapSystemInfo)
        foreach ($file in $files) {
            Write-Verbose (Get-ChekapText -Strings $strings -Key 'Core.Verbose.ReportWritten' -FormatArgs $file.FullName)
        }
    }
    $results
}

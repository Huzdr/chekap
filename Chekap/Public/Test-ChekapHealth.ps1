function Test-ChekapHealth {
    <#
    .SYNOPSIS
    Checks the health of this PC: uptime, pending restart, free disk space, load, memory, crashes and battery.
    .DESCRIPTION
    Runs the System checks and returns one Chekap.CheckResult object per finding. The checks only read data;
    none of them changes the PC or needs administrator rights.
    .PARAMETER Language
    Language of the texts: uk or en. By default the saved setting or the system language.
    .PARAMETER CheckId
    Run only these checks. Exact IDs or wildcards, for example SYS-DISK-001 or SYS-B*.
    .EXAMPLE
    Test-ChekapHealth -Language en
    .EXAMPLE
    Test-ChekapHealth -CheckId SYS-DISK-001, SYS-MEMORY-001 | Format-List
    #>
    [CmdletBinding()]
    [OutputType('Chekap.CheckResult')]
    param(
        [ValidateSet('uk', 'en')]
        [string]$Language,

        [string[]]$CheckId
    )

    $lang = Resolve-ChekapLanguage -Language $Language
    $checks = @(Select-ChekapCheck -Category System -CheckId $CheckId -Language $lang)
    # An unknown ID has already been reported by a warning; the runner needs at least one check.
    if ($checks.Count -eq 0) { return }
    Invoke-ChekapCheck -Check $checks -Language $lang
}

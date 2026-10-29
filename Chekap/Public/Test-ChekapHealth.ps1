function Test-ChekapHealth {
    # .ExternalHelp Chekap-help.xml
    [CmdletBinding()]
    [OutputType('Chekap.CheckResult')]
    param(
        [ValidateSet('uk', 'en')]
        [string]$Language,

        [SupportsWildcards()]
        [string[]]$CheckId
    )

    $lang = Resolve-ChekapLanguage -Language $Language
    $checks = @(Select-ChekapCheck -Category System -CheckId $CheckId -Language $lang)
    # An unknown ID has already been reported by a warning; the runner needs at least one check.
    if ($checks.Count -eq 0) { return }
    Invoke-ChekapCheck -Check $checks -Language $lang
}

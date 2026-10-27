function Test-ChekapPrinting {
    <#
    .SYNOPSIS
    Checks printing on this PC: the Print Spooler service, print queues, printer ports, the default printer, drivers, RPC protection of shared printers and scanners.
    .DESCRIPTION
    Runs the Printing checks and returns one Chekap.CheckResult object per finding. The checks only read data
    and open a few short TCP connections to network printers and print servers; none of them changes the PC or
    needs administrator rights. The names of documents and users in print queues are not collected.
    .PARAMETER Language
    Language of the texts: uk or en. By default the saved setting or the system language.
    .PARAMETER CheckId
    Run only these checks. Exact IDs or wildcards, for example PRN-QUEUE-001 or PRN-*.
    .EXAMPLE
    Test-ChekapPrinting -Language en
    .EXAMPLE
    Test-ChekapPrinting -CheckId PRN-SPOOLER-001, PRN-PORT-* | Format-List
    #>
    [CmdletBinding()]
    [OutputType('Chekap.CheckResult')]
    param(
        [ValidateSet('uk', 'en')]
        [string]$Language,

        [string[]]$CheckId
    )

    $lang = Resolve-ChekapLanguage -Language $Language
    $checks = @(Select-ChekapCheck -Category Printing -CheckId $CheckId -Language $lang)
    # An unknown ID has already been reported by a warning; the runner needs at least one check.
    if ($checks.Count -eq 0) { return }
    Invoke-ChekapCheck -Check $checks -Language $lang
}

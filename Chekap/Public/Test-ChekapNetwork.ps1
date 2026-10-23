function Test-ChekapNetwork {
    <#
    .SYNOPSIS
    Checks the network of this PC: adapters, addresses, gateway, DNS, internet access, proxy, network profile and clock.
    .DESCRIPTION
    Runs the Network checks and returns one Chekap.CheckResult object per finding. The checks only read data
    and send a few small probes (ping to the gateway, DNS queries, one TCP connection); none of them changes
    the PC or needs administrator rights.
    .PARAMETER Language
    Language of the texts: uk or en. By default the saved setting or the system language.
    .PARAMETER CheckId
    Run only these checks. Exact IDs or wildcards, for example NET-DNS-001 or NET-DNS-*.
    .EXAMPLE
    Test-ChekapNetwork -Language en
    .EXAMPLE
    Test-ChekapNetwork -CheckId NET-GATEWAY-001, NET-DNS-* | Format-List
    #>
    [CmdletBinding()]
    [OutputType('Chekap.CheckResult')]
    param(
        [ValidateSet('uk', 'en')]
        [string]$Language,

        [string[]]$CheckId
    )

    $lang = Resolve-ChekapLanguage -Language $Language
    $checks = @(Select-ChekapCheck -Category Network -CheckId $CheckId -Language $lang)
    # An unknown ID has already been reported by a warning; the runner needs at least one check.
    if ($checks.Count -eq 0) { return }
    Invoke-ChekapCheck -Check $checks -Language $lang
}

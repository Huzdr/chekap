@{
    Id            = 'NET-DNS-002'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/dnsclient/resolve-dnsname'
        'https://learn.microsoft.com/windows-server/networking/dns/dns-top'
    )
    Settings      = @{ ExternalName = 'www.microsoft.com' }
    Collect       = {
        param($Settings)
        $system = Get-CimInstance -ClassName Win32_ComputerSystem
        $partOfDomain = [bool]$system.PartOfDomain
        # Any failure of the lookup (no such name, no answer in time) means "does not resolve".
        $resolves = {
            param($name)
            try {
                $null = Resolve-DnsName -Name $name -DnsOnly -QuickTimeout -Type A -ErrorAction Stop
                $true
            }
            catch {
                $false
            }
        }
        # Outside a domain there is no domain name to look up, so the answer stays $null.
        $domainResolves = $null
        if ($partOfDomain) { $domainResolves = & $resolves ([string]$system.Domain) }
        @{
            Domain           = [string]$system.Domain
            PartOfDomain     = $partOfDomain
            DomainResolves   = $domainResolves
            ExternalResolves = & $resolves $Settings.ExternalName
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        $failed = 0
        if ($Data.PartOfDomain -and -not $Data.DomainResolves) {
            $failed++
            @{ Status = 'Critical'; Message = 'DomainFail'; Target = $Data.Domain; Args = @($Data.Domain) }
        }
        if (-not $Data.ExternalResolves) {
            $failed++
            @{ Status = 'Warning'; Message = 'ExternalFail'; Args = @($Settings.ExternalName) }
        }
        if ($failed -eq 0) {
            $names = @($Settings.ExternalName)
            if ($Data.PartOfDomain) { $names = @($Data.Domain) + $names }
            @{ Status = 'OK'; Message = 'Ok'; Args = @(($names -join ', ')) }
        }
    }
}

@{
    Id            = 'NET-DNS-002'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/dnsclient/get-dnsclientserveraddress'
        'https://learn.microsoft.com/windows-server/networking/dns/dns-top'
        'https://www.rfc-editor.org/rfc/rfc1035'
    )
    Settings      = @{ ExternalName = 'www.microsoft.com'; TimeoutMs = 1500 }
    Collect       = {
        param($Settings)
        $system = Get-CimInstance -ClassName Win32_ComputerSystem
        $partOfDomain = [bool]$system.PartOfDomain
        $connected = @(Get-ChekapConnectedInterface | ForEach-Object { $_.Index })
        $servers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -in $connected } | ForEach-Object { $_.ServerAddresses } | Select-Object -Unique)

        # The first configured server that answers is asked for both names, each question bounded by TimeoutMs.
        $server = $null
        $external = $null
        foreach ($candidate in $servers) {
            $answer = Test-ChekapDnsServer -Server $candidate -Name $Settings.ExternalName -TimeoutMs $Settings.TimeoutMs
            if ($answer.Responds) {
                $server = $candidate
                $external = $answer
                break
            }
        }
        # Outside a domain there is no domain name to ask for, so the answer stays $null.
        $domainResolves = $null
        if ($partOfDomain) {
            $domainResolves = $false
            if ($null -ne $server) {
                # Any failure of this probe means that the domain does not resolve; it is never an Error of the check.
                try {
                    $domain = Test-ChekapDnsServer -Server $server -Name ([string]$system.Domain) -TimeoutMs $Settings.TimeoutMs
                    $domainResolves = [bool]($domain.Responds -and $domain.RCode -eq 0 -and $domain.AnswerCount -gt 0)
                }
                catch {
                    Write-Verbose $_.Exception.Message
                }
            }
        }
        @{
            Domain           = [string]$system.Domain
            PartOfDomain     = $partOfDomain
            Server           = $server
            DomainResolves   = $domainResolves
            ExternalResolves = [bool]($null -ne $external -and $external.RCode -eq 0 -and $external.AnswerCount -gt 0)
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

@{
    Id            = 'NET-DNS-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/dnsclient/get-dnsclientserveraddress'
        'https://learn.microsoft.com/windows-server/networking/dns/dns-top'
        'https://www.rfc-editor.org/rfc/rfc1035'
    )
    Settings      = @{
        ProbeName       = 'localhost'
        PublicResolvers = @('8.8.8.8', '8.8.4.4', '1.1.1.1', '1.0.0.1', '9.9.9.9', '149.112.112.112', '208.67.222.222', '208.67.220.220')
        TimeoutMs       = 1500
    }
    Collect       = {
        param($Settings)
        $connected = @(Get-ChekapConnectedInterface | ForEach-Object { $_.Index })
        $servers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -in $connected } | ForEach-Object { $_.ServerAddresses } | Select-Object -Unique)
        # shortcut: servers are asked one after another, each for at most TimeoutMs, so a dozen dead servers still take a while; ask them in parallel if that matters.
        $probe = @{}
        foreach ($server in $servers) {
            # Any reply, even NXDOMAIN or SERVFAIL, shows that the server is alive; only silence is "does not respond".
            $probe[$server] = Test-ChekapDnsServer -Server $server -Name $Settings.ProbeName -TimeoutMs $Settings.TimeoutMs
        }
        @{
            Servers      = $servers
            Probe        = $probe
            PartOfDomain = [bool](Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        $servers = @($Data.Servers)
        if ($servers.Count -eq 0) {
            return @{ Status = 'Critical'; Message = 'NoServers' }
        }
        $list = $servers -join ', '
        if (@($servers | Where-Object { $Data.Probe[$_].Responds }).Count -eq 0) {
            return @{ Status = 'Critical'; Message = 'NoneRespond'; Args = @($list) }
        }
        $problems = 0
        foreach ($server in $servers) {
            if (-not $Data.Probe[$server].Responds) {
                $problems++
                @{ Status = 'Warning'; Message = 'ServerDown'; Target = $server; Args = @($server) }
            }
            # A public resolver cannot answer for the domain, so a domain PC that asks it fails at random.
            if ($Data.PartOfDomain -and $Settings.PublicResolvers -contains $server) {
                $problems++
                @{ Status = 'Warning'; Message = 'PublicOnDomain'; Target = $server; Args = @($server) }
            }
        }
        if ($problems -eq 0) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($list) }
        }
    }
}

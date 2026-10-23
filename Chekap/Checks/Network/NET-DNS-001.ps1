@{
    Id            = 'NET-DNS-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/dnsclient/resolve-dnsname'
        'https://learn.microsoft.com/powershell/module/dnsclient/get-dnsclientserveraddress'
    )
    Settings      = @{
        ProbeName       = 'localhost'
        PublicResolvers = @('8.8.8.8', '8.8.4.4', '1.1.1.1', '1.0.0.1', '9.9.9.9', '149.112.112.112', '208.67.222.222', '208.67.220.220')
    }
    Collect       = {
        param($Settings)
        $connected = @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | ForEach-Object { $_.InterfaceIndex })
        $servers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -in $connected } | ForEach-Object { $_.ServerAddresses } | Select-Object -Unique)
        # shortcut: servers are asked one after another and a dead one costs the QuickTimeout (about 7 s), so many dead servers slow the check; parallel probes if that matters.
        $probe = @{}
        foreach ($server in $servers) {
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            $responds = $false
            try {
                $null = Resolve-DnsName -Name $Settings.ProbeName -Server $server -DnsOnly -QuickTimeout -ErrorAction Stop
                $responds = $true
            }
            catch {
                # Native errors 9001-9999 are DNS response codes (9003 = the name does not exist): the server answered, only not with an address.
                $code = [int]$_.Exception.NativeErrorCode
                $responds = $code -ge 9001 -and $code -le 9999
            }
            $probe[$server] = @{ Responds = $responds; Ms = [int]$timer.ElapsedMilliseconds }
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

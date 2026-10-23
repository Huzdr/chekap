@{
    Id            = 'NET-GATEWAY-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/nettcpip/get-netroute'
    )
    Settings      = @{ TimeoutMs = 1000 }
    Collect       = {
        param($Settings)
        # A PC without a default route makes Get-NetRoute write an error; that is the answer "no gateway".
        $routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Where-Object { $_.NextHop -ne '0.0.0.0' } | ForEach-Object {
                @{ Alias = [string]$_.InterfaceAlias; NextHop = [string]$_.NextHop }
            })
        $ping = @{}
        # Gateways are IP addresses, so the ping needs no name resolution outside its timeout.
        foreach ($gateway in @($routes | ForEach-Object { $_.NextHop } | Sort-Object -Unique)) {
            $ping[$gateway] = Test-ChekapPing -ComputerName $gateway -TimeoutMs $Settings.TimeoutMs
        }
        @{ Routes = $routes; Ping = $ping }
    }
    Evaluate      = {
        param($Data)
        $routes = @($Data.Routes)
        if ($routes.Count -eq 0) {
            return @{ Status = 'Critical'; Message = 'NoGateway' }
        }
        $gateways = @($routes | ForEach-Object { $_.NextHop } | Sort-Object -Unique)
        $interfaces = @($routes | ForEach-Object { $_.Alias } | Sort-Object -Unique)
        # The same router on two adapters is one gateway; two different gateways on two adapters is the case to report.
        if ($gateways.Count -gt 1 -and $interfaces.Count -gt 1) {
            $list = @($routes | ForEach-Object { '{0}: {1}' -f $_.Alias, $_.NextHop } | Sort-Object -Unique) -join '; '
            @{ Status = 'Warning'; Message = 'Multiple'; Args = @($list) }
        }
        foreach ($gateway in $gateways) {
            $reply = $Data.Ping[$gateway]
            $evidence = @{ Gateway = $gateway; Success = [bool]$reply.Success; RoundtripMs = $reply.RoundtripMs }
            if ($reply.Success) {
                @{ Status = 'OK'; Message = 'Ok'; Target = $gateway; Args = @($gateway, $reply.RoundtripMs); Evidence = $evidence }
            }
            else {
                @{ Status = 'Warning'; Message = 'NoReply'; Target = $gateway; Args = @($gateway); Evidence = $evidence }
            }
        }
    }
}

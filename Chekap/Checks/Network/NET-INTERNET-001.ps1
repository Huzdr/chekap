@{
    Id            = 'NET-INTERNET-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows-server/networking/ncsi/ncsi-overview'
        'https://learn.microsoft.com/powershell/module/nettcpip/test-netconnection'
    )
    Settings      = @{ Host = 'www.microsoft.com'; Port = 443; TimeoutMs = 3000 }
    Collect       = {
        param($Settings)
        @{ Reachable = [bool](Test-ChekapTcpPort -ComputerName $Settings.Host -Port $Settings.Port -TimeoutMs $Settings.TimeoutMs) }
    }
    Evaluate      = {
        param($Data, $Settings)
        if ($Data.Reachable) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($Settings.Host, $Settings.Port) }
        }
        else {
            @{ Status = 'Warning'; Message = 'NoInternet'; Args = @($Settings.Host, $Settings.Port) }
        }
    }
}

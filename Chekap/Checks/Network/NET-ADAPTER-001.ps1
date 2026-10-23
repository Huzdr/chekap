@{
    Id            = 'NET-ADAPTER-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/netadapter/get-netadapter'
    )
    Settings      = @{ SlowMbps = 100 }
    Collect       = {
        $adapters = @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | ForEach-Object {
                @{
                    Name        = [string]$_.Name
                    Description = [string]$_.InterfaceDescription
                    MediaType   = [string]$_.MediaType
                    # An adapter that does not know its speed reports the maximum UInt64; clamp it so the cast cannot overflow.
                    SpeedBps    = [long][math]::Min([double]$_.Speed, 9e18)
                }
            })
        @{ Adapters = $adapters }
    }
    Evaluate      = {
        param($Data, $Settings)
        $adapters = @($Data.Adapters)
        if ($adapters.Count -eq 0) {
            @{ Status = 'Critical'; Message = 'NoConnection' }
        }
        else {
            foreach ($adapter in $adapters) {
                $mbps = $adapter.SpeedBps / 1000000
                # Only a wired link is judged: a Wi-Fi speed changes with the signal.
                if ($adapter.MediaType -eq '802.3' -and $mbps -le $Settings.SlowMbps) {
                    @{ Status = 'Warning'; Message = 'SlowLink'; Target = $adapter.Name; Args = @($adapter.Name, $mbps); Evidence = $adapter }
                }
                else {
                    @{ Status = 'OK'; Message = 'Ok'; Target = $adapter.Name; Args = @($adapter.Name, $mbps); Evidence = $adapter }
                }
            }
        }
    }
}

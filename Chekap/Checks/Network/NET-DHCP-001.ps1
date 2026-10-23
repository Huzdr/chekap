@{
    Id            = 'NET-DHCP-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/troubleshoot/windows-server/networking/dhcp-client-fail-obtain-valid-ip-address'
        'https://learn.microsoft.com/powershell/module/nettcpip/get-netipaddress'
    )
    Settings      = @{}
    Collect       = {
        $connected = @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | ForEach-Object { $_.InterfaceIndex })
        # No IPv4 address at all is an error of the cmdlet, not a failure of the check.
        $addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -in $connected } | ForEach-Object {
                @{
                    Alias        = [string]$_.InterfaceAlias
                    IP           = [string]$_.IPAddress
                    PrefixOrigin = [string]$_.PrefixOrigin
                }
            })
        @{ Addresses = $addresses }
    }
    Evaluate      = {
        param($Data)
        $addresses = @($Data.Addresses)
        # shortcut: every 169.254.x.x counts as APIPA, even one typed in by hand (PrefixOrigin Manual); filter on PrefixOrigin if that false alarm matters.
        $apipa = @($addresses | Where-Object { $_.IP -like '169.254.*' })
        if ($apipa.Count -eq 0) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($addresses.Count) }
        }
        else {
            foreach ($address in $apipa) {
                @{ Status = 'Critical'; Message = 'Apipa'; Target = $address.Alias; Args = @($address.Alias, $address.IP); Evidence = $address }
            }
        }
    }
}

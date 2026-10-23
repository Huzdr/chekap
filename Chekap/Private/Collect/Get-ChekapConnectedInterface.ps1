function Get-ChekapConnectedInterface {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Connected = a physical adapter that is Up, plus any interface that holds an IPv4 default route. On a Hyper-V host with an
    # external switch or on a NIC team the address and the DNS servers sit on a vEthernet/team interface, not on the physical NIC;
    # a WSL or Default Switch vEthernet has no default route, so it stays out.
    $found = @{}
    foreach ($adapter in @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')) {
        $found[[int]$adapter.InterfaceIndex] = [string]$adapter.Name
    }
    # No default route at all is an error of the cmdlet, not a failure.
    foreach ($route in @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Where-Object { $_.NextHop -ne '0.0.0.0' })) {
        $index = [int]$route.InterfaceIndex
        if (-not $found.ContainsKey($index)) { $found[$index] = [string]$route.InterfaceAlias }
    }
    # Emits nothing when no interface is connected; callers wrap the call in @().
    foreach ($index in @($found.Keys | Sort-Object)) {
        @{ Index = $index; Alias = $found[$index] }
    }
}

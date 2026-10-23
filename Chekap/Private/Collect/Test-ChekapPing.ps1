function Test-ChekapPing {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [ValidateRange(1, 600000)]
        [int]$TimeoutMs = 1000
    )

    $ping = New-Object System.Net.NetworkInformation.Ping
    try {
        $reply = $ping.Send($ComputerName, $TimeoutMs)
        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            return @{ Success = $true; RoundtripMs = [int]$reply.RoundtripTime }
        }
    }
    catch {
        # An unknown name or an unreachable network throws; that is the same answer as "no reply".
        Write-Verbose $_.Exception.Message
    }
    finally {
        $ping.Dispose()
    }
    @{ Success = $false; RoundtripMs = $null }
}

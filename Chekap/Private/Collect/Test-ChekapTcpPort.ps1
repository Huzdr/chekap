function Test-ChekapTcpPort {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [ValidateRange(1, 600000)]
        [int]$TimeoutMs = 1000
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        # Wait() throws when the connect fails at once (refused, unknown name); that is just "closed".
        $client.ConnectAsync($ComputerName, $Port).Wait($TimeoutMs) -and $client.Connected
    }
    catch {
        $false
    }
    finally {
        $client.Dispose()
    }
}

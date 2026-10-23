function Test-ChekapDnsServer {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Net.IPAddress]$Server,

        # Letters, digits, "_" and "-" in labels of 1-63 characters; a trailing dot is fine.
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_][A-Za-z0-9_-]{0,62}(\.[A-Za-z0-9_][A-Za-z0-9_-]{0,62})*\.?$')]
        [string]$Name,

        [ValidateRange(1, 600000)]
        [int]$TimeoutMs = 1500,

        # Only tests use another port.
        [ValidateRange(1, 65535)]
        [int]$Port = 53
    )

    # A name that is not a DNS name was refused above; a socket error or a timeout below is the same answer as "no reply".
    $noReply = @{ Responds = $false; RCode = $null; AnswerCount = $null; Ms = $null }

    # Header: random id, flags 0x0100 (recursion desired), one question. Question: the labels, type A (1), class IN (1).
    $id = Get-Random -Minimum 0 -Maximum 65536
    $query = New-Object System.Collections.Generic.List[byte]
    $query.AddRange([byte[]](($id -shr 8), ($id -band 0xFF), 1, 0, 0, 1, 0, 0, 0, 0, 0, 0))
    foreach ($label in $Name.TrimEnd('.').Split('.')) {
        $query.Add([byte]$label.Length)
        $query.AddRange([System.Text.Encoding]::ASCII.GetBytes($label))
    }
    $query.AddRange([byte[]](0, 0, 1, 0, 1))
    $packet = $query.ToArray()

    $client = New-Object System.Net.Sockets.UdpClient $Server.AddressFamily
    try {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $client.Connect($Server, $Port)
        $null = $client.Send($packet, $packet.Length)
        $remote = New-Object System.Net.IPEndPoint $Server, $Port
        # ReceiveTimeout is per call, so the time left is set again for each reply; a reply with another id is not ours.
        while ($timer.ElapsedMilliseconds -lt $TimeoutMs) {
            $client.Client.ReceiveTimeout = [int][math]::Max(1, $TimeoutMs - $timer.ElapsedMilliseconds)
            $reply = $client.Receive([ref]$remote)
            if ($reply.Length -ge 12 -and $reply[0] -eq $packet[0] -and $reply[1] -eq $packet[1]) {
                return @{
                    Responds    = $true
                    RCode       = [int]($reply[3] -band 0x0F)
                    AnswerCount = [int](($reply[6] -shl 8) -bor $reply[7])
                    Ms          = [int]$timer.ElapsedMilliseconds
                }
            }
        }
    }
    catch {
        Write-Verbose $_.Exception.Message
    }
    finally {
        $client.Close()
    }
    $noReply
}

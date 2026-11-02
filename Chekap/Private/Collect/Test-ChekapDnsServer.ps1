function Test-ChekapDnsServer {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Net.IPAddress]$Server,

        # A DNS name, also one in Cyrillic (it goes on the wire as punycode). A name that cannot be asked gets no reply instead of an exception.
        [Parameter(Mandatory)]
        [string]$Name,

        [ValidateRange(1, 600000)]
        [int]$TimeoutMs = 1500,

        # Only tests use another port.
        [ValidateRange(1, 65535)]
        [int]$Port = 53
    )

    # A name that is not a DNS name, a socket error and a timeout are all the same answer: no reply.
    $noReply = @{ Responds = $false; RCode = $null; AnswerCount = $null; Ms = $null }

    # shortcut: Unicode AD zones on Microsoft DNS not verified with punycode, verify when someone reports it
    try { $ascii = (New-Object System.Globalization.IdnMapping).GetAscii($Name.TrimEnd('.')) }
    catch { return $noReply }
    # Letters, digits, "_" and "-" in labels of 1-63 characters.
    if ($ascii -notmatch '^[A-Za-z0-9_][A-Za-z0-9_-]{0,62}(\.[A-Za-z0-9_][A-Za-z0-9_-]{0,62})*$') { return $noReply }

    # Header: random id, flags 0x0100 (recursion desired), one question. Question: the labels, type A (1), class IN (1).
    $id = Get-Random -Minimum 0 -Maximum 65536
    $query = New-Object System.Collections.Generic.List[byte]
    $query.AddRange([byte[]](($id -shr 8), ($id -band 0xFF), 1, 0, 0, 1, 0, 0, 0, 0, 0, 0))
    foreach ($label in $ascii.Split('.')) {
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
        # One lost datagram must not look like a dead server (an office with a single DNS server): after half of the time the query goes out once more.
        # The whole wait stays within TimeoutMs.
        $resendAtMs = [int]($TimeoutMs / 2)
        $resent = $false
        # ReceiveTimeout is per call, so the time left is set again for each reply; a reply with another id is not ours.
        while ($timer.ElapsedMilliseconds -lt $TimeoutMs) {
            $limitMs = if ($resent) { $TimeoutMs } else { $resendAtMs }
            $client.Client.ReceiveTimeout = [int][math]::Max(1, $limitMs - $timer.ElapsedMilliseconds)
            try {
                $reply = $client.Receive([ref]$remote)
            }
            catch [System.Net.Sockets.SocketException] {
                if ($resent -or $_.Exception.SocketErrorCode -ne [System.Net.Sockets.SocketError]::TimedOut) { throw }
                $null = $client.Send($packet, $packet.Length)
                $resent = $true
                continue
            }
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
BeforeAll {
    Import-Module (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'Chekap/Chekap.psd1') -Force
}

AfterAll {
    Remove-Module Chekap -ErrorAction SilentlyContinue
}

Describe 'Test-ChekapTcpPort' {
    It 'returns false within 3s for unroutable 192.0.2.1' {
        InModuleScope Chekap {
            $unroutable = '192.0.2.1'
            $sw = [Diagnostics.Stopwatch]::StartNew()
            Test-ChekapTcpPort -ComputerName $unroutable -Port 9100 -TimeoutMs 500 | Should -BeFalse
            $sw.Elapsed.TotalSeconds | Should -BeLessThan 3
        }
    }

    It 'returns true for a listening port and false for a closed one' {
        InModuleScope Chekap {
            $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback), 0
            $listener.Start()
            $port = $listener.LocalEndpoint.Port
            try {
                Test-ChekapTcpPort -ComputerName 127.0.0.1 -Port $port | Should -BeTrue
            }
            finally {
                $listener.Stop()
            }
            # Nothing listens there any more: a refused connection is false, not an exception.
            Test-ChekapTcpPort -ComputerName 127.0.0.1 -Port $port | Should -BeFalse
        }
    }
}

Describe 'Test-ChekapPing' {
    It 'answers on loopback with the round trip time' {
        InModuleScope Chekap {
            $r = Test-ChekapPing -ComputerName 127.0.0.1
            $r.Success | Should -BeTrue
            $r.RoundtripMs | Should -BeOfType [int]
        }
    }

    It 'returns Success false and no time for an unroutable address' {
        InModuleScope Chekap {
            $unroutable = '192.0.2.1'
            $r = Test-ChekapPing -ComputerName $unroutable -TimeoutMs 500
            $r.Success | Should -BeFalse
            $r.RoundtripMs | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-ChekapWinEvent' {
    It 'returns empty array when no events' {
        InModuleScope Chekap {
            $r = @(Get-ChekapWinEvent -FilterHashtable @{ LogName = 'System'; Id = 65000 })
            $r.Count | Should -Be 0
        }
    }

    It 'returns events and honours MaxEvents' {
        InModuleScope Chekap {
            $r = @(Get-ChekapWinEvent -FilterHashtable @{ LogName = 'System' } -MaxEvents 2)
            $r.Count | Should -BeGreaterThan 0
            $r.Count | Should -BeLessOrEqual 2
        }
    }

    It 'throws for errors other than no events' {
        InModuleScope Chekap {
            { Get-ChekapWinEvent -FilterHashtable @{ LogName = 'Chekap-No-Such-Log' } } | Should -Throw
        }
    }
}

Describe 'Get-ChekapFolderSize' {
    It 'returns $null for missing path' {
        InModuleScope Chekap -Parameters @{ P = (Join-Path $TestDrive 'no-such-folder') } {
            Get-ChekapFolderSize -Path $P | Should -BeNullOrEmpty
        }
    }

    It 'sums files in sub-folders' {
        $dir = Join-Path $TestDrive 'sized'
        New-Item -ItemType Directory -Path (Join-Path $dir 'sub') -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'a.bin'), (New-Object byte[] 100))
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'sub/b.bin'), (New-Object byte[] 23))
        InModuleScope Chekap -Parameters @{ P = $dir } {
            $size = Get-ChekapFolderSize -Path $P
            $size | Should -BeOfType [long]
            $size | Should -Be 123
        }
    }

    It 'returns 0 for an empty folder' {
        $dir = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        InModuleScope Chekap -Parameters @{ P = $dir } {
            Get-ChekapFolderSize -Path $P | Should -Be 0
        }
    }
}

Describe 'Get-ChekapConnectedInterface' {
    BeforeEach {
        Mock Get-NetAdapter {
            @(
                [pscustomobject]@{ Name = 'Ethernet'; InterfaceIndex = 3; Status = 'Up' }
                [pscustomobject]@{ Name = 'Ethernet 2'; InterfaceIndex = 4; Status = 'Disconnected' }
            )
        } -ModuleName Chekap
        Mock Get-NetRoute { } -ModuleName Chekap
    }

    It 'returns only the connected physical adapters when no other interface routes to the internet' {
        $r = @(InModuleScope Chekap { Get-ChekapConnectedInterface })
        $r.Count | Should -Be 1
        $r[0].Index | Should -BeOfType [int]
        $r[0].Index | Should -Be 3
        $r[0].Alias | Should -Be 'Ethernet'
        Should -Invoke Get-NetAdapter -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Physical }
    }

    It 'adds a vEthernet interface that carries the IPv4 default route (Hyper-V external switch, NIC team)' {
        Mock Get-NetRoute { [pscustomobject]@{ InterfaceIndex = 9; InterfaceAlias = 'vEthernet (External)'; NextHop = '192.0.2.1' } } -ModuleName Chekap
        $r = @(InModuleScope Chekap { Get-ChekapConnectedInterface })
        ($r | ForEach-Object { '{0}={1}' -f $_.Index, $_.Alias }) -join '; ' | Should -Be '3=Ethernet; 9=vEthernet (External)'
        # No default route is an error of the cmdlet, so it is silenced.
        Should -Invoke Get-NetRoute -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $DestinationPrefix -eq '0.0.0.0/0' -and $ErrorAction -eq 'SilentlyContinue' }
    }

    It 'does not add a WSL vEthernet whose default route is on-link only' {
        Mock Get-NetRoute { [pscustomobject]@{ InterfaceIndex = 12; InterfaceAlias = 'vEthernet (WSL)'; NextHop = '0.0.0.0' } } -ModuleName Chekap
        $r = @(InModuleScope Chekap { Get-ChekapConnectedInterface })
        ($r | ForEach-Object { $_.Index }) -join ',' | Should -Be '3'
    }

    It 'lists an interface once when it is physical and also holds the default route, in order of index' {
        Mock Get-NetRoute {
            @(
                [pscustomobject]@{ InterfaceIndex = 9; InterfaceAlias = 'vEthernet (External)'; NextHop = '192.0.2.1' }
                [pscustomobject]@{ InterfaceIndex = 3; InterfaceAlias = 'Ethernet'; NextHop = '192.0.2.1' }
                [pscustomobject]@{ InterfaceIndex = 3; InterfaceAlias = 'Ethernet'; NextHop = '192.0.2.2' }
            )
        } -ModuleName Chekap
        $r = @(InModuleScope Chekap { Get-ChekapConnectedInterface })
        ($r | ForEach-Object { $_.Index }) -join ',' | Should -Be '3,9'
    }

    It 'returns nothing when no adapter is connected and no route exists' {
        Mock Get-NetAdapter { [pscustomobject]@{ Name = 'Ethernet'; InterfaceIndex = 3; Status = 'Disconnected' } } -ModuleName Chekap
        @(InModuleScope Chekap { Get-ChekapConnectedInterface }).Count | Should -Be 0
    }
}

Describe 'Test-ChekapDnsServer' {
    BeforeAll {
        # A DNS server on loopback in a runspace of its own: it reads one query and answers as the plan says.
        # RCode/Answers shape the reply; WrongIdFirst sends a reply with a wrong id before the right one; OnlyWrongId never sends the right one;
        # Silent sends nothing; Capture (a synchronized hashtable) receives the bytes of the query.
        $script:startFakeDns = {
            param($Plan)
            $endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Loopback), 0
            $listener = New-Object System.Net.Sockets.UdpClient $endpoint
            $runspace = [runspacefactory]::CreateRunspace()
            $runspace.Open()
            $worker = [powershell]::Create()
            $worker.Runspace = $runspace
            $null = $worker.AddScript({
                    param($Listener, $Plan)
                    $Listener.Client.ReceiveTimeout = 10000
                    $from = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0
                    try { $query = $Listener.Receive([ref]$from) } catch { return }
                    if ($Plan.Capture) { $Plan.Capture.Query = $query }
                    if ($Plan.Silent) { return }
                    $reply = [byte[]]$query.Clone()
                    $reply[2] = 0x81
                    $reply[3] = 0x80 -bor $Plan.RCode
                    if ($Plan.Answers -gt 0) {
                        $reply[7] = 1
                        $reply = [byte[]]($reply + [byte[]](0xC0, 0x0C, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 192, 0, 2, 7))
                    }
                    $wrong = [byte[]]$reply.Clone()
                    $wrong[0] = $wrong[0] -bxor 0xFF
                    if ($Plan.WrongIdFirst -or $Plan.OnlyWrongId) { $null = $Listener.Send($wrong, $wrong.Length, $from) }
                    if (-not $Plan.OnlyWrongId) { $null = $Listener.Send($reply, $reply.Length, $from) }
                }).AddArgument($listener).AddArgument($Plan)
            $null = $worker.BeginInvoke()
            @{
                Port = $listener.Client.LocalEndPoint.Port
                Stop = { $listener.Close(); $worker.Dispose(); $runspace.Dispose() }.GetNewClosure()
            }
        }
        $script:askFakeDns = {
            param($Plan, $TimeoutMs)
            $fake = & $script:startFakeDns $Plan
            try {
                InModuleScope Chekap -Parameters @{ Port = $fake.Port; TimeoutMs = $TimeoutMs } {
                    Test-ChekapDnsServer -Server '127.0.0.1' -Name 'www.contoso.local' -TimeoutMs $TimeoutMs -Port $Port
                }
            }
            finally {
                & $fake.Stop
            }
        }
    }

    It 'a NOERROR reply with an answer is a response with RCode 0 and 1 answer' {
        $r = & $script:askFakeDns @{ RCode = 0; Answers = 1 } 3000
        $r.Responds | Should -BeTrue
        $r.Responds | Should -BeOfType [bool]
        $r.RCode | Should -BeOfType [int]
        $r.RCode | Should -Be 0
        $r.AnswerCount | Should -Be 1
        $r.Ms | Should -BeOfType [int]
        $r.Ms | Should -BeGreaterOrEqual 0
    }

    It 'an NXDOMAIN reply is still a response' {
        $r = & $script:askFakeDns @{ RCode = 3; Answers = 0 } 3000
        $r.Responds | Should -BeTrue
        $r.RCode | Should -Be 3
        $r.AnswerCount | Should -Be 0
    }

    It 'reads the RCode from the low 4 bits only: <RCode>' -ForEach @(@{ RCode = 2 }, @{ RCode = 5 }, @{ RCode = 15 }) {
        $r = & $script:askFakeDns @{ RCode = $RCode; Answers = 0 } 3000
        $r.Responds | Should -BeTrue
        $r.RCode | Should -Be $RCode
    }

    It 'ignores a reply with a wrong id' {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $r = & $script:askFakeDns @{ RCode = 0; Answers = 1; OnlyWrongId = $true } 600
        $r.Responds | Should -BeFalse
        $r.RCode | Should -BeNullOrEmpty
        $r.AnswerCount | Should -BeNullOrEmpty
        $r.Ms | Should -BeNullOrEmpty
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 3
    }

    It 'keeps waiting after a wrong id and takes the right reply' {
        $r = & $script:askFakeDns @{ RCode = 0; Answers = 1; WrongIdFirst = $true } 3000
        $r.Responds | Should -BeTrue
        $r.AnswerCount | Should -Be 1
    }

    It 'a server that stays silent does not respond, within the timeout' {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $r = & $script:askFakeDns @{ Silent = $true } 500
        $r.Responds | Should -BeFalse
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 3
    }

    It 'returns Responds false within 3s for unroutable 192.0.2.1' {
        InModuleScope Chekap {
            $unroutable = '192.0.2.1'
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $r = Test-ChekapDnsServer -Server $unroutable -Name 'localhost'
            $r.Responds | Should -BeFalse
            $r.Ms | Should -BeNullOrEmpty
            $sw.Elapsed.TotalSeconds | Should -BeLessThan 3
        }
    }

    It 'sends one type A query with recursion desired for the name' {
        $capture = [hashtable]::Synchronized(@{})
        $null = & $script:askFakeDns @{ RCode = 0; Answers = 0; Capture = $capture } 3000
        $q = [byte[]]$capture.Query
        # Header after the id: recursion desired only, one question, nothing else.
        ($q[2..11] -join ',') | Should -Be '1,0,0,1,0,0,0,0,0,0'
        # Question: 3www7contoso5local0, then type A (1) and class IN (1).
        $expected = [byte[]](3) + [Text.Encoding]::ASCII.GetBytes('www') + [byte[]](7) + [Text.Encoding]::ASCII.GetBytes('contoso') + [byte[]](5) + [Text.Encoding]::ASCII.GetBytes('local') + [byte[]](0, 0, 1, 0, 1)
        ($q[12..($q.Length - 1)] -join ',') | Should -Be ($expected -join ',')
    }

    It 'uses a different id for different queries' {
        $ids = foreach ($i in 1..4) {
            $capture = [hashtable]::Synchronized(@{})
            $null = & $script:askFakeDns @{ RCode = 0; Answers = 0; Capture = $capture } 3000
            $capture.Query[0] * 256 + $capture.Query[1]
        }
        @($ids | Sort-Object -Unique).Count | Should -BeGreaterThan 1
    }

    It 'refuses a name that is not a DNS name: <Bad>' -ForEach @(@{ Bad = 'bad..name' }, @{ Bad = '-' }, @{ Bad = 'a b' }, @{ Bad = ('a' * 64) }) {
        InModuleScope Chekap -Parameters @{ Bad = $Bad } {
            { Test-ChekapDnsServer -Server '127.0.0.1' -Name $Bad -TimeoutMs 200 } | Should -Throw
        }
    }
}

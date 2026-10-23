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

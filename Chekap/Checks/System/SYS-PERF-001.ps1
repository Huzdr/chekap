@{
    Id            = 'SYS-PERF-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-perfformatteddata'
        'https://learn.microsoft.com/windows/win32/wmisdk/monitoring-performance-data'
    )
    Settings      = @{ WarnCpuPercent = 90 }
    Collect       = {
        # The performance classes are missing when the performance counters of the PC are damaged; that is "cannot measure", not an error.
        $classes = 'Win32_PerfFormattedData_PerfOS_Processor', 'Win32_PerfFormattedData_PerfProc_Process'
        if (@($classes | Where-Object { Get-CimClass -ClassName $_ -ErrorAction SilentlyContinue }).Count -lt $classes.Count) {
            return @{ CountersAvailable = $false }
        }
        $totalOnly = "Name='_Total'"
        # The formatted counters are computed between two queries: the first one only primes them, the second one is measured.
        $null = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter $totalOnly
        $null = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process
        Start-Sleep -Milliseconds 1000
        $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter $totalOnly
        $processes = @(Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process)
        $logicalCpus = [math]::Max(1, [int](Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors)
        # A process counter runs up to 100 per logical CPU; dividing gives the share of the whole PC.
        $list = @($processes | Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' } | ForEach-Object {
                @{
                    Name       = [string]$_.Name
                    CpuPercent = [math]::Round($_.PercentProcessorTime / $logicalCpus, 1)
                    RamMB      = [math]::Round($_.WorkingSetPrivate / 1MB, 0)
                }
            })
        @{
            CountersAvailable = $true
            CpuPercent        = [int]$cpu.PercentProcessorTime
            LogicalCpus       = $logicalCpus
            TopCpu            = @($list | Sort-Object -Property { $_.CpuPercent } -Descending | Select-Object -First 5)
            TopRam            = @($list | Sort-Object -Property { $_.RamMB } -Descending | Select-Object -First 5)
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        if (-not $Data.CountersAvailable) {
            return @{ Status = 'Warning'; Message = 'NoCounters' }
        }
        # "name: number" lists; the unit is in the message text.
        $topCpu = @($Data.TopCpu | Select-Object -First 3 | ForEach-Object { '{0}: {1:N0}' -f $_.Name, $_.CpuPercent }) -join ', '
        $topRam = @($Data.TopRam | Select-Object -First 3 | ForEach-Object { '{0}: {1:N0}' -f $_.Name, $_.RamMB }) -join ', '
        if ($Data.CpuPercent -ge $Settings.WarnCpuPercent) {
            @{ Status = 'Warning'; Message = 'HighCpu'; Args = @($Data.CpuPercent, $topCpu) }
        }
        else {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($Data.CpuPercent, $topCpu, $topRam) }
        }
    }
}

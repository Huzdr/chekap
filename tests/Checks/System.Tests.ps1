BeforeDiscovery {
    $now = [datetime]'2026-03-10T12:00:00'
    $daysAgo = { param($days) $now.AddDays(-$days) }
    $startupItems = { param($count) @(1..$count | ForEach-Object { @{ Name = 'App{0:D2}' -f $_; Location = 'HKLM\Run'; User = 'PC-042\user' } }) }
    $crash = { param($daysBack, $code) @{ Time = $now.AddDays(-$daysBack); Code = $code } }
    $battery = { param($id, $design, $full) @{ Id = $id; DesignCapacity = $design; FullChargeCapacity = $full; CycleCount = 100 } }
    $memory = { param($totalKB, $freeKB, $virtualKB, $freeVirtualKB, $pagefileMB) @{ TotalVisibleMemorySize = $totalKB; FreePhysicalMemory = $freeKB; TotalVirtualMemorySize = $virtualKB; FreeVirtualMemory = $freeVirtualKB; PagefileMB = $pagefileMB } }
    $topCpu = @(
        @{ Name = 'a.exe'; CpuPercent = 20; RamMB = 300 }
        @{ Name = 'b.exe'; CpuPercent = 10; RamMB = 200 }
        @{ Name = 'c.exe'; CpuPercent = 5; RamMB = 100 }
        @{ Name = 'd.exe'; CpuPercent = 4; RamMB = 90 }
        @{ Name = 'e.exe'; CpuPercent = 3; RamMB = 80 }
    )
    $topRam = @(
        @{ Name = 'x.exe'; CpuPercent = 1; RamMB = 900 }
        @{ Name = 'y.exe'; CpuPercent = 1; RamMB = 800 }
        @{ Name = 'z.exe'; CpuPercent = 1; RamMB = 700 }
        @{ Name = 'v.exe'; CpuPercent = 1; RamMB = 600 }
        @{ Name = 'w.exe'; CpuPercent = 1; RamMB = 500 }
    )
    # The same format Evaluate uses for "name: number" lists; the number format follows the current culture.
    $gb = { param($path, $bytes) '{0}: {1:N1}' -f $path, ($bytes / 1GB) }

    # One row per Message of every check. Expect lists the verdicts in order; Args is compared as a joined string.
    $script:evaluateCases = @(
        @{ Id = 'SYS-UPTIME-001'; Name = 'short uptime is OK'; Data = @{ LastBoot = (& $daysAgo 3); Now = $now; FastStartup = $false }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(3) }) }
        @{ Id = 'SYS-UPTIME-001'; Name = 'short uptime with Fast Startup is OK'; Data = @{ LastBoot = (& $daysAgo 3); Now = $now; FastStartup = $true }; Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'SYS-UPTIME-001'; Name = 'just under WarnDays is OK'; Data = @{ LastBoot = $now.AddDays(-13).AddHours(-23); Now = $now; FastStartup = $false }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(13) }) }
        @{ Id = 'SYS-UPTIME-001'; Name = 'WarnDays reached is Long'; Data = @{ LastBoot = (& $daysAgo 14); Now = $now; FastStartup = $false }; Expect = @(@{ Status = 'Warning'; Message = 'Long'; Args = @(14) }) }
        @{ Id = 'SYS-UPTIME-001'; Name = 'long uptime is Long'; Data = @{ LastBoot = (& $daysAgo 20); Now = $now; FastStartup = $false }; Expect = @(@{ Status = 'Warning'; Message = 'Long'; Args = @(20) }) }
        @{ Id = 'SYS-UPTIME-001'; Name = 'long uptime with Fast Startup is LongFastStartup'; Data = @{ LastBoot = (& $daysAgo 20); Now = $now; FastStartup = $true }; Expect = @(@{ Status = 'Warning'; Message = 'LongFastStartup'; Args = @(20) }) }

        @{ Id = 'SYS-REBOOT-001'; Name = 'nothing pending is OK'; Data = @{ WindowsUpdate = $false; Cbs = $false; FileRenameCount = 0 }; Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'SYS-REBOOT-001'; Name = 'Windows Update flag is Pending'; Data = @{ WindowsUpdate = $true; Cbs = $false; FileRenameCount = 0 }; Expect = @(@{ Status = 'Warning'; Message = 'Pending'; Args = @('Windows Update') }) }
        @{ Id = 'SYS-REBOOT-001'; Name = 'CBS and file renames list both sources'; Data = @{ WindowsUpdate = $false; Cbs = $true; FileRenameCount = 4 }; Expect = @(@{ Status = 'Warning'; Message = 'Pending'; Args = @('CBS, PendingFileRenameOperations') }) }
        @{ Id = 'SYS-REBOOT-001'; Name = 'all three sources are listed in order'; Data = @{ WindowsUpdate = $true; Cbs = $true; FileRenameCount = 2 }; Expect = @(@{ Status = 'Warning'; Message = 'Pending'; Args = @('Windows Update, CBS, PendingFileRenameOperations') }) }

        @{ Id = 'SYS-DISK-001'; Name = 'plenty of space is OK'; Data = @{ Drive = 'C:'; SizeBytes = 100GB; FreeBytes = 60GB; Candidates = @(); OldProfiles = 0 }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'C:'; Args = @(60, 60) }) }
        @{ Id = 'SYS-DISK-001'; Name = 'under WarnGB is Low'; Data = @{ Drive = 'C:'; SizeBytes = 100GB; FreeBytes = 12GB; Candidates = @(); OldProfiles = 0 }; Expect = @(@{ Status = 'Warning'; Message = 'Low'; Target = 'C:'; Args = @(12, 12, [string][char]0x2014, 0) }) }
        @{ Id = 'SYS-DISK-001'; Name = 'under WarnPercent on a big disk is Low'; Data = @{ Drive = 'D:'; SizeBytes = 1000GB; FreeBytes = 90GB; Candidates = @(); OldProfiles = 0 }; Expect = @(@{ Status = 'Warning'; Message = 'Low'; Target = 'D:' }) }
        @{ Id = 'SYS-DISK-001'; Name = 'exactly CriticalGB is still Low'; Data = @{ Drive = 'C:'; SizeBytes = 100GB; FreeBytes = 5GB; Candidates = @(); OldProfiles = 0 }; Expect = @(@{ Status = 'Warning'; Message = 'Low'; Target = 'C:' }) }
        @{ Id = 'SYS-DISK-001'; Name = 'under CriticalGB is CriticalLow'; Data = @{ Drive = 'C:'; SizeBytes = 100GB; FreeBytes = 4GB; Candidates = @(); OldProfiles = 0 }; Expect = @(@{ Status = 'Critical'; Message = 'CriticalLow'; Target = 'C:' }) }
        @{
            Id = 'SYS-DISK-001'; Name = 'candidates are listed biggest first, then the old profile count'
            Data = @{ Drive = 'C:'; SizeBytes = 100GB; FreeBytes = 4GB; OldProfiles = 2; Candidates = @(@{ Path = 'C:\Temp-A'; Bytes = 1GB }, @{ Path = 'C:\Temp-B'; Bytes = 3GB }) }
            Expect = @(@{ Status = 'Critical'; Message = 'CriticalLow'; Target = 'C:'; Args = @(4, 4, ((& $gb 'C:\Temp-B' 3GB), (& $gb 'C:\Temp-A' 1GB) -join '; '), 2) })
        }

        @{ Id = 'SYS-PERF-001'; Name = 'low CPU is OK with the top 3 of each list'; Data = @{ CountersAvailable = $true; CpuPercent = 35; LogicalCpus = 8; TopCpu = $topCpu; TopRam = $topRam }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(35, 'a.exe: 20, b.exe: 10, c.exe: 5', 'x.exe: 900, y.exe: 800, z.exe: 700') }) }
        @{ Id = 'SYS-PERF-001'; Name = 'high CPU is HighCpu'; Data = @{ CountersAvailable = $true; CpuPercent = 95; LogicalCpus = 8; TopCpu = $topCpu; TopRam = $topRam }; Expect = @(@{ Status = 'Warning'; Message = 'HighCpu'; Args = @(95, 'a.exe: 20, b.exe: 10, c.exe: 5') }) }
        @{ Id = 'SYS-PERF-001'; Name = 'WarnCpuPercent reached is HighCpu'; Data = @{ CountersAvailable = $true; CpuPercent = 90; LogicalCpus = 8; TopCpu = $topCpu; TopRam = $topRam }; Expect = @(@{ Status = 'Warning'; Message = 'HighCpu' }) }
        @{ Id = 'SYS-PERF-001'; Name = 'no processes still gives a verdict'; Data = @{ CountersAvailable = $true; CpuPercent = 5; LogicalCpus = 8; TopCpu = @(); TopRam = @() }; Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }

        @{ Id = 'SYS-PERF-001'; Name = 'missing performance counters are a Warning'; Data = @{ CountersAvailable = $false }; Expect = @(@{ Status = 'Warning'; Message = 'NoCounters' }) }

        @{ Id = 'SYS-STARTUP-001'; Name = 'few items is OK'; Data = @{ Items = (& $startupItems 3) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(3) }) }
        @{ Id = 'SYS-STARTUP-001'; Name = 'no items is OK'; Data = @{ Items = @() }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(0) }) }
        @{ Id = 'SYS-STARTUP-001'; Name = 'one below WarnCount is OK'; Data = @{ Items = (& $startupItems 14) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(14) }) }
        @{ Id = 'SYS-STARTUP-001'; Name = 'WarnCount reached is Many with the first 10 names'; Data = @{ Items = (& $startupItems 15) }; Expect = @(@{ Status = 'Warning'; Message = 'Many'; Args = @(15, 'App01, App02, App03, App04, App05, App06, App07, App08, App09, App10') }) }

        @{ Id = 'SYS-MEMORY-001'; Name = 'healthy memory is OK'; Data = (& $memory 16777216 8388608 25165824 20971520 4096); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(16, 50) }) }
        @{ Id = 'SYS-MEMORY-001'; Name = 'little free RAM is LowRam'; Data = (& $memory 16777216 1048576 25165824 12582912 4096); Expect = @(@{ Status = 'Warning'; Message = 'LowRam'; Args = @(6.25) }) }
        @{ Id = 'SYS-MEMORY-001'; Name = 'exactly WarnFreeRamPercent free is OK'; Data = (& $memory 10000 1000 20000 10000 4096); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'SYS-MEMORY-001'; Name = 'high commit is CommitHigh'; Data = (& $memory 16777216 8388608 25165824 1048576 4096); Expect = @(@{ Status = 'Critical'; Message = 'CommitHigh' }) }
        @{ Id = 'SYS-MEMORY-001'; Name = 'exactly CriticalCommitPercent is CommitHigh'; Data = (& $memory 10000 5000 10000 1000 4096); Expect = @(@{ Status = 'Critical'; Message = 'CommitHigh'; Args = @(90) }) }
        @{ Id = 'SYS-MEMORY-001'; Name = 'commit beats low RAM: one memory verdict'; Data = (& $memory 16777216 1048576 25165824 1048576 4096); Expect = @(@{ Status = 'Critical'; Message = 'CommitHigh' }) }
        @{ Id = 'SYS-MEMORY-001'; Name = 'no page file adds NoPagefile after the memory verdict'; Data = (& $memory 16777216 8388608 16777216 8388608 0); Expect = @(@{ Status = 'OK'; Message = 'Ok' }, @{ Status = 'Warning'; Message = 'NoPagefile'; Target = 'pagefile' }) }
        @{ Id = 'SYS-MEMORY-001'; Name = 'no page file next to a memory problem gives both'; Data = (& $memory 16777216 1048576 16777216 1048576 0); Expect = @(@{ Status = 'Critical'; Message = 'CommitHigh' }, @{ Status = 'Warning'; Message = 'NoPagefile'; Target = 'pagefile' }) }

        @{ Id = 'SYS-BSOD-001'; Name = 'no events is OK'; Data = @{ Events = @(); MinidumpCount = $null }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(30) }) }
        @{ Id = 'SYS-BSOD-001'; Name = 'one crash is Crashes with the short stop code'; Data = @{ Events = @(& $crash 2 '0x000000d1 (0x1, 0x2, 0x0, 0x3)'); MinidumpCount = 1 }; Expect = @(@{ Status = 'Warning'; Message = 'Crashes'; Args = @(1, 30, $now.AddDays(-2), '0x000000d1') }) }
        @{ Id = 'SYS-BSOD-001'; Name = 'one below CriticalCount is Crashes'; Data = @{ Events = @((& $crash 5 '0x0000009f (0x3)'), (& $crash 9 '0x0000009f (0x3)')); MinidumpCount = $null }; Expect = @(@{ Status = 'Warning'; Message = 'Crashes'; Args = @(2, 30, $now.AddDays(-5), '0x0000009f') }) }
        @{ Id = 'SYS-BSOD-001'; Name = 'CriticalCount reached is ManyCrashes with the latest date and unique codes'; Data = @{ Events = @((& $crash 9 '0x000000d1 (0x1)'), (& $crash 2 '0x0000009f (0x3)'), (& $crash 5 '0x000000d1 (0x1)')); MinidumpCount = 3 }; Expect = @(@{ Status = 'Critical'; Message = 'ManyCrashes'; Args = @(3, 30, $now.AddDays(-2), '0x0000009f, 0x000000d1') }) }

        @{ Id = 'SYS-SHUTDOWN-001'; Name = 'no events is OK'; Data = @{ KernelPower41 = @(); EventLog6008 = @() }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(30) }) }
        @{ Id = 'SYS-SHUTDOWN-001'; Name = 'count is the bigger of the two lists'; Data = @{ KernelPower41 = @($now.AddDays(-4), $now.AddDays(-8)); EventLog6008 = @($now.AddDays(-3)) }; Expect = @(@{ Status = 'Warning'; Message = 'Unexpected'; Args = @(2, 30, $now.AddDays(-3)) }) }
        @{ Id = 'SYS-SHUTDOWN-001'; Name = 'one event is Unexpected'; Data = @{ KernelPower41 = @($now.AddDays(-6)); EventLog6008 = @() }; Expect = @(@{ Status = 'Warning'; Message = 'Unexpected'; Args = @(1, 30, $now.AddDays(-6)) }) }
        @{ Id = 'SYS-SHUTDOWN-001'; Name = 'CriticalCount reached is Frequent, latest date from both lists'; Data = @{ KernelPower41 = @($now.AddDays(-1)); EventLog6008 = @($now.AddDays(-10), $now.AddDays(-12), $now.AddDays(-14)) }; Expect = @(@{ Status = 'Critical'; Message = 'Frequent'; Args = @(3, 30, $now.AddDays(-1)) }) }

        @{ Id = 'SYS-APPCRASH-001'; Name = 'no crashes and no stability index is OK with a dash'; Data = @{ Crashes = @(); StabilityIndex = $null }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(0, 7, [string][char]0x2014) }) }
        @{ Id = 'SYS-APPCRASH-001'; Name = 'crashes below WarnPerApp are OK with the index'; Data = @{ Crashes = @('a.exe', 'a.exe', 'b.exe', 'b.exe'); StabilityIndex = 8.5 }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(4, 7, 8.5) }) }
        @{ Id = 'SYS-APPCRASH-001'; Name = 'apps at WarnPerApp are Crashing, most crashes first'; Data = @{ Crashes = @('contoso.exe', 'a.exe', 'b.exe', 'contoso.exe', 'b.exe', 'b.exe', 'contoso.exe', 'b.exe'); StabilityIndex = $null }; Expect = @(@{ Status = 'Warning'; Message = 'Crashing'; Args = @(('b.exe {0}4, contoso.exe {0}3' -f [char]0x00D7), 7) }) }
        @{ Id = 'SYS-APPCRASH-001'; Name = 'exe names differing in case count as one app'; Data = @{ Crashes = @('App.exe', 'app.exe', 'APP.EXE'); StabilityIndex = 9 }; Expect = @(@{ Status = 'Warning'; Message = 'Crashing'; Args = @(('App.exe {0}3' -f [char]0x00D7), 7) }) }

        @{ Id = 'SYS-BATTERY-001'; Name = 'no battery is Skipped'; Data = @{ HasBattery = $false; Batteries = @() }; Expect = @(@{ Status = 'Skipped'; Message = 'NoBattery' }) }
        @{ Id = 'SYS-BATTERY-001'; Name = 'a battery that powercfg does not report is Skipped'; Data = @{ HasBattery = $true; Batteries = @() }; Expect = @(@{ Status = 'Skipped'; Message = 'NoBattery' }) }
        @{ Id = 'SYS-BATTERY-001'; Name = 'zero design capacity is NoData'; Data = @{ HasBattery = $true; Batteries = @(& $battery 'BAT0' 0 0) }; Expect = @(@{ Status = 'Skipped'; Message = 'NoData'; Target = 'BAT0' }) }
        @{ Id = 'SYS-BATTERY-001'; Name = 'under CriticalPercent is Worn'; Data = @{ HasBattery = $true; Batteries = @(& $battery 'BAT0' 50000 15000) }; Expect = @(@{ Status = 'Critical'; Message = 'Worn'; Target = 'BAT0'; Args = @(30) }) }
        @{ Id = 'SYS-BATTERY-001'; Name = 'exactly CriticalPercent is Aging'; Data = @{ HasBattery = $true; Batteries = @(& $battery 'BAT0' 50000 20000) }; Expect = @(@{ Status = 'Warning'; Message = 'Aging'; Target = 'BAT0'; Args = @(40) }) }
        @{ Id = 'SYS-BATTERY-001'; Name = 'under WarnPercent is Aging'; Data = @{ HasBattery = $true; Batteries = @(& $battery 'BAT0' 50000 27500) }; Expect = @(@{ Status = 'Warning'; Message = 'Aging'; Target = 'BAT0'; Args = @(55) }) }
        @{ Id = 'SYS-BATTERY-001'; Name = 'exactly WarnPercent is OK'; Data = @{ HasBattery = $true; Batteries = @(& $battery 'BAT0' 50000 30000) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'BAT0'; Args = @(60) }) }
        @{ Id = 'SYS-BATTERY-001'; Name = 'healthy battery is OK'; Data = @{ HasBattery = $true; Batteries = @(& $battery 'BAT0' 50000 45000) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'BAT0'; Args = @(90) }) }
        @{ Id = 'SYS-BATTERY-001'; Name = 'every battery gets its own verdict'; Data = @{ HasBattery = $true; Batteries = @((& $battery 'BAT0' 50000 45000), (& $battery 'BAT1' 40000 10000)) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'BAT0' }, @{ Status = 'Critical'; Message = 'Worn'; Target = 'BAT1'; Args = @(25) }) }
    )

    # Defaults named in the task brief; admin rights are not needed by any System check.
    $script:settingsCases = @(
        @{ Id = 'SYS-UPTIME-001'; Settings = @{ WarnDays = 14 } }
        @{ Id = 'SYS-REBOOT-001'; Settings = @{} }
        @{ Id = 'SYS-DISK-001'; Settings = @{ CriticalGB = 5; WarnGB = 15; WarnPercent = 10 } }
        @{ Id = 'SYS-PERF-001'; Settings = @{ WarnCpuPercent = 90 } }
        @{ Id = 'SYS-STARTUP-001'; Settings = @{ WarnCount = 15 } }
        @{ Id = 'SYS-MEMORY-001'; Settings = @{ WarnFreeRamPercent = 10; CriticalCommitPercent = 90 } }
        @{ Id = 'SYS-BSOD-001'; Settings = @{ Days = 30; CriticalCount = 3 } }
        @{ Id = 'SYS-SHUTDOWN-001'; Settings = @{ Days = 30; CriticalCount = 3 } }
        @{ Id = 'SYS-APPCRASH-001'; Settings = @{ Days = 7; WarnPerApp = 3 } }
        @{ Id = 'SYS-BATTERY-001'; Settings = @{ WarnPercent = 60; CriticalPercent = 40 } }
    )
}

BeforeAll {
    Import-Module (Join-Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) 'Chekap/Chekap.psd1') -Force
    $script:byId = @{}
    foreach ($registered in (InModuleScope Chekap { $script:ChekapChecks })) { $script:byId[$registered.Id] = $registered }
}

AfterAll {
    Remove-Module Chekap -ErrorAction SilentlyContinue
}

Describe 'System checks: registration' {
    It 'registers all 10 checks in the System category' {
        @($script:byId.Values | Where-Object { $_.Category -eq 'System' }).Count | Should -Be 10
    }

    It '<Id> has the Settings from the brief and needs no admin rights' -ForEach $script:settingsCases {
        $check = $script:byId[$Id]
        $check | Should -Not -BeNullOrEmpty
        $check.RequiresAdmin | Should -BeFalse
        $check.Settings.Count | Should -Be $Settings.Count
        foreach ($key in $Settings.Keys) { $check.Settings[$key] | Should -Be $Settings[$key] }
    }
}

Describe 'System checks: Evaluate' {
    It '<Id>: <Name>' -ForEach $script:evaluateCases {
        $check = $script:byId[$Id]
        $verdicts = @(& $check.Evaluate $Data $check.Settings)
        $verdicts.Count | Should -Be $Expect.Count
        for ($i = 0; $i -lt $Expect.Count; $i++) {
            $verdicts[$i].Status | Should -Be $Expect[$i].Status
            $verdicts[$i].Message | Should -Be $Expect[$i].Message
            if ($Expect[$i].ContainsKey('Target')) { $verdicts[$i].Target | Should -Be $Expect[$i].Target }
            if ($Expect[$i].ContainsKey('Args')) { (@($verdicts[$i].Args) -join '|') | Should -Be (@($Expect[$i].Args) -join '|') }
        }
    }
}

Describe 'System checks: numbers follow the report language, not the session culture' {
    BeforeAll {
        # 2.1 GB free with a 1.8 GB candidate: Evaluate pre-formats the candidate list and the text formats the numbers.
        $script:diskCheck = $script:byId['SYS-DISK-001'].Clone()
        $script:diskCheck.Collect = { @{ Drive = 'C:'; SizeBytes = [long]100GB; FreeBytes = [long](2.1 * 1GB); Candidates = @(@{ Path = 'C:\Temp-A'; Bytes = [long](1.8 * 1GB) }); OldProfiles = 2 } }
        $script:runWithThreadCulture = {
            param([string]$ThreadCulture, [string]$Language)
            $saved = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo($ThreadCulture)
                InModuleScope Chekap -Parameters @{ C = $script:diskCheck; L = $Language } { @(Invoke-ChekapCheck -Check $C -Language $L)[0] }
            }
            finally {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $saved
            }
        }
    }

    It 'an English report made on a Ukrainian session uses the decimal point' {
        $result = & $script:runWithThreadCulture 'uk-UA' 'en'
        $result.Status | Should -Be 'Critical'
        $result.Details | Should -BeLike '*2.1 GB*'
        $result.Details | Should -BeLike '*C:\Temp-A: 1.8*'
        $result.Details | Should -Not -Match '\d,\d'
    }

    It 'a Ukrainian report made on an English session uses the decimal comma' {
        $result = & $script:runWithThreadCulture 'en-US' 'uk'
        $result.Details | Should -BeLike '*2,1 ГБ*'
        $result.Details | Should -BeLike '*C:\Temp-A: 1,8*'
        $result.Details | Should -Not -Match '\d\.\d'
    }

    It 'gives the session culture back when the check is done, also after a failure' {
        $before = [System.Threading.Thread]::CurrentThread.CurrentCulture.Name
        $null = & $script:runWithThreadCulture 'en-US' 'uk'
        [System.Threading.Thread]::CurrentThread.CurrentCulture.Name | Should -Be $before
        $broken = $script:diskCheck.Clone()
        $broken.Evaluate = { throw 'boom' }
        $saved = [System.Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
            $result = InModuleScope Chekap -Parameters @{ C = $broken } { @(Invoke-ChekapCheck -Check $C -Language uk)[0] }
            $result.Status | Should -Be 'Error'
            [System.Threading.Thread]::CurrentThread.CurrentCulture.Name | Should -Be 'en-US'
        }
        finally {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = $saved
        }
    }
}

Describe 'System checks: Collect' {
    It 'SYS-UPTIME-001 reads LastBoot and FastStartup' {
        Mock Get-CimInstance { [pscustomobject]@{ LastBootUpTime = [datetime]'2026-03-01T08:30:00' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
        Mock Get-ItemProperty { [pscustomobject]@{ HiberbootEnabled = 1 } } -ModuleName Chekap
        $check = $script:byId['SYS-UPTIME-001']
        $data = & $check.Collect $check.Settings
        $data.LastBoot | Should -Be ([datetime]'2026-03-01T08:30:00')
        $data.FastStartup | Should -BeOfType [bool]
        $data.FastStartup | Should -BeTrue
        $data.Now | Should -BeOfType [datetime]
    }

    It 'SYS-UPTIME-001 FastStartup is false when the value is 0 or missing' {
        Mock Get-CimInstance { [pscustomobject]@{ LastBootUpTime = [datetime]'2026-03-01T08:30:00' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
        $check = $script:byId['SYS-UPTIME-001']
        Mock Get-ItemProperty { [pscustomobject]@{ HiberbootEnabled = 0 } } -ModuleName Chekap
        (& $check.Collect $check.Settings).FastStartup | Should -BeFalse
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        (& $check.Collect $check.Settings).FastStartup | Should -BeFalse
    }

    It 'SYS-REBOOT-001 reads the two flags and counts PendingFileRenameOperations' {
        Mock Test-Path { $true } -ModuleName Chekap -ParameterFilter { $LiteralPath -like '*Auto Update\RebootRequired' }
        Mock Test-Path { $false } -ModuleName Chekap -ParameterFilter { $LiteralPath -like '*Component Based Servicing\RebootPending' }
        Mock Get-ItemProperty { [pscustomobject]@{ PendingFileRenameOperations = @('\??\C:\a.tmp', '', '\??\C:\b.tmp', '') } } -ModuleName Chekap
        $check = $script:byId['SYS-REBOOT-001']
        $data = & $check.Collect $check.Settings
        $data.WindowsUpdate | Should -BeTrue
        $data.Cbs | Should -BeFalse
        $data.FileRenameCount | Should -Be 4
    }

    It 'SYS-REBOOT-001 counts 0 file renames when the value is missing' {
        Mock Test-Path { $false } -ModuleName Chekap -ParameterFilter { $LiteralPath -like '*RebootRequired' -or $LiteralPath -like '*RebootPending' }
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        $check = $script:byId['SYS-REBOOT-001']
        (& $check.Collect $check.Settings).FileRenameCount | Should -Be 0
    }

    It 'SYS-DISK-001 skips unreadable folders and counts only profiles unused for 90 days' {
        Mock Get-CimInstance { [pscustomobject]@{ Size = [uint64]100GB; FreeSpace = [uint64]7GB } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_LogicalDisk' }
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{ Special = $false; LastUseTime = (Get-Date).AddDays(-200) }
                [pscustomobject]@{ Special = $false; LastUseTime = (Get-Date).AddDays(-10) }
                [pscustomobject]@{ Special = $false; LastUseTime = $null }
                [pscustomobject]@{ Special = $true; LastUseTime = (Get-Date).AddDays(-400) }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_UserProfile' }
        # Only the Windows Update download folder is readable.
        Mock Get-ChekapFolderSize { [long]2GB } -ModuleName Chekap -ParameterFilter { $Path -like '*SoftwareDistribution*' }
        Mock Get-ChekapFolderSize { $null } -ModuleName Chekap -ParameterFilter { $Path -notlike '*SoftwareDistribution*' }
        $check = $script:byId['SYS-DISK-001']
        $data = & $check.Collect $check.Settings
        $data.Drive | Should -Be $env:SystemDrive
        $data.SizeBytes | Should -Be 100GB
        $data.FreeBytes | Should -Be 7GB
        @($data.Candidates).Count | Should -Be 1
        $data.Candidates[0].Path | Should -BeLike '*SoftwareDistribution*Download'
        $data.Candidates[0].Bytes | Should -Be 2GB
        $data.OldProfiles | Should -Be 1
    }

    It 'SYS-PERF-001 reports CountersAvailable false when the performance classes are missing' {
        Mock Get-CimClass { } -ModuleName Chekap
        Mock Get-CimInstance { throw 'Invalid class' } -ModuleName Chekap
        Mock Start-Sleep { } -ModuleName Chekap
        $check = $script:byId['SYS-PERF-001']
        { & $check.Collect $check.Settings } | Should -Not -Throw
        $data = & $check.Collect $check.Settings
        $data.CountersAvailable | Should -BeFalse
        Should -Invoke Start-Sleep -ModuleName Chekap -Times 0 -Exactly
    }

    It 'SYS-PERF-001 uses the second sample, drops _Total and Idle, divides by the logical CPUs' {
        Mock Get-CimClass { [pscustomobject]@{ CimClassName = 'present' } } -ModuleName Chekap
        Mock Start-Sleep { } -ModuleName Chekap
        Mock Get-CimInstance { [pscustomobject]@{ PercentProcessorTime = [uint64]42 } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_PerfFormattedData_PerfOS_Processor' }
        Mock Get-CimInstance { [pscustomobject]@{ NumberOfLogicalProcessors = 4 } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{ Name = '_Total'; PercentProcessorTime = [uint64]400; WorkingSetPrivate = [uint64]9GB }
                [pscustomobject]@{ Name = 'Idle'; PercentProcessorTime = [uint64]300; WorkingSetPrivate = [uint64]0 }
                [pscustomobject]@{ Name = 'heavy'; PercentProcessorTime = [uint64]80; WorkingSetPrivate = [uint64]100MB }
                [pscustomobject]@{ Name = 'bloated'; PercentProcessorTime = [uint64]4; WorkingSetPrivate = [uint64]2GB }
                [pscustomobject]@{ Name = 'p3'; PercentProcessorTime = [uint64]3; WorkingSetPrivate = [uint64]30MB }
                [pscustomobject]@{ Name = 'p4'; PercentProcessorTime = [uint64]2; WorkingSetPrivate = [uint64]20MB }
                [pscustomobject]@{ Name = 'p5'; PercentProcessorTime = [uint64]1; WorkingSetPrivate = [uint64]10MB }
                [pscustomobject]@{ Name = 'p6'; PercentProcessorTime = [uint64]0; WorkingSetPrivate = [uint64]5MB }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_PerfFormattedData_PerfProc_Process' }
        $check = $script:byId['SYS-PERF-001']
        $data = & $check.Collect $check.Settings
        # Each performance class is queried twice around one 1000 ms pause.
        Should -Invoke Get-CimInstance -ModuleName Chekap -Times 2 -Exactly -ParameterFilter { $ClassName -eq 'Win32_PerfFormattedData_PerfOS_Processor' }
        Should -Invoke Get-CimInstance -ModuleName Chekap -Times 2 -Exactly -ParameterFilter { $ClassName -eq 'Win32_PerfFormattedData_PerfProc_Process' }
        Should -Invoke Start-Sleep -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq 1000 }
        $data.CountersAvailable | Should -BeTrue
        $data.CpuPercent | Should -Be 42
        $data.LogicalCpus | Should -Be 4
        @($data.TopCpu).Count | Should -Be 5
        @($data.TopRam).Count | Should -Be 5
        $data.TopCpu[0].Name | Should -Be 'heavy'
        $data.TopCpu[0].CpuPercent | Should -Be 20
        $data.TopRam[0].Name | Should -Be 'bloated'
        $data.TopRam[0].RamMB | Should -Be 2048
        @($data.TopCpu | Where-Object { $_.Name -in '_Total', 'Idle' }) | Should -BeNullOrEmpty
        @($data.TopRam | Where-Object { $_.Name -in '_Total', 'Idle' }) | Should -BeNullOrEmpty
    }

    It 'SYS-STARTUP-001 keeps only Name, Location and User of each startup command' {
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{ Name = 'Updater'; Command = 'C:\Tools\updater.exe /silent'; Location = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; User = 'Public' }
                [pscustomobject]@{ Name = 'Sync'; Command = 'C:\Tools\sync.exe'; Location = 'Startup'; User = 'PC-042\user' }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_StartupCommand' }
        $check = $script:byId['SYS-STARTUP-001']
        $data = & $check.Collect $check.Settings
        @($data.Items).Count | Should -Be 2
        $data.Items[1].Name | Should -Be 'Sync'
        $data.Items[1].Location | Should -Be 'Startup'
        $data.Items[1].User | Should -Be 'PC-042\user'
        ($data.Items[1].Keys | Sort-Object) -join ',' | Should -Be 'Location,Name,User'
    }

    It 'SYS-STARTUP-001 drops entries disabled in Task Manager and keeps enabled ones' {
        $enabled = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $enabledAlt = [byte[]](6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $disabled = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $disabledAlt = [byte[]](7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        Mock Get-CimInstance {
            $userRun = 'HKU\S-1-5-21-1000-2000-3000-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            $machineRun = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            @(
                [pscustomobject]@{ Name = 'Enabled App'; Command = 'C:\Tools\a.exe'; Location = $userRun; User = 'PC-042\user' }
                [pscustomobject]@{ Name = 'Disabled App'; Command = 'C:\Tools\b.exe'; Location = $userRun; User = 'PC-042\user' }
                [pscustomobject]@{ Name = 'Machine Enabled'; Command = 'C:\Tools\c.exe'; Location = $machineRun; User = 'Public' }
                [pscustomobject]@{ Name = 'Machine Disabled'; Command = 'C:\Tools\d.exe'; Location = $machineRun; User = 'Public' }
                [pscustomobject]@{ Name = 'Not Listed'; Command = 'C:\Tools\e.exe'; Location = $machineRun; User = 'Public' }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_StartupCommand' }
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        Mock Get-ItemProperty { [pscustomobject]@{ 'Enabled App' = $enabled; 'Disabled App' = $disabled; PSPath = 'Registry::x'; PSChildName = 'Run' } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'Registry::HKEY_USERS\S-1-5-21-1000-2000-3000-1001\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        }
        Mock Get-ItemProperty { [pscustomobject]@{ 'Machine Enabled' = $enabledAlt; 'Machine Disabled' = $disabledAlt } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        }
        $check = $script:byId['SYS-STARTUP-001']
        $data = & $check.Collect $check.Settings
        ($data.Items | ForEach-Object { $_.Name }) -join ',' | Should -Be 'Enabled App,Machine Enabled,Not Listed'
    }

    It 'SYS-STARTUP-001 matches Startup-folder entries by shortcut file name' {
        $enabled = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $disabled = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{ Name = 'Sync'; Command = 'C:\Tools\sync.exe'; Location = 'Startup'; User = 'PC-042\user' }
                [pscustomobject]@{ Name = 'Plain'; Command = 'C:\Tools\plain.exe'; Location = 'Startup'; User = 'PC-042\user' }
                [pscustomobject]@{ Name = 'Backup'; Command = 'C:\Tools\backup.exe'; Location = 'Common Startup'; User = 'Public' }
                [pscustomobject]@{ Name = 'Other'; Command = 'C:\Tools\other.exe'; Location = 'Common Startup'; User = 'Public' }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_StartupCommand' }
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        # The user's switch store has Sync.lnk and an unrelated file turned off.
        Mock Get-ItemProperty { [pscustomobject]@{ 'Sync.lnk' = $disabled; 'Unrelated.lnk' = $disabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
        }
        Mock Get-ItemProperty { [pscustomobject]@{ 'Backup.lnk' = $enabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
        }
        $check = $script:byId['SYS-STARTUP-001']
        $data = & $check.Collect $check.Settings
        (@($data.Items | ForEach-Object { '{0}/{1}' -f $_.Name, $_.Location }) -join ',') | Should -Be 'Plain/Startup,Backup/Common Startup,Other/Common Startup'
    }

    It 'SYS-STARTUP-001 honours a per-user switch for a machine-wide Run entry' {
        $enabled = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $disabled = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        Mock Get-CimInstance {
            $machineRun = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            @(
                [pscustomobject]@{ Name = 'Switched Off By User'; Command = 'C:\Tools\a.exe'; Location = $machineRun; User = 'Public' }
                [pscustomobject]@{ Name = 'Kept'; Command = 'C:\Tools\b.exe'; Location = $machineRun; User = 'Public' }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_StartupCommand' }
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        # The machine key calls both enabled; only the current user's key has the switch.
        Mock Get-ItemProperty { [pscustomobject]@{ 'Switched Off By User' = $enabled; Kept = $enabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        }
        Mock Get-ItemProperty { [pscustomobject]@{ 'Switched Off By User' = $disabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        }
        $check = $script:byId['SYS-STARTUP-001']
        $data = & $check.Collect $check.Settings
        ($data.Items | ForEach-Object { $_.Name }) -join ',' | Should -Be 'Kept'
    }

    It 'SYS-STARTUP-001 honours a per-user switch for a Common Startup entry' {
        $enabled = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $disabled = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{ Name = 'Backup'; Command = 'C:\Tools\backup.exe'; Location = 'Common Startup'; User = 'Public' }
                [pscustomobject]@{ Name = 'Kept'; Command = 'C:\Tools\kept.exe'; Location = 'Common Startup'; User = 'Public' }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_StartupCommand' }
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        Mock Get-ItemProperty { [pscustomobject]@{ 'Backup.lnk' = $enabled; 'Kept.lnk' = $enabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
        }
        Mock Get-ItemProperty { [pscustomobject]@{ 'Backup.lnk' = $disabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
        }
        $check = $script:byId['SYS-STARTUP-001']
        $data = & $check.Collect $check.Settings
        ($data.Items | ForEach-Object { $_.Name }) -join ',' | Should -Be 'Kept'
    }

    It 'SYS-STARTUP-001 still drops a machine-wide Run entry that is disabled only in HKLM' {
        $enabled = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $disabled = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        Mock Get-CimInstance {
            $machineRun = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            @(
                [pscustomobject]@{ Name = 'Switched Off By Admin'; Command = 'C:\Tools\a.exe'; Location = $machineRun; User = 'Public' }
                [pscustomobject]@{ Name = 'Kept'; Command = 'C:\Tools\b.exe'; Location = $machineRun; User = 'Public' }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_StartupCommand' }
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        Mock Get-ItemProperty { [pscustomobject]@{ 'Switched Off By Admin' = $disabled; Kept = $enabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter {
            $LiteralPath -eq 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        }
        $check = $script:byId['SYS-STARTUP-001']
        $data = & $check.Collect $check.Settings
        ($data.Items | ForEach-Object { $_.Name }) -join ',' | Should -Be 'Kept'
    }

    It 'SYS-STARTUP-001 reads Run32 for 32-bit Run entries' {
        $enabled = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $disabled = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        Mock Get-CimInstance {
            @([pscustomobject]@{ Name = 'Legacy'; Command = 'C:\Tools\old.exe'; Location = 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; User = 'Public' })
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_StartupCommand' }
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        # The 64-bit Run key calls the same name enabled; only Run32 decides for a WOW6432Node entry.
        Mock Get-ItemProperty { [pscustomobject]@{ Legacy = $enabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*StartupApproved\Run' }
        Mock Get-ItemProperty { [pscustomobject]@{ Legacy = $disabled } }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*StartupApproved\Run32' }
        $check = $script:byId['SYS-STARTUP-001']
        $data = & $check.Collect $check.Settings
        @($data.Items).Count | Should -Be 0
    }

    It 'SYS-STARTUP-001 keeps everything when there is no StartupApproved key' {
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{ Name = 'One'; Command = 'C:\Tools\1.exe'; Location = 'HKU\S-1-5-21-1000-2000-3000-1001\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; User = 'PC-042\user' }
                [pscustomobject]@{ Name = 'Two'; Command = 'C:\Tools\2.exe'; Location = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; User = 'Public' }
                [pscustomobject]@{ Name = 'Three'; Command = 'C:\Tools\3.exe'; Location = 'Startup'; User = 'PC-042\user' }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_StartupCommand' }
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        $check = $script:byId['SYS-STARTUP-001']
        $data = & $check.Collect $check.Settings
        ($data.Items | ForEach-Object { $_.Name }) -join ',' | Should -Be 'One,Two,Three'
    }

    It 'SYS-MEMORY-001 reads the memory sizes and sums the page files' {
        Mock Get-CimInstance {
            [pscustomobject]@{ TotalVisibleMemorySize = [uint64]16777216; FreePhysicalMemory = [uint64]8388608; TotalVirtualMemorySize = [uint64]25165824; FreeVirtualMemory = [uint64]20971520 }
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
        Mock Get-CimInstance { @([pscustomobject]@{ AllocatedBaseSize = [uint32]2048 }, [pscustomobject]@{ AllocatedBaseSize = [uint32]1024 }) } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_PageFileUsage' }
        $check = $script:byId['SYS-MEMORY-001']
        $data = & $check.Collect $check.Settings
        $data.TotalVisibleMemorySize | Should -Be 16777216
        $data.FreePhysicalMemory | Should -Be 8388608
        $data.TotalVirtualMemorySize | Should -Be 25165824
        $data.FreeVirtualMemory | Should -Be 20971520
        $data.PagefileMB | Should -Be 3072
    }

    It 'SYS-MEMORY-001 gives PagefileMB 0 when there is no page file' {
        Mock Get-CimInstance {
            [pscustomobject]@{ TotalVisibleMemorySize = [uint64]16777216; FreePhysicalMemory = [uint64]8388608; TotalVirtualMemorySize = [uint64]16777216; FreeVirtualMemory = [uint64]8388608 }
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
        Mock Get-CimInstance { } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_PageFileUsage' }
        $check = $script:byId['SYS-MEMORY-001']
        (& $check.Collect $check.Settings).PagefileMB | Should -Be 0
    }

    It 'SYS-BSOD-001 maps events to Time and Code and counts recent minidumps' {
        Mock Get-ChekapWinEvent {
            [pscustomobject]@{ TimeCreated = [datetime]'2026-03-05T10:00:00'; Properties = @([pscustomobject]@{ Value = '0x000000d1 (0x1, 0x2)' }) }
        } -ModuleName Chekap
        Mock Get-ChildItem {
            @(
                [pscustomobject]@{ LastWriteTime = (Get-Date).AddDays(-2) }
                [pscustomobject]@{ LastWriteTime = (Get-Date).AddDays(-90) }
            )
        } -ModuleName Chekap -ParameterFilter { $LiteralPath -like '*Minidump' }
        $check = $script:byId['SYS-BSOD-001']
        $data = & $check.Collect $check.Settings
        Should -Invoke Get-ChekapWinEvent -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $FilterHashtable.LogName -eq 'System' -and $FilterHashtable.ProviderName -eq 'Microsoft-Windows-WER-SystemErrorReporting' -and $FilterHashtable.Id -eq 1001 -and $FilterHashtable.StartTime -lt (Get-Date).AddDays(-29)
        }
        @($data.Events).Count | Should -Be 1
        $data.Events[0].Time | Should -Be ([datetime]'2026-03-05T10:00:00')
        $data.Events[0].Code | Should -Be '0x000000d1 (0x1, 0x2)'
        $data.MinidumpCount | Should -Be 1
    }

    It 'SYS-BSOD-001 tolerates denied Minidump' {
        Mock Get-ChekapWinEvent { } -ModuleName Chekap
        Mock Get-ChildItem { throw [System.UnauthorizedAccessException]::new('Access denied') } -ModuleName Chekap -ParameterFilter { $LiteralPath -like '*Minidump' }
        $check = $script:byId['SYS-BSOD-001']
        { & $check.Collect $check.Settings } | Should -Not -Throw
        $data = & $check.Collect $check.Settings
        $data.MinidumpCount | Should -BeNullOrEmpty
        @($data.Events).Count | Should -Be 0
    }

    It 'SYS-BSOD-001 counts 0 minidumps when the folder does not exist' {
        Mock Get-ChekapWinEvent { } -ModuleName Chekap
        Mock Get-ChildItem { Get-ChildItem -LiteralPath (Join-Path $TestDrive 'no-such-folder') -ErrorAction Stop }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like '*Minidump' }
        $check = $script:byId['SYS-BSOD-001']
        $data = & $check.Collect $check.Settings
        $data.MinidumpCount | Should -Be 0
        $data.MinidumpCount | Should -Not -BeNullOrEmpty
    }

    It 'SYS-SHUTDOWN-001 collects the two event lists as dates' {
        Mock Get-ChekapWinEvent {
            @([pscustomobject]@{ TimeCreated = [datetime]'2026-03-01T01:00:00' }, [pscustomobject]@{ TimeCreated = [datetime]'2026-03-02T01:00:00' })
        } -ModuleName Chekap -ParameterFilter { $FilterHashtable.Id -eq 41 }
        Mock Get-ChekapWinEvent { } -ModuleName Chekap -ParameterFilter { $FilterHashtable.Id -eq 6008 }
        $check = $script:byId['SYS-SHUTDOWN-001']
        $data = & $check.Collect $check.Settings
        Should -Invoke Get-ChekapWinEvent -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $FilterHashtable.Id -eq 41 -and $FilterHashtable.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $FilterHashtable.LogName -eq 'System' }
        Should -Invoke Get-ChekapWinEvent -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $FilterHashtable.Id -eq 6008 -and $FilterHashtable.ProviderName -eq 'EventLog' -and $FilterHashtable.LogName -eq 'System' }
        @($data.KernelPower41).Count | Should -Be 2
        $data.KernelPower41[0] | Should -BeOfType [datetime]
        @($data.EventLog6008).Count | Should -Be 0
    }

    It 'SYS-APPCRASH-001 collects exe names and the latest stability index' {
        Mock Get-ChekapWinEvent {
            @([pscustomobject]@{ Properties = @([pscustomobject]@{ Value = 'contoso.exe' }) }, [pscustomobject]@{ Properties = @([pscustomobject]@{ Value = 'fabrikam.exe' }) })
        } -ModuleName Chekap
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{ TimeGenerated = [datetime]'2026-03-01T10:00:00'; SystemStabilityIndex = 7.0 }
                [pscustomobject]@{ TimeGenerated = [datetime]'2026-03-03T10:00:00'; SystemStabilityIndex = 8.5 }
                [pscustomobject]@{ TimeGenerated = [datetime]'2026-03-02T10:00:00'; SystemStabilityIndex = 6.0 }
            )
        } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ReliabilityStabilityMetrics' }
        $check = $script:byId['SYS-APPCRASH-001']
        $data = & $check.Collect $check.Settings
        Should -Invoke Get-ChekapWinEvent -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $FilterHashtable.LogName -eq 'Application' -and $FilterHashtable.ProviderName -eq 'Application Error' -and $FilterHashtable.Id -eq 1000
        }
        ($data.Crashes -join ',') | Should -Be 'contoso.exe,fabrikam.exe'
        $data.StabilityIndex | Should -Be 8.5
    }

    It 'SYS-APPCRASH-001 tolerates reliability class failure' {
        Mock Get-ChekapWinEvent {
            [pscustomobject]@{ Properties = @([pscustomobject]@{ Value = 'contoso.exe' }) }
        } -ModuleName Chekap
        Mock Get-CimInstance { throw 'Invalid class' } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ReliabilityStabilityMetrics' }
        $check = $script:byId['SYS-APPCRASH-001']
        { & $check.Collect $check.Settings } | Should -Not -Throw
        $data = & $check.Collect $check.Settings
        $data.StabilityIndex | Should -BeNullOrEmpty
        @($data.Crashes).Count | Should -Be 1
    }

    It 'SYS-APPCRASH-001 gives a null index and an empty list when nothing is there' {
        Mock Get-ChekapWinEvent { } -ModuleName Chekap
        Mock Get-CimInstance { } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ReliabilityStabilityMetrics' }
        $check = $script:byId['SYS-APPCRASH-001']
        $data = & $check.Collect $check.Settings
        $data.StabilityIndex | Should -BeNullOrEmpty
        @($data.Crashes).Count | Should -Be 0
    }

    It 'SYS-BATTERY-001 returns HasBattery false without calling powercfg' {
        Mock Get-CimInstance { } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_Battery' }
        Mock powercfg { } -ModuleName Chekap
        $check = $script:byId['SYS-BATTERY-001']
        $data = & $check.Collect $check.Settings
        $data.HasBattery | Should -BeFalse
        @($data.Batteries).Count | Should -Be 0
        Should -Invoke powercfg -ModuleName Chekap -Times 0 -Exactly
    }

    It 'SYS-BATTERY-001 reads the battery report XML and removes the file' {
        $report = @'
<?xml version="1.0" encoding="UTF-8"?>
<BatteryReport xmlns="http://schemas.microsoft.com/battery/2012">
  <Batteries>
    <Battery>
      <Id>CONTOSO-BAT0</Id>
      <DesignCapacity>50000</DesignCapacity>
      <FullChargeCapacity>41000</FullChargeCapacity>
      <CycleCount>112</CycleCount>
    </Battery>
    <Battery>
      <Id>CONTOSO-BAT1</Id>
      <DesignCapacity>0</DesignCapacity>
      <FullChargeCapacity>0</FullChargeCapacity>
    </Battery>
  </Batteries>
</BatteryReport>
'@
        Mock Get-CimInstance { [pscustomobject]@{ Name = 'Battery' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_Battery' }
        # The last argument of the real call is the report path.
        Mock powercfg {
            $global:LASTEXITCODE = 0
            Set-Content -LiteralPath $args[-1] -Value $report -Encoding UTF8
        }.GetNewClosure() -ModuleName Chekap
        $check = $script:byId['SYS-BATTERY-001']
        $data = & $check.Collect $check.Settings
        Should -Invoke powercfg -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $args -contains '/batteryreport' -and $args -contains '/xml' -and $args -contains '/output' }
        $data.HasBattery | Should -BeTrue
        @($data.Batteries).Count | Should -Be 2
        $data.Batteries[0].Id | Should -Be 'CONTOSO-BAT0'
        $data.Batteries[0].DesignCapacity | Should -Be 50000
        $data.Batteries[0].FullChargeCapacity | Should -Be 41000
        $data.Batteries[0].CycleCount | Should -Be 112
        $data.Batteries[1].DesignCapacity | Should -Be 0
        Test-Path -LiteralPath (Join-Path $env:TEMP 'chekap-battery.xml') | Should -BeFalse
    }

    It 'SYS-BATTERY-001 throws when powercfg fails and still removes the file' {
        Mock Get-CimInstance { [pscustomobject]@{ Name = 'Battery' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_Battery' }
        Mock powercfg {
            $global:LASTEXITCODE = 1
            Set-Content -LiteralPath $args[-1] -Value 'partial'
        } -ModuleName Chekap
        $check = $script:byId['SYS-BATTERY-001']
        { & $check.Collect $check.Settings } | Should -Throw '*powercfg*1*'
        Test-Path -LiteralPath (Join-Path $env:TEMP 'chekap-battery.xml') | Should -BeFalse
    }
}

Describe 'Test-ChekapHealth' {
    BeforeEach {
        Mock Invoke-ChekapCheck { } -ModuleName Chekap
    }

    It 'runs all System checks in the requested language' {
        Test-ChekapHealth -Language en
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $Language -eq 'en' -and @($Check).Count -eq 10 -and @($Check | Where-Object { $_.Category -ne 'System' }).Count -eq 0
        }
    }

    It 'selects checks by -CheckId, wildcards allowed' {
        Test-ChekapHealth -Language uk -CheckId 'SYS-DISK-*', 'SYS-BSOD-001'
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $Language -eq 'uk' -and (@($Check | ForEach-Object { $_.Id }) -join ',') -eq 'SYS-BSOD-001,SYS-DISK-001'
        }
    }

    It 'warns about an unknown ID and returns nothing' {
        $result = @(Test-ChekapHealth -Language en -CheckId 'SYS-NOPE-999' -WarningVariable warnings -WarningAction SilentlyContinue)
        $result.Count | Should -Be 0
        @($warnings).Count | Should -Be 1
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 0 -Exactly
    }
}

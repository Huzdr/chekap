@{
    Id            = 'SYS-MEMORY-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-operatingsystem'
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-pagefileusage'
        'https://learn.microsoft.com/troubleshoot/windows-client/performance/how-to-determine-the-appropriate-page-file-size-for-64-bit-versions-of-windows'
    )
    Settings      = @{ WarnFreeRamPercent = 10; CriticalCommitPercent = 90 }
    Collect       = {
        # Sizes are in KB, as Windows reports them.
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $pagefile = Get-CimInstance -ClassName Win32_PageFileUsage | Measure-Object -Property AllocatedBaseSize -Sum
        @{
            TotalVisibleMemorySize = [long]$os.TotalVisibleMemorySize
            FreePhysicalMemory     = [long]$os.FreePhysicalMemory
            TotalVirtualMemorySize = [long]$os.TotalVirtualMemorySize
            FreeVirtualMemory      = [long]$os.FreeVirtualMemory
            PagefileMB             = [int]$pagefile.Sum
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        $totalGB = $Data.TotalVisibleMemorySize / 1MB
        $freePercent = 100 * $Data.FreePhysicalMemory / $Data.TotalVisibleMemorySize
        $commitPercent = 100 * ($Data.TotalVirtualMemorySize - $Data.FreeVirtualMemory) / $Data.TotalVirtualMemorySize
        # One memory verdict, the worst one wins.
        if ($commitPercent -ge $Settings.CriticalCommitPercent) {
            @{ Status = 'Critical'; Message = 'CommitHigh'; Args = @($commitPercent) }
        }
        elseif ($freePercent -lt $Settings.WarnFreeRamPercent) {
            @{ Status = 'Warning'; Message = 'LowRam'; Args = @($freePercent) }
        }
        else {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($totalGB, $freePercent) }
        }
        if ($Data.PagefileMB -eq 0) {
            @{ Status = 'Warning'; Message = 'NoPagefile'; Target = 'pagefile' }
        }
    }
}

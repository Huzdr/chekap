@{
    Id            = 'SYS-SHUTDOWN-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/troubleshoot/windows-client/performance/event-id-41-restart'
    )
    Settings      = @{ Days = 30; CriticalCount = 3 }
    Collect       = {
        param($Settings)
        $start = (Get-Date).AddDays(-$Settings.Days)
        @{
            KernelPower41 = @(Get-ChekapWinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $start } | ForEach-Object { $_.TimeCreated })
            EventLog6008  = @(Get-ChekapWinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'EventLog'; Id = 6008; StartTime = $start } | ForEach-Object { $_.TimeCreated })
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        # Both events describe the same kind of shutdown, so the bigger list is the count, not the sum.
        $count = [math]::Max(@($Data.KernelPower41).Count, @($Data.EventLog6008).Count)
        if ($count -eq 0) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($Settings.Days) }
        }
        else {
            $last = (@($Data.KernelPower41) + @($Data.EventLog6008) | Sort-Object -Descending | Select-Object -First 1)
            if ($count -ge $Settings.CriticalCount) {
                @{ Status = 'Critical'; Message = 'Frequent'; Args = @($count, $Settings.Days, $last) }
            }
            else {
                @{ Status = 'Warning'; Message = 'Unexpected'; Args = @($count, $Settings.Days, $last) }
            }
        }
    }
}

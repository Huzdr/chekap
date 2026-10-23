@{
    Id            = 'SYS-UPTIME-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-operatingsystem'
        'https://learn.microsoft.com/troubleshoot/windows-client/setup-upgrade-and-drivers/updates-not-install-with-fast-startup'
    )
    Settings      = @{ WarnDays = 14 }
    Collect       = {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $power = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -ErrorAction SilentlyContinue
        @{
            LastBoot    = [datetime]$os.LastBootUpTime
            Now         = Get-Date
            FastStartup = ($null -ne $power -and $power.HiberbootEnabled -eq 1)
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        $totalDays = ($Data.Now - $Data.LastBoot).TotalDays
        $days = [int][math]::Floor($totalDays)
        if ($totalDays -lt $Settings.WarnDays) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($days) }
        }
        elseif ($Data.FastStartup) {
            @{ Status = 'Warning'; Message = 'LongFastStartup'; Args = @($days) }
        }
        else {
            @{ Status = 'Warning'; Message = 'Long'; Args = @($days) }
        }
    }
}

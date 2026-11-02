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
        $boot = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -ErrorAction SilentlyContinue
        # Fast Startup needs hibernation: after "powercfg /h off" HiberbootEnabled can stay 1 while Shut down is a full shutdown again.
        $hibernation = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -ErrorAction SilentlyContinue
        @{
            LastBoot    = [datetime]$os.LastBootUpTime
            Now         = Get-Date
            FastStartup = ($null -ne $boot -and $boot.HiberbootEnabled -eq 1 -and $null -ne $hibernation -and $hibernation.HibernateEnabled -eq 1)
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

@{
    Id            = 'SYS-STARTUP-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-startupcommand'
        'https://support.microsoft.com/windows/configure-startup-applications-in-windows-115a420a-0bff-4a6f-90e0-1934c844e473'
    )
    Settings      = @{ WarnCount = 15 }
    Collect       = {
        @{
            Items = @(Get-CimInstance -ClassName Win32_StartupCommand | ForEach-Object {
                    @{ Name = [string]$_.Name; Location = [string]$_.Location; User = [string]$_.User }
                })
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        $count = @($Data.Items).Count
        if ($count -ge $Settings.WarnCount) {
            $names = @($Data.Items | Select-Object -First 10 | ForEach-Object { $_.Name }) -join ', '
            @{ Status = 'Warning'; Message = 'Many'; Args = @($count, $names) }
        }
        else {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($count) }
        }
    }
}

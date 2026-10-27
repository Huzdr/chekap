@{
    Id            = 'PRN-SCAN-001'
    Category      = 'Printing'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/wia/-wia-startpage'
        'https://learn.microsoft.com/powershell/module/pnpdevice/get-pnpdevice'
    )
    Settings      = @{}
    Collect       = {
        # With no imaging device the cmdlet writes an error (CmdletizationQuery_NotFound); that is the answer "none".
        $devices = @(Get-PnpDevice -Class Image -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object { @{ Name = [string]$_.FriendlyName; Status = [string]$_.Status } })
        # TriggerStart: Windows starts such a service when a device appears or an app asks for it, so it idles as Stopped (stisvc does).
        $services = @(Get-Service -Name stisvc, ShellHWDetection -ErrorAction SilentlyContinue | ForEach-Object {
                @{
                    Name         = [string]$_.Name
                    Status       = [string]$_.Status
                    StartType    = [string]$_.StartType
                    TriggerStart = [bool](Test-Path -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\{0}\TriggerInfo' -f $_.Name))
                }
            })
        @{ Devices = $devices; Services = $services }
    }
    Evaluate      = {
        param($Data)
        $devices = @($Data.Devices)
        if ($devices.Count -eq 0) {
            return @{ Status = 'Skipped'; Message = 'NoScanner' }
        }
        $found = 0
        foreach ($service in @($Data.Services)) {
            # A stopped trigger-start service is waiting, not broken; only a disabled one is a fault then.
            if ($service.StartType -eq 'Disabled' -or ($service.Status -ne 'Running' -and -not $service.TriggerStart)) {
                $found++
                @{ Status = 'Warning'; Message = 'ServiceStopped'; Target = $service.Name; Args = @($service.Name); Evidence = $service }
            }
        }
        foreach ($device in @($devices | Where-Object { $_.Status -eq 'Error' })) {
            $found++
            @{ Status = 'Warning'; Message = 'DeviceError'; Target = $device.Name; Args = @($device.Name); Evidence = $device }
        }
        if ($found -eq 0) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @((@($devices | ForEach-Object { $_.Name }) -join ', ')) }
        }
    }
}

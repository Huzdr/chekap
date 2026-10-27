@{
    Id            = 'PRN-DEFAULT-001'
    Category      = 'Printing'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-printer'
        'https://learn.microsoft.com/powershell/module/printmanagement/get-printer'
    )
    Settings      = @{}
    Collect       = {
        $state = Get-ChekapPrintState
        if (-not ($state.PrintModule -and $state.SpoolerRunning)) { return $state }

        # Printers counts the real ones: a PC with only PDF and XPS printers has nothing to set a default for.
        $printers = @(Get-Printer | Where-Object { -not (Test-ChekapVirtualPrinterPort -PortName $_.PortName) })
        $default = Get-CimInstance -ClassName Win32_Printer -Filter 'Default = TRUE' | Select-Object -First 1
        # Windows manages the default printer unless this value is 1; it is per user, so it is read from HKCU.
        $legacy = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Name LegacyDefaultPrinterMode -ErrorAction SilentlyContinue).LegacyDefaultPrinterMode
        @{
            PrintModule    = $true
            SpoolerRunning = $true
            Printers       = $printers.Count
            Default        = $(if ($default) { [string]$default.Name })
            WindowsManaged = [bool]($null -eq $legacy -or [int]$legacy -eq 0)
        }
    }
    Evaluate      = {
        param($Data)
        if (-not $Data.PrintModule) { return @{ Status = 'Skipped'; Message = 'NoPrintModule' } }
        if (-not $Data.SpoolerRunning) { return @{ Status = 'Skipped'; Message = 'SpoolerStopped' } }

        if ($Data.Default) {
            if ($Data.WindowsManaged) {
                @{ Status = 'OK'; Message = 'Managed'; Target = $Data.Default; Args = @($Data.Default) }
            }
            else {
                @{ Status = 'OK'; Message = 'Ok'; Target = $Data.Default; Args = @($Data.Default) }
            }
        }
        elseif ($Data.Printers -gt 0) {
            @{ Status = 'Warning'; Message = 'NoDefault'; Args = @($Data.Printers) }
        }
        else {
            @{ Status = 'Skipped'; Message = 'NoPrinters' }
        }
    }
}

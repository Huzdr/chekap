@{
    Id            = 'PRN-DRIVER-001'
    Category      = 'Printing'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/printmanagement/get-printerdriver'
        'https://learn.microsoft.com/powershell/module/printmanagement/remove-printerdriver'
    )
    Settings      = @{}
    Collect       = {
        $state = Get-ChekapPrintState
        if (-not ($state.PrintModule -and $state.SpoolerRunning)) { return $state }

        $drivers = @(Get-PrinterDriver | ForEach-Object { @{ Name = [string]$_.Name; Manufacturer = [string]$_.Manufacturer } })
        $used = @(Get-Printer | ForEach-Object { [string]$_.DriverName } | Sort-Object -Unique)
        @{ PrintModule = $true; SpoolerRunning = $true; Drivers = $drivers; Used = $used }
    }
    Evaluate      = {
        param($Data)
        if (-not $Data.PrintModule) { return @{ Status = 'Skipped'; Message = 'NoPrintModule' } }
        if (-not $Data.SpoolerRunning) { return @{ Status = 'Skipped'; Message = 'SpoolerStopped' } }

        $used = @($Data.Used)
        # The same driver is listed once per architecture (x64, x86), and Microsoft's own drivers are not worth removing.
        $unused = @($Data.Drivers | Where-Object { $_.Manufacturer -ne 'Microsoft' -and $_.Name -notin $used } | ForEach-Object { $_.Name } | Sort-Object -Unique)
        if ($unused.Count -eq 0) {
            return @{ Status = 'OK'; Message = 'Ok' }
        }
        $names = @($unused | Select-Object -First 10) -join ', '
        if ($unused.Count -gt 10) { $names = $names + ', ...' }
        @{ Status = 'OK'; Message = 'Unused'; Args = @($unused.Count, $names); Evidence = @{ Unused = $unused } }
    }
}

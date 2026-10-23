@{
    Id            = 'SYS-BATTERY-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows-hardware/design/device-experiences/powercfg-command-line-options'
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-battery'
    )
    Settings      = @{ WarnPercent = 60; CriticalPercent = 40 }
    Collect       = {
        $hasBattery = @(Get-CimInstance -ClassName Win32_Battery).Count -gt 0
        $batteries = @()
        if ($hasBattery) {
            $path = Join-Path $env:TEMP 'chekap-battery.xml'
            try {
                # The report goes to the file; whatever powercfg prints is not data.
                $null = powercfg /batteryreport /xml /output $path
                if ($LASTEXITCODE -ne 0) { throw "powercfg /batteryreport failed with exit code $LASTEXITCODE" }
                $report = New-Object -TypeName System.Xml.XmlDocument
                $report.Load($path)
                $batteries = @($report.BatteryReport.Batteries.Battery | Where-Object { $null -ne $_ } | ForEach-Object {
                        @{
                            Id                 = [string]$_.Id
                            DesignCapacity     = [long]$_.DesignCapacity
                            FullChargeCapacity = [long]$_.FullChargeCapacity
                            CycleCount         = [int]$_.CycleCount
                        }
                    })
            }
            finally {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
        @{ HasBattery = $hasBattery; Batteries = $batteries }
    }
    Evaluate      = {
        param($Data, $Settings)
        $batteries = @($Data.Batteries)
        # Win32_Battery also lists a UPS; powercfg then reports no battery, which is the same answer as "no battery".
        if (-not $Data.HasBattery -or $batteries.Count -eq 0) {
            @{ Status = 'Skipped'; Message = 'NoBattery' }
        }
        else {
            foreach ($battery in $batteries) {
                if ($battery.DesignCapacity -le 0) {
                    @{ Status = 'Skipped'; Message = 'NoData'; Target = $battery.Id; Evidence = $battery }
                    continue
                }
                $percent = 100 * $battery.FullChargeCapacity / $battery.DesignCapacity
                if ($percent -lt $Settings.CriticalPercent) {
                    @{ Status = 'Critical'; Message = 'Worn'; Target = $battery.Id; Args = @($percent); Evidence = $battery }
                }
                elseif ($percent -lt $Settings.WarnPercent) {
                    @{ Status = 'Warning'; Message = 'Aging'; Target = $battery.Id; Args = @($percent); Evidence = $battery }
                }
                else {
                    @{ Status = 'OK'; Message = 'Ok'; Target = $battery.Id; Args = @($percent); Evidence = $battery }
                }
            }
        }
    }
}

@{
    Id            = 'SYS-BSOD-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows-hardware/drivers/debugger/bug-check-code-reference2'
    )
    Settings      = @{ Days = 30; CriticalCount = 3 }
    Collect       = {
        param($Settings)
        $start = (Get-Date).AddDays(-$Settings.Days)
        $events = @(Get-ChekapWinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $start } | ForEach-Object {
                @{ Time = $_.TimeCreated; Code = [string]$_.Properties[0].Value }
            })
        # The Minidump folder is readable by administrators only: $null means "could not look", 0 means "no dumps".
        try {
            $minidumps = @(Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'Minidump') -Filter '*.dmp' -File -ErrorAction Stop | Where-Object { $_.LastWriteTime -gt $start }).Count
        }
        catch {
            $minidumps = if ($_.CategoryInfo.Category -eq 'ObjectNotFound') { 0 } else { $null }
        }
        @{ Events = $events; MinidumpCount = $minidumps }
    }
    Evaluate      = {
        param($Data, $Settings)
        $count = @($Data.Events).Count
        if ($count -eq 0) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($Settings.Days) }
        }
        else {
            $last = ($Data.Events | Sort-Object -Property { $_.Time } -Descending | Select-Object -First 1).Time
            # The event text is "0x000000d1 (0x..., ...)": only the bug check code itself is useful in a sentence.
            $codes = @($Data.Events | ForEach-Object { $_.Code -replace '\s.*$', '' } | Sort-Object -Unique) -join ', '
            if ($count -ge $Settings.CriticalCount) {
                @{ Status = 'Critical'; Message = 'ManyCrashes'; Args = @($count, $Settings.Days, $last, $codes) }
            }
            else {
                @{ Status = 'Warning'; Message = 'Crashes'; Args = @($count, $Settings.Days, $last, $codes) }
            }
        }
    }
}

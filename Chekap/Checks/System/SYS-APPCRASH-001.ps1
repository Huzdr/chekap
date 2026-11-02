@{
    Id            = 'SYS-APPCRASH-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/previous-versions/windows/desktop/racwmiprov/win32-reliabilitystabilitymetrics'
    )
    Settings      = @{ Days = 7; WarnPerApp = 3 }
    Collect       = {
        param($Settings)
        $start = (Get-Date).AddDays(-$Settings.Days)
        $crashes = @(Get-ChekapWinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Application Error'; Id = 1000; StartTime = $start } | ForEach-Object {
                [string]$_.Properties[0].Value
            })
        # The reliability class is missing or empty on some systems (servers, reliability monitoring switched off): no index, not an error.
        $index = $null
        try {
            $latest = Get-CimInstance -ClassName Win32_ReliabilityStabilityMetrics -ErrorAction Stop | Sort-Object -Property TimeGenerated -Descending | Select-Object -First 1
            if ($null -ne $latest) { $index = [double]$latest.SystemStabilityIndex }
        }
        catch {
            Write-Verbose $_.Exception.Message
        }
        @{ Crashes = $crashes; StabilityIndex = $index }
    }
    Evaluate      = {
        param($Data, $Settings)
        $repeated = @($Data.Crashes | Group-Object | Where-Object { $_.Count -ge $Settings.WarnPerApp } |
                Sort-Object -Property @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { $_.Name } })
        if ($repeated.Count -gt 0) {
            $apps = @($repeated | ForEach-Object { '{0} ({1})' -f $_.Name, $_.Count }) -join ', '
            @{ Status = 'Warning'; Message = 'Crashing'; Args = @($apps, $Settings.Days) }
        }
        elseif ($null -eq $Data.StabilityIndex) {
            @{ Status = 'OK'; Message = 'OkNoIndex'; Args = @(@($Data.Crashes).Count, $Settings.Days) }
        }
        else {
            @{ Status = 'OK'; Message = 'Ok'; Args = @(@($Data.Crashes).Count, $Settings.Days, [math]::Round($Data.StabilityIndex, 1)) }
        }
    }
}

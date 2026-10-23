@{
    Id            = 'NET-TIME-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings'
        'https://learn.microsoft.com/windows/security/threat-protection/security-policy-settings/maximum-tolerance-for-computer-clock-synchronization'
        'https://learn.microsoft.com/windows/security/threat-protection/security-policy-settings/kerberos-policy'
    )
    Settings      = @{ WarnSeconds = 60; CriticalSeconds = 300 }
    Collect       = {
        $parameters = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -ErrorAction SilentlyContinue
        $type = $null
        $ntpServer = $null
        if ($null -ne $parameters) {
            $type = $parameters.Type
            $ntpServer = $parameters.NtpServer
        }
        $system = Get-CimInstance -ClassName Win32_ComputerSystem
        # A domain PC takes its time from the domain (NT5DS); otherwise the first NtpServer entry, without its ",0x9" flags.
        $source = $null
        $firstEntry = @($ntpServer -split '\s+' | Where-Object { $_ }) | Select-Object -First 1
        if ($type -eq 'NT5DS' -and $system.PartOfDomain) { $source = [string]$system.Domain }
        elseif ($firstEntry) { $source = $firstEntry -replace ',0x[0-9a-fA-F]+$', '' }

        $output = @()
        $offset = $null
        if ($source) {
            # Only the data line is read: w32tm translates its headers and writes the offset with a decimal comma on Ukrainian Windows.
            $output = @(w32tm /stripchart /computer:$source /samples:1 /dataonly)
            foreach ($line in $output) {
                if ([string]$line -match '([+-]\d+[.,]\d+)s') {
                    $offset = [double]::Parse(($Matches[1] -replace ',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
                }
            }
        }
        $service = Get-Service -Name 'W32Time' -ErrorAction SilentlyContinue
        $serviceStatus = $null
        if ($null -ne $service) { $serviceStatus = [string]$service.Status }
        @{
            Type          = $type
            NtpServer     = $ntpServer
            Source        = $source
            Output        = $output
            OffsetSeconds = $offset
            ServiceStatus = $serviceStatus
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        if ($null -eq $Data.OffsetSeconds) {
            $source = $Data.Source
            if (-not $source) { $source = '—' }
            return @{ Status = 'Warning'; Message = 'NoSource'; Args = @($source) }
        }
        $seconds = [math]::Abs($Data.OffsetSeconds)
        if ($seconds -ge $Settings.CriticalSeconds) {
            @{ Status = 'Critical'; Message = 'DriftKerberos'; Args = @($seconds) }
        }
        elseif ($seconds -ge $Settings.WarnSeconds) {
            @{ Status = 'Warning'; Message = 'Drift'; Args = @($seconds) }
        }
        else {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($seconds, $Data.Source) }
        }
    }
}

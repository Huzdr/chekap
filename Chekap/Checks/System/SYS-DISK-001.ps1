@{
    Id            = 'SYS-DISK-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-logicaldisk'
        'https://support.microsoft.com/windows/free-up-drive-space-in-windows-85529ccb-c365-490d-b548-831022bc9b32'
    )
    Settings      = @{ CriticalGB = 5; WarnGB = 15; WarnPercent = 10 }
    Collect       = {
        $drive = $env:SystemDrive
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$drive'"
        # Sorted and unique: when this runs as SYSTEM, %TEMP% is the same folder as %SystemRoot%\Temp.
        $paths = @($env:TEMP, (Join-Path $env:SystemRoot 'Temp'), (Join-Path $env:SystemRoot 'SoftwareDistribution\Download')) | Sort-Object -Unique
        $candidates = @(foreach ($path in $paths) {
                $bytes = Get-ChekapFolderSize -Path $path
                if ($null -ne $bytes) { @{ Path = $path; Bytes = $bytes } }
            })
        $limit = (Get-Date).AddDays(-90)
        $oldProfiles = @(Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false -and $null -ne $_.LastUseTime -and $_.LastUseTime -lt $limit }).Count
        @{
            Drive       = $drive
            SizeBytes   = [long]$disk.Size
            FreeBytes   = [long]$disk.FreeSpace
            Candidates  = $candidates
            OldProfiles = $oldProfiles
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        $freeGB = $Data.FreeBytes / 1GB
        $freePercent = 100 * $Data.FreeBytes / $Data.SizeBytes
        # "path: size in GB", biggest first; the unit is in the message text.
        $candidates = @($Data.Candidates | Sort-Object -Property { $_.Bytes } -Descending | ForEach-Object { '{0}: {1:N1}' -f $_.Path, ($_.Bytes / 1GB) }) -join '; '
        if (-not $candidates) { $candidates = '—' }
        if ($freeGB -lt $Settings.CriticalGB) {
            @{ Status = 'Critical'; Message = 'CriticalLow'; Target = $Data.Drive; Args = @($freeGB, $freePercent, $candidates, $Data.OldProfiles) }
        }
        elseif ($freeGB -lt $Settings.WarnGB -or $freePercent -lt $Settings.WarnPercent) {
            @{ Status = 'Warning'; Message = 'Low'; Target = $Data.Drive; Args = @($freeGB, $freePercent, $candidates, $Data.OldProfiles) }
        }
        else {
            @{ Status = 'OK'; Message = 'Ok'; Target = $Data.Drive; Args = @($freeGB, $freePercent) }
        }
    }
}

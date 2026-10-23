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
        $approved = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
        # Names that Task Manager has turned off in one StartupApproved sub-key: REG_BINARY values whose first byte has the low bit set (03, 07).
        $disabledNames = {
            param($Root, $SubKey)
            $key = Get-ItemProperty -LiteralPath "$Root\$approved\$SubKey" -ErrorAction SilentlyContinue
            if ($null -ne $key) {
                $key.PSObject.Properties | Where-Object { $_.Value -is [byte[]] -and $_.Value.Count -gt 0 -and ($_.Value[0] -band 1) } | ForEach-Object { $_.Name }
            }
        }
        $cache = @{}
        # Win32_StartupCommand lists disabled entries too; the Run key entries match by value name, the Startup folder ones by file name.
        $isDisabled = {
            param($Entry)
            $location = [string]$Entry.Location
            $folder = $location -eq 'Startup' -or $location -eq 'Common Startup'
            # Machine-wide entries (HKLM Run, Common Startup) can be switched off by the user in HKCU as well as in HKLM: either one counts.
            if ($location -eq 'Startup') { $roots = @('HKCU:'); $subKey = 'StartupFolder' }
            elseif ($location -eq 'Common Startup') { $roots = @('HKLM:', 'HKCU:'); $subKey = 'StartupFolder' }
            else {
                $subKey = if ($location -like '*\WOW6432Node\*') { 'Run32' } else { 'Run' }
                if ($location -like 'HKLM\*') { $roots = @('HKLM:', 'HKCU:') }
                elseif ($location -match '^HKU\\([^\\]+)\\') { $roots = @("Registry::HKEY_USERS\$($Matches[1])") }
                else { return $false }
            }
            $name = [string]$Entry.Name
            foreach ($root in $roots) {
                if (-not $cache.ContainsKey("$root|$subKey")) { $cache["$root|$subKey"] = @(& $disabledNames $root $subKey) }
                # A Startup folder value is "<file name>.lnk" while the entry name has no extension.
                if (@($cache["$root|$subKey"] | Where-Object { $_ -eq $name -or ($folder -and [System.IO.Path]::GetFileNameWithoutExtension($_) -eq $name) }).Count -gt 0) { return $true }
            }
            $false
        }
        @{
            Items = @(Get-CimInstance -ClassName Win32_StartupCommand | Where-Object { -not (& $isDisabled $_) } | ForEach-Object {
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

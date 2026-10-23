@{
    Id            = 'SYS-REBOOT-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/api/wuapi/nf-wuapi-isysteminformation-get_rebootrequired'
    )
    Settings      = @{}
    Collect       = {
        $files = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        $renames = 0
        if ($null -ne $files -and $null -ne $files.PendingFileRenameOperations) { $renames = @($files.PendingFileRenameOperations).Count }
        @{
            WindowsUpdate   = [bool](Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
            Cbs             = [bool](Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
            FileRenameCount = $renames
        }
    }
    Evaluate      = {
        param($Data)
        $sources = @()
        if ($Data.WindowsUpdate) { $sources += 'Windows Update' }
        if ($Data.Cbs) { $sources += 'CBS' }
        if ($Data.FileRenameCount -gt 0) { $sources += 'PendingFileRenameOperations' }
        if ($sources.Count -eq 0) {
            @{ Status = 'OK'; Message = 'Ok' }
        }
        else {
            @{ Status = 'Warning'; Message = 'Pending'; Args = @(($sources -join ', ')) }
        }
    }
}

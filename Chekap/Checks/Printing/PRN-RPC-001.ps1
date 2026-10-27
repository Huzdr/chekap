@{
    Id            = 'PRN-RPC-001'
    Category      = 'Printing'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://support.microsoft.com/help/4599464'
        'https://support.microsoft.com/help/5005565'
        'https://learn.microsoft.com/powershell/module/printmanagement/get-printer'
    )
    Settings      = @{}
    Collect       = {
        $state = Get-ChekapPrintState
        if (-not ($state.PrintModule -and $state.SpoolerRunning)) { return $state }

        # Absent means the Windows default, which is protection on; only a stored 0 turns it off.
        $privacy = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' -Name RpcAuthnLevelPrivacyEnabled -ErrorAction SilentlyContinue).RpcAuthnLevelPrivacyEnabled
        $printers = @(Get-Printer)
        @{
            PrintModule                 = $true
            SpoolerRunning              = $true
            RpcAuthnLevelPrivacyEnabled = $privacy
            Shared                      = @($printers | Where-Object { $_.Shared -eq $true } | ForEach-Object { [string]$_.Name })
            Connections                 = @($printers | Where-Object { [string]$_.Type -eq 'Connection' } | ForEach-Object { @{ Name = [string]$_.Name; Server = Get-ChekapPrinterServer -Printer $_ } })
            ProductType                 = [int](Get-CimInstance -ClassName Win32_OperatingSystem).ProductType
        }
    }
    Evaluate      = {
        param($Data)
        if (-not $Data.PrintModule) { return @{ Status = 'Skipped'; Message = 'NoPrintModule' } }
        if (-not $Data.SpoolerRunning) { return @{ Status = 'Skipped'; Message = 'SpoolerStopped' } }

        $found = 0
        if ($null -ne $Data.RpcAuthnLevelPrivacyEnabled -and [int]$Data.RpcAuthnLevelPrivacyEnabled -eq 0) {
            $found++
            @{ Status = 'Warning'; Message = 'ProtectionOff' }
        }
        # ProductType 1 is a workstation; servers and domain controllers are meant to share printers.
        if ($Data.ProductType -eq 1 -and @($Data.Shared).Count -gt 0) {
            $found++
            @{ Status = 'Warning'; Message = 'WorkstationShare'; Args = @((@($Data.Shared) -join ', ')) }
        }
        if (@($Data.Connections).Count -gt 0) {
            $found++
            @{ Status = 'OK'; Message = 'Client'; Args = @(@($Data.Connections).Count) }
        }
        if ($found -eq 0) {
            @{ Status = 'OK'; Message = 'Ok' }
        }
    }
}

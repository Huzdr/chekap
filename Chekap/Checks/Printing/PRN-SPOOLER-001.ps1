@{
    Id            = 'PRN-SPOOLER-001'
    Category      = 'Printing'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/microsoft.powershell.management/get-service'
        'https://learn.microsoft.com/defender-for-identity/security-posture-assessments/identity-infrastructure'
        'https://learn.microsoft.com/windows-server/security/windows-services/security-guidelines-for-disabling-system-services-in-windows-server-2016'
    )
    Settings      = @{}
    Collect       = {
        # No SilentlyContinue: Windows without a Spooler service is broken, and that should show as an Error, not as a verdict.
        $service = Get-Service -Name Spooler
        @{
            Status      = [string]$service.Status
            StartType   = [string]$service.StartType
            ProductType = [int](Get-CimInstance -ClassName Win32_OperatingSystem).ProductType
        }
    }
    Evaluate      = {
        param($Data)
        if ($Data.StartType -eq 'Disabled') {
            # Microsoft advises switching the spooler off on domain controllers (ProductType 2) and servers (3) that do not print.
            if ($Data.ProductType -in 2, 3) {
                @{ Status = 'OK'; Message = 'DisabledServer' }
            }
            else {
                @{ Status = 'Warning'; Message = 'Disabled' }
            }
        }
        elseif ($Data.Status -ne 'Running') {
            @{ Status = 'Critical'; Message = 'Stopped' }
        }
        elseif ($Data.StartType -ne 'Automatic') {
            @{ Status = 'Warning'; Message = 'NotAuto' }
        }
        else {
            @{ Status = 'OK'; Message = 'Ok' }
        }
    }
}

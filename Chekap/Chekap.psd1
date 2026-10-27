@{
    RootModule            = 'Chekap.psm1'
    ModuleVersion         = '0.1.0'
    GUID                  = '15c3df6d-1d15-417b-b8ba-1833614e0400'
    Author                = 'Denys Huzar (Huzdr)'
    Copyright             = '(c) 2026 Denys Huzar'
    Description           = 'Bilingual (Ukrainian/English) diagnostics for Windows sysadmins: finds common problems with printing, networking and PC health and explains them in plain language.'
    PowerShellVersion     = '5.1'
    CompatiblePSEditions  = @('Desktop', 'Core')
    FormatsToProcess      = @('Chekap.format.ps1xml')
    FunctionsToExport     = @('Get-ChekapCheck', 'Get-ChekapConfig', 'Invoke-ChekapAudit', 'Set-ChekapConfig', 'Test-ChekapHealth', 'Test-ChekapNetwork', 'Test-ChekapPrinting')
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @()
    PrivateData           = @{
        PSData = @{
            Tags       = @('diagnostics', 'sysadmin', 'windows', 'troubleshooting', 'ukrainian')
            LicenseUri = 'https://github.com/Huzdr/chekap/blob/main/LICENSE'
            ProjectUri = 'https://github.com/Huzdr/chekap'
        }
    }
}

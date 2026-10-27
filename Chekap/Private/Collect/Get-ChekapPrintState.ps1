function Get-ChekapPrintState {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Get-Printer, Get-PrintJob and Win32_Printer fail when the spooler is stopped or the PrintManagement module is missing.
    # A check reads this first and returns early, so that case is a Skipped verdict and not an Error.
    $service = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    @{
        PrintModule    = [bool](Get-Command -Name Get-Printer -ErrorAction SilentlyContinue)
        SpoolerRunning = [bool]($null -ne $service -and [string]$service.Status -eq 'Running')
    }
}

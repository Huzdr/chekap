function Get-ChekapPrinterServer {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Printer
    )

    # A printer connected from another computer is named \\server\share; ComputerName is the fallback.
    if ([string]$Printer.Name -match '^\\\\([^\\]+)\\') { return $Matches[1] }
    ([string]$Printer.ComputerName).Trim('\')
}

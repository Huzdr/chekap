function Test-ChekapVirtualPrinterPort {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$PortName
    )

    # Ports that never reach a device on the network: print to file, PDF, XPS, OneNote, fax, and RDP redirection (TS001).
    foreach ($pattern in 'PORTPROMPT:*', 'nul:*', 'FILE:*', 'SHRFAX:*', 'XPS*', '*OneNote*', '*PDF*', 'TS*') {
        if ($PortName -like $pattern) { return $true }
    }
    $false
}

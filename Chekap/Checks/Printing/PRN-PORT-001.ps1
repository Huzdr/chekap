@{
    Id            = 'PRN-PORT-001'
    Category      = 'Printing'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/printmanagement/get-printerport'
        'https://learn.microsoft.com/powershell/module/printmanagement/get-printer'
    )
    # BudgetMs bounds the whole check: a power cut that takes down every printer must not cost one TimeoutMs per printer.
    Settings      = @{ TimeoutMs = 1000; BudgetMs = 8000 }
    Collect       = {
        param($Settings)
        $state = Get-ChekapPrintState
        if (-not ($state.PrintModule -and $state.SpoolerRunning)) { return $state }

        $ports = @{}
        foreach ($record in @(Get-PrinterPort)) { $ports[[string]$record.Name] = $record }

        # Kind: Connection (shared by another computer), Network (TCP/IP or IPP, has Host and Port), Wsd (no fixed address),
        # Virtual (PDF, XPS, file) or Local (USB, LPT, COM).
        $printers = @(foreach ($printer in @(Get-Printer)) {
                $entry = @{ Name = [string]$printer.Name; Type = [string]$printer.Type; PortName = [string]$printer.PortName; Status = [string]$printer.PrinterStatus; Server = ''; Kind = 'Local'; Host = $null; Port = 0 }
                $record = $ports[$entry.PortName]
                $server = Get-ChekapPrinterServer -Printer $printer
                $uri = $null
                if ($entry.Type -eq 'Connection' -and $server) {
                    $entry.Kind = 'Connection'
                    $entry.Server = $server
                    $entry.Host = $server
                    $entry.Port = 445
                }
                elseif ($record -and $record.PrinterHostAddress) {
                    # A real TCP/IP port wins over the name of the port: a port called TS_Office is still a network port.
                    $entry.Kind = 'Network'
                    $entry.Host = [string]$record.PrinterHostAddress
                    # LPR mode (Protocol 2) listens on 515 whatever PortNumber says. For raw printing, PortNumber 0 means none was set: 9100.
                    $entry.Port = if ([int]$record.Protocol -eq 2) { 515 } elseif ([int]$record.PortNumber -gt 0) { [int]$record.PortNumber } else { 9100 }
                }
                elseif ([uri]::TryCreate($entry.PortName, [System.UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -in 'http', 'https', 'ipp', 'ipps') {
                    # The port written in the URL, else the scheme's own (http 80, https 443). [uri] knows no port for ipp and ipps (-1): ipp is 631, ipps (IPP over TLS) is 443.
                    $entry.Kind = 'Network'
                    $entry.Host = $uri.DnsSafeHost
                    $entry.Port = if ($uri.Port -gt 0) { $uri.Port } elseif ($uri.Scheme -eq 'ipps') { 443 } else { 631 }
                }
                elseif ($entry.PortName -like 'WSD*') {
                    $entry.Kind = 'Wsd'
                }
                elseif (Test-ChekapVirtualPrinterPort -PortName $entry.PortName) {
                    $entry.Kind = 'Virtual'
                }
                $entry
            })

        # Reachable has an entry only for a printer whose endpoint was probed. Printers that share an endpoint (one print server) share one probe.
        $reachable = @{}
        $answers = @{}
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($entry in @($printers | Where-Object { $_.Host })) {
            $endpoint = '{0}:{1}' -f $entry.Host, $entry.Port
            if (-not $answers.ContainsKey($endpoint)) {
                if ($watch.ElapsedMilliseconds -ge $Settings.BudgetMs) { continue }
                $answers[$endpoint] = [bool](Test-ChekapTcpPort -ComputerName $entry.Host -Port $entry.Port -TimeoutMs $Settings.TimeoutMs)
            }
            $reachable[$entry.Name] = $answers[$endpoint]
        }
        @{ PrintModule = $true; SpoolerRunning = $true; Printers = $printers; Reachable = $reachable }
    }
    Evaluate      = {
        param($Data)
        if (-not $Data.PrintModule) { return @{ Status = 'Skipped'; Message = 'NoPrintModule' } }
        if (-not $Data.SpoolerRunning) { return @{ Status = 'Skipped'; Message = 'SpoolerStopped' } }

        $network = @($Data.Printers | Where-Object { $_.Kind -in 'Network', 'Wsd', 'Connection' })
        if ($network.Count -eq 0) {
            return @{ Status = 'OK'; Message = 'NoNetworkPrinters' }
        }
        foreach ($printer in $network) {
            $evidence = @{ Printer = $printer.Name; Kind = $printer.Kind; Host = $printer.Host; Port = $printer.Port; Status = $printer.Status }
            if ($printer.Kind -eq 'Wsd') {
                @{ Status = 'OK'; Message = 'Wsd'; Target = $printer.Name; Evidence = $evidence }
            }
            elseif (-not $Data.Reachable.ContainsKey($printer.Name)) {
                @{ Status = 'Skipped'; Message = 'NotTested'; Target = $printer.Name; Evidence = $evidence }
            }
            elseif (-not $Data.Reachable[$printer.Name]) {
                @{ Status = 'Critical'; Message = 'Unreachable'; Target = $printer.Name; Args = @($printer.Host, $printer.Port); Evidence = $evidence }
            }
            elseif ($printer.Status -match 'Offline') {
                @{ Status = 'Warning'; Message = 'Offline'; Target = $printer.Name; Args = @($printer.Host, $printer.Port); Evidence = $evidence }
            }
            else {
                @{ Status = 'OK'; Message = 'Ok'; Target = $printer.Name; Args = @($printer.Host, $printer.Port); Evidence = $evidence }
            }
        }
    }
}

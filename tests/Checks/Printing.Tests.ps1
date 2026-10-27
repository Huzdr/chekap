BeforeDiscovery {
    $now = [datetime]'2026-05-04T12:00:00'
    $dependent = 'PRN-QUEUE-001', 'PRN-PORT-001', 'PRN-DEFAULT-001', 'PRN-DRIVER-001', 'PRN-RPC-001'

    # Data of a PC where the print cmdlets work; the Skipped fixtures below say otherwise.
    $ready = { param($extra) $data = @{ PrintModule = $true; SpoolerRunning = $true }; foreach ($key in $extra.Keys) { $data[$key] = $extra[$key] }; $data }
    $spooler = { param($status, $startType, $productType) @{ Status = $status; StartType = $startType; ProductType = $productType } }
    $job = { param($printer, $id, $status, $minutes) @{ Printer = $printer; Id = $id; Status = $status; Submitted = $now.AddMinutes(-$minutes) } }
    $printer = { param($name, $kind, $hostName, $port, $status) @{ Name = $name; Type = 'Local'; PortName = 'IP_192.0.2.50'; Status = $status; Server = ''; Kind = $kind; Host = $hostName; Port = $port } }
    $rpc = { param($privacy, $productType, $shared, $connections) & $ready @{ RpcAuthnLevelPrivacyEnabled = $privacy; ProductType = $productType; Shared = $shared; Connections = $connections } }
    $driver = { param($name, $manufacturer) @{ Name = $name; Manufacturer = $manufacturer } }
    $device = { param($name, $status) @{ Name = $name; Status = $status } }
    $service = { param($name, $status, $startType, $triggerStart) @{ Name = $name; Status = $status; StartType = $startType; TriggerStart = $triggerStart } }
    $runningServices = @((& $service 'stisvc' 'Running' 'Automatic' $true), (& $service 'ShellHWDetection' 'Running' 'Automatic' $false))
    $twelveDrivers = 1..12 | ForEach-Object { & $driver ('Contoso Driver {0:D2}' -f $_) 'Contoso' }

    # Every spooler-dependent check answers the same way when the module or the spooler is missing.
    $skipCases = foreach ($id in $dependent) {
        @{ Id = $id; Name = 'no PrintManagement module is NoPrintModule'; Data = @{ PrintModule = $false; SpoolerRunning = $true }; Expect = @(@{ Status = 'Skipped'; Message = 'NoPrintModule' }) }
        @{ Id = $id; Name = 'a stopped spooler is SpoolerStopped'; Data = @{ PrintModule = $true; SpoolerRunning = $false }; Expect = @(@{ Status = 'Skipped'; Message = 'SpoolerStopped' }) }
        @{ Id = $id; Name = 'both missing is NoPrintModule, the module comes first'; Data = @{ PrintModule = $false; SpoolerRunning = $false }; Expect = @(@{ Status = 'Skipped'; Message = 'NoPrintModule' }) }
    }

    # One row per Message of every check. Expect lists the verdicts in order; Args is compared as a joined string.
    $script:evaluateCases = @($skipCases) + @(
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a running automatic spooler is OK'; Data = (& $spooler 'Running' 'Automatic' 1); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a running automatic spooler on a server is OK'; Data = (& $spooler 'Running' 'Automatic' 3); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a stopped spooler is Stopped'; Data = (& $spooler 'Stopped' 'Automatic' 1); Expect = @(@{ Status = 'Critical'; Message = 'Stopped' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a stopped manual spooler is Stopped, not NotAuto'; Data = (& $spooler 'Stopped' 'Manual' 1); Expect = @(@{ Status = 'Critical'; Message = 'Stopped' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a spooler that is neither running nor stopped is Stopped'; Data = (& $spooler 'StopPending' 'Automatic' 1); Expect = @(@{ Status = 'Critical'; Message = 'Stopped' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a running manual spooler is NotAuto'; Data = (& $spooler 'Running' 'Manual' 1); Expect = @(@{ Status = 'Warning'; Message = 'NotAuto' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a disabled spooler on a workstation is Disabled'; Data = (& $spooler 'Stopped' 'Disabled' 1); Expect = @(@{ Status = 'Warning'; Message = 'Disabled' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a disabled spooler on a domain controller is DisabledServer'; Data = (& $spooler 'Stopped' 'Disabled' 2); Expect = @(@{ Status = 'OK'; Message = 'DisabledServer' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a disabled spooler on a member server is DisabledServer'; Data = (& $spooler 'Stopped' 'Disabled' 3); Expect = @(@{ Status = 'OK'; Message = 'DisabledServer' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a disabled spooler with an unknown product type is Disabled'; Data = (& $spooler 'Stopped' 'Disabled' 0); Expect = @(@{ Status = 'Warning'; Message = 'Disabled' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a disabled spooler that still runs is judged by its start type'; Data = (& $spooler 'Running' 'Disabled' 1); Expect = @(@{ Status = 'Warning'; Message = 'Disabled' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a Spooler service that is not on the PC is Skipped NoSpooler, not Stopped'; Data = (& $spooler '' '' 1); Expect = @(@{ Status = 'Skipped'; Message = 'NoSpooler' }) }
        @{ Id = 'PRN-SPOOLER-001'; Name = 'a missing Spooler service is NoSpooler on a server too'; Data = (& $spooler '' '' 2); Expect = @(@{ Status = 'Skipped'; Message = 'NoSpooler' }) }

        @{ Id = 'PRN-QUEUE-001'; Name = 'no jobs is OK with a zero count'; Data = (& $ready @{ Jobs = @(); Now = $now }); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(0) }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'a fresh job is OK with the total'; Data = (& $ready @{ Jobs = @((& $job 'PRN-2F-HP' 1 'Printing' 5)); Now = $now }); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(1) }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'a combined status without Error or Deleting is not stuck'; Data = (& $ready @{ Jobs = @((& $job 'PRN-2F-HP' 1 'Spooling, Printing' 10)); Now = $now }); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'just under StuckMinutes is OK'; Data = (& $ready @{ Jobs = @((& $job 'PRN-2F-HP' 1 'Normal' 59.9)); Now = $now }); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'exactly StuckMinutes is Stuck'; Data = (& $ready @{ Jobs = @((& $job 'PRN-2F-HP' 1 'Normal' 60)); Now = $now }); Expect = @(@{ Status = 'Warning'; Message = 'Stuck'; Target = 'PRN-2F-HP'; Args = @(1, 60) }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'a job in Error is Stuck however young'; Data = (& $ready @{ Jobs = @((& $job 'PRN-2F-HP' 1 'Error' 1)); Now = $now }); Expect = @(@{ Status = 'Warning'; Message = 'Stuck'; Target = 'PRN-2F-HP'; Args = @(1, 1) }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'a job being Deleted is Stuck'; Data = (& $ready @{ Jobs = @((& $job 'PRN-2F-HP' 1 'Deleting' 3)); Now = $now }); Expect = @(@{ Status = 'Warning'; Message = 'Stuck'; Args = @(1, 3) }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'Error inside a combined status is Stuck'; Data = (& $ready @{ Jobs = @((& $job 'PRN-2F-HP' 1 'Error, Printing' 2)); Now = $now }); Expect = @(@{ Status = 'Warning'; Message = 'Stuck' }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'one verdict per printer with the count and the oldest stuck job'; Data = (& $ready @{ Jobs = @((& $job 'PRN-2F-HP' 1 'Normal' 70), (& $job 'PRN-2F-HP' 2 'Normal' 125), (& $job 'PRN-2F-HP' 3 'Normal' 4)); Now = $now }); Expect = @(@{ Status = 'Warning'; Message = 'Stuck'; Target = 'PRN-2F-HP'; Args = @(2, 125) }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'only the printer with stuck jobs is reported, not an OK as well'; Data = (& $ready @{ Jobs = @((& $job 'PRN-1F-HP' 1 'Printing' 2), (& $job 'PRN-2F-HP' 2 'Error' 9)); Now = $now }); Expect = @(@{ Status = 'Warning'; Message = 'Stuck'; Target = 'PRN-2F-HP' }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'every printer with stuck jobs gets a verdict, in the order the printers were listed, Cyrillic included'; Data = (& $ready @{ Jobs = @((& $job 'Принтер бухгалтерії' 1 'Error' 9), (& $job 'PRN-2F-HP' 2 'Error' 9), (& $job 'Принтер бухгалтерії' 3 'Error' 20)); Now = $now }); Expect = @(@{ Status = 'Warning'; Message = 'Stuck'; Target = 'Принтер бухгалтерії'; Args = @(2, 20) }, @{ Status = 'Warning'; Message = 'Stuck'; Target = 'PRN-2F-HP'; Args = @(1, 9) }) }
        @{ Id = 'PRN-QUEUE-001'; Name = 'a job without a submit time is judged by its status only'; Data = (& $ready @{ Jobs = @(@{ Printer = 'PRN-2F-HP'; Id = 1; Status = 'Normal'; Submitted = $null }); Now = $now }); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(1) }) }

        @{ Id = 'PRN-PORT-001'; Name = 'no printers is NoNetworkPrinters'; Data = (& $ready @{ Printers = @(); Reachable = @{} }); Expect = @(@{ Status = 'OK'; Message = 'NoNetworkPrinters' }) }
        @{ Id = 'PRN-PORT-001'; Name = 'local and virtual printers are not network printers'; Data = (& $ready @{ Printers = @((& $printer 'Microsoft Print to PDF' 'Virtual' $null 0 'Normal'), (& $printer 'USB-HP' 'Local' $null 0 'Normal')); Reachable = @{} }); Expect = @(@{ Status = 'OK'; Message = 'NoNetworkPrinters' }) }
        @{ Id = 'PRN-PORT-001'; Name = 'a printer that answers is OK with host and port'; Data = (& $ready @{ Printers = @((& $printer 'PRN-2F-HP' 'Network' '192.0.2.50' 9100 'Normal')); Reachable = @{ 'PRN-2F-HP' = $true } }); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'PRN-2F-HP'; Args = @('192.0.2.50', 9100) }) }
        @{ Id = 'PRN-PORT-001'; Name = 'a printer that is silent is Unreachable'; Data = (& $ready @{ Printers = @((& $printer 'PRN-2F-HP' 'Network' '192.0.2.50' 9100 'Normal')); Reachable = @{ 'PRN-2F-HP' = $false } }); Expect = @(@{ Status = 'Critical'; Message = 'Unreachable'; Target = 'PRN-2F-HP'; Args = @('192.0.2.50', 9100) }) }
        @{ Id = 'PRN-PORT-001'; Name = 'a printer that answers but is Offline for Windows is Offline'; Data = (& $ready @{ Printers = @((& $printer 'PRN-2F-HP' 'Network' '192.0.2.50' 9100 'Offline')); Reachable = @{ 'PRN-2F-HP' = $true } }); Expect = @(@{ Status = 'Warning'; Message = 'Offline'; Target = 'PRN-2F-HP'; Args = @('192.0.2.50', 9100) }) }
        @{ Id = 'PRN-PORT-001'; Name = 'a silent printer that is also Offline is Unreachable'; Data = (& $ready @{ Printers = @((& $printer 'PRN-2F-HP' 'Network' '192.0.2.50' 9100 'Offline')); Reachable = @{ 'PRN-2F-HP' = $false } }); Expect = @(@{ Status = 'Critical'; Message = 'Unreachable' }) }
        @{ Id = 'PRN-PORT-001'; Name = 'a WSD printer is Wsd and needs no test'; Data = (& $ready @{ Printers = @((& $printer 'PRN-2F-HP' 'Wsd' $null 0 'Normal')); Reachable = @{} }); Expect = @(@{ Status = 'OK'; Message = 'Wsd'; Target = 'PRN-2F-HP' }) }
        @{ Id = 'PRN-PORT-001'; Name = 'a shared printer is judged by its print server'; Data = (& $ready @{ Printers = @((& $printer '\\PRINT-SRV\HP-2F' 'Connection' 'PRINT-SRV' 445 'Normal')); Reachable = @{ '\\PRINT-SRV\HP-2F' = $true } }); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = '\\PRINT-SRV\HP-2F'; Args = @('PRINT-SRV', 445) }) }
        @{ Id = 'PRN-PORT-001'; Name = 'a print server that is silent is Unreachable'; Data = (& $ready @{ Printers = @((& $printer '\\PRINT-SRV\HP-2F' 'Connection' 'PRINT-SRV' 445 'Normal')); Reachable = @{ '\\PRINT-SRV\HP-2F' = $false } }); Expect = @(@{ Status = 'Critical'; Message = 'Unreachable'; Args = @('PRINT-SRV', 445) }) }
        @{ Id = 'PRN-PORT-001'; Name = 'a printer that was not probed is NotTested, not Unreachable'; Data = (& $ready @{ Printers = @((& $printer 'PRN-2F-HP' 'Network' '192.0.2.50' 9100 'Normal')); Reachable = @{} }); Expect = @(@{ Status = 'Skipped'; Message = 'NotTested'; Target = 'PRN-2F-HP' }) }
        @{ Id = 'PRN-PORT-001'; Name = 'every network printer gets a verdict in order, virtual ones none, Cyrillic name kept'; Data = (& $ready @{ Printers = @((& $printer 'Microsoft Print to PDF' 'Virtual' $null 0 'Normal'), (& $printer 'Принтер бухгалтерії' 'Network' '192.0.2.51' 9100 'Normal'), (& $printer 'PRN-2F-HP' 'Network' '192.0.2.50' 631 'Normal'), (& $printer 'PRN-3F-HP' 'Wsd' $null 0 'Normal')); Reachable = @{ 'Принтер бухгалтерії' = $false } }); Expect = @(@{ Status = 'Critical'; Message = 'Unreachable'; Target = 'Принтер бухгалтерії'; Args = @('192.0.2.51', 9100) }, @{ Status = 'Skipped'; Message = 'NotTested'; Target = 'PRN-2F-HP' }, @{ Status = 'OK'; Message = 'Wsd'; Target = 'PRN-3F-HP' }) }

        @{ Id = 'PRN-DEFAULT-001'; Name = 'a default printer under Windows control is Managed'; Data = (& $ready @{ Printers = 2; Default = 'PRN-2F-HP'; WindowsManaged = $true }); Expect = @(@{ Status = 'OK'; Message = 'Managed'; Target = 'PRN-2F-HP'; Args = @('PRN-2F-HP') }) }
        @{ Id = 'PRN-DEFAULT-001'; Name = 'a default printer chosen by the user is OK'; Data = (& $ready @{ Printers = 2; Default = 'Принтер бухгалтерії'; WindowsManaged = $false }); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'Принтер бухгалтерії'; Args = @('Принтер бухгалтерії') }) }
        @{ Id = 'PRN-DEFAULT-001'; Name = 'a virtual default printer still counts as a default'; Data = (& $ready @{ Printers = 0; Default = 'Microsoft Print to PDF'; WindowsManaged = $false }); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @('Microsoft Print to PDF') }) }
        @{ Id = 'PRN-DEFAULT-001'; Name = 'real printers but no default is NoDefault'; Data = (& $ready @{ Printers = 2; Default = $null; WindowsManaged = $false }); Expect = @(@{ Status = 'Warning'; Message = 'NoDefault'; Args = @(2) }) }
        @{ Id = 'PRN-DEFAULT-001'; Name = 'no default under Windows control is still NoDefault'; Data = (& $ready @{ Printers = 1; Default = $null; WindowsManaged = $true }); Expect = @(@{ Status = 'Warning'; Message = 'NoDefault' }) }
        @{ Id = 'PRN-DEFAULT-001'; Name = 'no real printer and no default is NoPrinters'; Data = (& $ready @{ Printers = 0; Default = $null; WindowsManaged = $true }); Expect = @(@{ Status = 'Skipped'; Message = 'NoPrinters' }) }

        @{ Id = 'PRN-DRIVER-001'; Name = 'no drivers at all is OK'; Data = (& $ready @{ Drivers = @(); Used = @() }); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-DRIVER-001'; Name = 'drivers that are all in use are OK'; Data = (& $ready @{ Drivers = @((& $driver 'Contoso Laser' 'Contoso')); Used = @('Contoso Laser') }); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-DRIVER-001'; Name = 'an unused Microsoft driver is not reported'; Data = (& $ready @{ Drivers = @((& $driver 'Microsoft XPS Class Driver' 'Microsoft')); Used = @() }); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-DRIVER-001'; Name = 'an unused third-party driver is Unused with the count and the name'; Data = (& $ready @{ Drivers = @((& $driver 'Contoso Laser' 'Contoso'), (& $driver 'Microsoft XPS Class Driver' 'Microsoft')); Used = @() }); Expect = @(@{ Status = 'OK'; Message = 'Unused'; Args = @(1, 'Contoso Laser') }) }
        @{ Id = 'PRN-DRIVER-001'; Name = 'the same driver for x64 and x86 is one driver'; Data = (& $ready @{ Drivers = @((& $driver 'Contoso Laser' 'Contoso'), (& $driver 'Contoso Laser' 'Contoso')); Used = @() }); Expect = @(@{ Status = 'OK'; Message = 'Unused'; Args = @(1, 'Contoso Laser') }) }
        @{ Id = 'PRN-DRIVER-001'; Name = 'the used driver is matched without regard to case'; Data = (& $ready @{ Drivers = @((& $driver 'Contoso Laser' 'Contoso')); Used = @('CONTOSO LASER') }); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-DRIVER-001'; Name = 'unused drivers are listed sorted, joined by a comma'; Data = (& $ready @{ Drivers = @((& $driver 'Fabrikam Plotter' 'Fabrikam'), (& $driver 'Contoso Laser' 'Contoso'), (& $driver 'Fabrikam Inkjet' 'Fabrikam')); Used = @('Fabrikam Inkjet') }); Expect = @(@{ Status = 'OK'; Message = 'Unused'; Args = @(2, 'Contoso Laser, Fabrikam Plotter') }) }
        @{ Id = 'PRN-DRIVER-001'; Name = 'a long list shows the first ten names and the full count'; Data = (& $ready @{ Drivers = $twelveDrivers; Used = @() }); Expect = @(@{ Status = 'OK'; Message = 'Unused'; Args = @(12, 'Contoso Driver 01, Contoso Driver 02, Contoso Driver 03, Contoso Driver 04, Contoso Driver 05, Contoso Driver 06, Contoso Driver 07, Contoso Driver 08, Contoso Driver 09, Contoso Driver 10, ...') }) }

        @{ Id = 'PRN-RPC-001'; Name = 'no registry value, no sharing, no connections is OK'; Data = (& $rpc $null 1 @() @()); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-RPC-001'; Name = 'protection switched on explicitly is OK'; Data = (& $rpc 1 1 @() @()); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-RPC-001'; Name = 'the value 0 is ProtectionOff'; Data = (& $rpc 0 1 @() @()); Expect = @(@{ Status = 'Warning'; Message = 'ProtectionOff' }) }
        @{ Id = 'PRN-RPC-001'; Name = 'a workstation that shares printers is WorkstationShare with their names'; Data = (& $rpc $null 1 @('PRN-2F-HP', 'Принтер бухгалтерії') @()); Expect = @(@{ Status = 'Warning'; Message = 'WorkstationShare'; Args = @('PRN-2F-HP, Принтер бухгалтерії') }) }
        @{ Id = 'PRN-RPC-001'; Name = 'a server that shares printers is OK'; Data = (& $rpc $null 3 @('PRN-2F-HP') @()); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-RPC-001'; Name = 'a domain controller that shares printers is OK'; Data = (& $rpc $null 2 @('PRN-2F-HP') @()); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-RPC-001'; Name = 'printer connections are Client with their count'; Data = (& $rpc $null 1 @() @(@{ Name = '\\PRINT-SRV\HP-2F'; Server = 'PRINT-SRV' }, @{ Name = '\\PRINT-SRV\HP-3F'; Server = 'PRINT-SRV' })); Expect = @(@{ Status = 'OK'; Message = 'Client'; Args = @(2) }) }
        @{ Id = 'PRN-RPC-001'; Name = 'every finding is reported, in order, and OK is left out'; Data = (& $rpc 0 1 @('PRN-2F-HP') @(@{ Name = '\\PRINT-SRV\HP-2F'; Server = 'PRINT-SRV' })); Expect = @(@{ Status = 'Warning'; Message = 'ProtectionOff' }, @{ Status = 'Warning'; Message = 'WorkstationShare' }, @{ Status = 'OK'; Message = 'Client'; Args = @(1) }) }

        @{ Id = 'PRN-SCAN-001'; Name = 'no imaging device is NoScanner'; Data = @{ Devices = @(); Services = $runningServices }; Expect = @(@{ Status = 'Skipped'; Message = 'NoScanner' }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'no imaging device is NoScanner even when a service is stopped'; Data = @{ Devices = @(); Services = @((& $service 'stisvc' 'Stopped' 'Disabled' $true)) }; Expect = @(@{ Status = 'Skipped'; Message = 'NoScanner' }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'a device that works with running services is OK with its name'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'OK')); Services = $runningServices }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @('Contoso Scan 3000') }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'several devices are listed in order, joined by a comma'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'OK'), (& $device 'Integrated Camera' 'OK')); Services = $runningServices }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @('Contoso Scan 3000, Integrated Camera') }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'a device in Error is DeviceError'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'Error')); Services = $runningServices }; Expect = @(@{ Status = 'Warning'; Message = 'DeviceError'; Target = 'Contoso Scan 3000'; Args = @('Contoso Scan 3000') }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'a device that is not in Error is not flagged, only Error is'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'Unknown')); Services = $runningServices }; Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'a stopped service that must run is ServiceStopped'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'OK')); Services = @((& $service 'stisvc' 'Running' 'Automatic' $true), (& $service 'ShellHWDetection' 'Stopped' 'Automatic' $false)) }; Expect = @(@{ Status = 'Warning'; Message = 'ServiceStopped'; Target = 'ShellHWDetection'; Args = @('ShellHWDetection') }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'a stopped trigger-start service waits for its trigger and is not flagged'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'OK')); Services = @((& $service 'stisvc' 'Stopped' 'Automatic' $true), (& $service 'ShellHWDetection' 'Running' 'Automatic' $false)) }; Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'a disabled trigger-start service is ServiceStopped'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'OK')); Services = @((& $service 'stisvc' 'Stopped' 'Disabled' $true), (& $service 'ShellHWDetection' 'Running' 'Automatic' $false)) }; Expect = @(@{ Status = 'Warning'; Message = 'ServiceStopped'; Target = 'stisvc' }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'a service that is not on the PC is not judged'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'OK')); Services = @((& $service 'ShellHWDetection' 'Running' 'Automatic' $false)) }; Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'PRN-SCAN-001'; Name = 'services first, then devices, and no OK when there is a finding'; Data = @{ Devices = @((& $device 'Contoso Scan 3000' 'Error')); Services = @((& $service 'stisvc' 'Stopped' 'Disabled' $true), (& $service 'ShellHWDetection' 'Stopped' 'Automatic' $false)) }; Expect = @(@{ Status = 'Warning'; Message = 'ServiceStopped'; Target = 'stisvc' }, @{ Status = 'Warning'; Message = 'ServiceStopped'; Target = 'ShellHWDetection' }, @{ Status = 'Warning'; Message = 'DeviceError'; Target = 'Contoso Scan 3000' }) }
    )

    # Defaults named in the task brief (and R22 for BudgetMs); no Printing check needs admin rights.
    $script:settingsCases = @(
        @{ Id = 'PRN-SPOOLER-001'; Settings = @{} }
        @{ Id = 'PRN-QUEUE-001'; Settings = @{ StuckMinutes = 60 } }
        @{ Id = 'PRN-PORT-001'; Settings = @{ TimeoutMs = 1000; BudgetMs = 8000 } }
        @{ Id = 'PRN-DEFAULT-001'; Settings = @{} }
        @{ Id = 'PRN-DRIVER-001'; Settings = @{} }
        @{ Id = 'PRN-RPC-001'; Settings = @{} }
        @{ Id = 'PRN-SCAN-001'; Settings = @{} }
    )

    $script:dependentCases = @($dependent | ForEach-Object { @{ Id = $_ } })

    # The three texts that were wrong or too sure of themselves, in every spooler-dependent check.
    $script:spoolerStoppedCases = foreach ($id in $dependent) {
        @{ Id = $id; Language = 'en-US'; Pattern = 'domain controller' }
        @{ Id = $id; Language = 'uk-UA'; Pattern = 'контролер\S* домену' }
    }

    $script:virtualPorts = @(
        @{ PortName = 'PORTPROMPT:'; Expected = $true }
        @{ PortName = 'nul:'; Expected = $true }
        @{ PortName = 'FILE:'; Expected = $true }
        @{ PortName = 'SHRFAX:'; Expected = $true }
        @{ PortName = 'XPSPort:'; Expected = $true }
        @{ PortName = 'Send to OneNote 16'; Expected = $true }
        @{ PortName = 'Contoso PDF Writer Port'; Expected = $true }
        @{ PortName = 'TS001'; Expected = $true }
        @{ PortName = 'USB001'; Expected = $false }
        @{ PortName = 'LPT1:'; Expected = $false }
        @{ PortName = 'IP_192.0.2.50'; Expected = $false }
        @{ PortName = 'WSD-0a1b2c3d-0000-1111-2222-333344445555'; Expected = $false }
        @{ PortName = 'http://192.0.2.50:631/ipp/print'; Expected = $false }
        @{ PortName = ''; Expected = $false }
    )
}

BeforeAll {
    Import-Module (Join-Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) 'Chekap/Chekap.psd1') -Force
    $script:byId = @{}
    foreach ($registered in (InModuleScope Chekap { $script:ChekapChecks })) { $script:byId[$registered.Id] = $registered }
    $root = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:tables = @{
        'en-US' = Import-PowerShellDataFile -Path (Join-Path $root 'Chekap/en-US/Chekap.strings.psd1')
        'uk-UA' = Import-PowerShellDataFile -Path (Join-Path $root 'Chekap/uk-UA/Chekap.strings.psd1')
    }
    # A mock cannot honour -ErrorAction by itself. This fails the way the real cmdlet does unless the caller silenced it.
    $script:failUnlessSilenced = {
        param($Bound)
        $action = 'Stop'
        if ($Bound.ContainsKey('ErrorAction')) { $action = $Bound['ErrorAction'] }
        Write-Error 'The cmdlet failed' -ErrorAction $action
    }
    # Real cmdlets return enums; the checks must turn them into strings.
    if (-not ('ChekapTestPrinterType' -as [type])) { Add-Type -TypeDefinition 'public enum ChekapTestPrinterType { Local, Connection }' }
    if (-not ('ChekapTestPrinterStatus' -as [type])) { Add-Type -TypeDefinition 'public enum ChekapTestPrinterStatus { Normal, Offline }' }
    if (-not ('ChekapTestPortProtocol' -as [type])) { Add-Type -TypeDefinition 'public enum ChekapTestPortProtocol { RAW = 1, LPR = 2 }' }
    if (-not ('ChekapTestJobStatus' -as [type])) { Add-Type -TypeDefinition '[System.Flags] public enum ChekapTestJobStatus { Normal = 0, Error = 1, Printing = 2 }' }
    # A printer as Get-Printer returns it.
    $script:newPrinter = {
        param([string]$Name, [string]$Type, [string]$PortName, [string]$Status = 'Normal', [string]$Driver = 'Contoso Laser', [bool]$Shared = $false, [string]$ComputerName = '')
        [pscustomobject]@{
            Name = $Name; Type = [ChekapTestPrinterType]$Type; PortName = $PortName; PrinterStatus = [ChekapTestPrinterStatus]$Status
            DriverName = $Driver; Shared = $Shared; ComputerName = $ComputerName
        }
    }
}

AfterAll {
    Remove-Module Chekap -ErrorAction SilentlyContinue
}

Describe 'Printing checks: registration' {
    It 'registers all 7 checks in the Printing category' {
        @($script:byId.Values | Where-Object { $_.Category -eq 'Printing' }).Count | Should -Be 7
    }

    It '<Id> has the Settings from the brief and needs no admin rights' -ForEach $script:settingsCases {
        $check = $script:byId[$Id]
        $check | Should -Not -BeNullOrEmpty
        $check.RequiresAdmin | Should -BeFalse
        $check.Settings.Count | Should -Be $Settings.Count
        foreach ($key in $Settings.Keys) { (@($check.Settings[$key]) -join ',') | Should -Be (@($Settings[$key]) -join ',') }
    }
}

Describe 'Printing checks: Evaluate' {
    It '<Id>: <Name>' -ForEach $script:evaluateCases {
        $check = $script:byId[$Id]
        $verdicts = @(& $check.Evaluate $Data $check.Settings)
        $verdicts.Count | Should -Be $Expect.Count
        for ($i = 0; $i -lt $Expect.Count; $i++) {
            $verdicts[$i].Status | Should -Be $Expect[$i].Status
            $verdicts[$i].Message | Should -Be $Expect[$i].Message
            if ($Expect[$i].ContainsKey('Target')) { $verdicts[$i].Target | Should -Be $Expect[$i].Target }
            if ($Expect[$i].ContainsKey('Args')) { (@($verdicts[$i].Args) -join '|') | Should -Be (@($Expect[$i].Args) -join '|') }
        }
    }

    # The runner formats a text only when Args is not empty; a placeholder left over or too few Args would show up in a report.
    It '<Id>: <Name> - the texts format in both languages' -ForEach $script:evaluateCases {
        $check = $script:byId[$Id]
        foreach ($verdict in @(& $check.Evaluate $Data $check.Settings)) {
            $verdictArgs = @()
            if ($null -ne $verdict.Args) { $verdictArgs = @($verdict.Args) }
            foreach ($table in $script:tables.Values) {
                foreach ($part in 'Details', 'Recommendation') {
                    $key = "$Id.$($verdict.Message).$part"
                    if (-not $table.ContainsKey($key)) { continue }
                    $text = [string]$table[$key]
                    if ($verdictArgs.Count -gt 0) { $text = $text -f $verdictArgs }
                    $text | Should -Not -Match '\{\d'
                }
            }
        }
    }

    # The OK verdicts that carry advice need a Recommendation in both languages; the structural test only requires it for non-OK ones.
    It '<Key> exists in both languages' -ForEach @(
        @{ Key = 'PRN-PORT-001.Wsd.Recommendation' }
        @{ Key = 'PRN-DEFAULT-001.Managed.Recommendation' }
        @{ Key = 'PRN-RPC-001.Client.Recommendation' }
        @{ Key = 'PRN-SPOOLER-001.DisabledServer.Recommendation' }
        @{ Key = 'PRN-DRIVER-001.Unused.Recommendation' }
    ) {
        foreach ($table in $script:tables.Values) { $table[$Key] | Should -Not -BeNullOrEmpty }
    }

    # Get-PnpDevice -Class Image also returns webcams (R25): no text may call such a device a scanner only.
    It 'PRN-SCAN-001 texts name an imaging device (scanner or camera) in <Language>' -ForEach @(@{ Language = 'en-US'; Pattern = 'scanner or camera' }, @{ Language = 'uk-UA'; Pattern = 'сканер\S* або камер' }) {
        foreach ($message in 'NoScanner', 'Ok', 'DeviceError') {
            $script:tables[$Language]["PRN-SCAN-001.$message.Details"] | Should -Match $Pattern
        }
    }

    # Facts checked read-only against this PC (Get-Service DisplayName; printui.dll.mui, TCPMonUI.dll.mui and the Settings app resources of uk-UA).
    It 'uk-UA texts name the Windows UI the way Windows does' -ForEach @(
        @{ Key = 'PRN-SPOOLER-001.Ok.Details'; Text = 'Print Spooler (Spooler)' }
        @{ Key = 'PRN-SPOOLER-001.Stopped.Recommendation'; Text = 'Print Spooler' }
        @{ Key = 'PRN-SCAN-001.ServiceStopped.Recommendation'; Text = 'Служба завантаження зображень Windows' }
        @{ Key = 'PRN-SCAN-001.ServiceStopped.Recommendation'; Text = 'Визначення устаткування оболонки' }
        @{ Key = 'PRN-PORT-001.Unreachable.Recommendation'; Text = 'Настроїти порт' }
        @{ Key = 'PRN-PORT-001.Offline.Recommendation'; Text = 'Настроїти порт' }
        @{ Key = 'PRN-PORT-001.Offline.Recommendation'; Text = 'Використовувати цей принтер в автономному режимі' }
        @{ Key = 'PRN-PORT-001.Offline.Recommendation'; Text = 'Дозволено перевірку стану через SNMP' }
        @{ Key = 'PRN-DEFAULT-001.Managed.Recommendation'; Text = 'Дозволити ОС Windows керувати моїм принтером за замовчуванням' }
        @{ Key = 'PRN-DEFAULT-001.NoDefault.Recommendation'; Text = 'Дозволити ОС Windows керувати моїм принтером за замовчуванням' }
    ) {
        $script:tables['uk-UA'][$Key] | Should -Match ([regex]::Escape($Text))
    }

    It 'uk-UA Printing texts leave out names and wording that Windows does not use' {
        $banned = '(?i)диспетчер\w* друку', 'стандартним принтером', 'Налаштувати порт', 'можуть не знаходитися', 'помилки безпеки', 'спільного на робочій'
        $texts = @($script:tables['uk-UA'].Keys | Where-Object { $_ -like 'PRN-*' } | ForEach-Object { '{0}: {1}' -f $_, $script:tables['uk-UA'][$_] })
        $texts.Count | Should -BeGreaterThan 50
        $hits = foreach ($text in $texts) { foreach ($word in $banned) { if ($text -match $word) { '{0} <- {1}' -f $word, $text.Substring(0, $text.IndexOf(':')) } } }
        $hits | Should -BeNullOrEmpty
    }

    It 'PRN-PORT-001 does not state the cause of an unreachable printer as a fact in <Language>' -ForEach @(@{ Language = 'en-US'; Pattern = 'may be' }, @{ Language = 'uk-UA'; Pattern = 'може бути' }) {
        $script:tables[$Language]['PRN-PORT-001.Unreachable.Details'] | Should -Match $Pattern
        $script:tables[$Language]['PRN-PORT-001.Unreachable.Details'] | Should -Match '(?i)firewall|брандмауер'
        $script:tables[$Language]['PRN-PORT-001.Unreachable.Recommendation'] | Should -Match '(?i)firewall|брандмауер'
        $script:tables[$Language]['PRN-PORT-001.Unreachable.Recommendation'] | Should -Match '9100'
    }

    It '<Id>.SpoolerStopped.Recommendation says a stopped spooler is expected on a server that does not print in <Language>' -ForEach $script:spoolerStoppedCases {
        $script:tables[$Language]["$Id.SpoolerStopped.Recommendation"] | Should -Match $Pattern
    }

    It 'PRN-SCAN-001 never mentions a scanner without a camera in <Language>' -ForEach @(@{ Language = 'en-US'; Scanner = 'scanner'; Camera = 'camera' }, @{ Language = 'uk-UA'; Scanner = 'сканер'; Camera = 'камер' }) {
        $texts = @($script:tables[$Language].Keys | Where-Object { $_ -like 'PRN-SCAN-001.*' } | ForEach-Object { $script:tables[$Language][$_] })
        $texts.Count | Should -BeGreaterThan 5
        @($texts | Where-Object { $_ -match $Scanner -and $_ -notmatch $Camera }) | Should -BeNullOrEmpty
    }
}

Describe 'Printing helpers' {
    It 'Test-ChekapVirtualPrinterPort: "<PortName>" is <Expected>' -ForEach $script:virtualPorts {
        InModuleScope Chekap -Parameters @{ PortName = $PortName; Expected = $Expected } {
            Test-ChekapVirtualPrinterPort -PortName $PortName | Should -Be $Expected
        }
    }

    It 'Get-ChekapPrinterServer takes the server from the \\server\share name' {
        InModuleScope Chekap {
            Get-ChekapPrinterServer -Printer ([pscustomobject]@{ Name = '\\PRINT-SRV\HP-2F'; ComputerName = '' }) | Should -Be 'PRINT-SRV'
            Get-ChekapPrinterServer -Printer ([pscustomobject]@{ Name = '\\Сервер-друку\Бухгалтерія'; ComputerName = '' }) | Should -Be 'Сервер-друку'
        }
    }

    It 'Get-ChekapPrinterServer falls back to ComputerName without leading backslashes' {
        InModuleScope Chekap {
            Get-ChekapPrinterServer -Printer ([pscustomobject]@{ Name = 'PRN-2F-HP'; ComputerName = '\\PRINT-SRV' }) | Should -Be 'PRINT-SRV'
            Get-ChekapPrinterServer -Printer ([pscustomobject]@{ Name = 'PRN-2F-HP'; ComputerName = '' }) | Should -Be ''
        }
    }

    Context 'Get-ChekapPrintState' {
        It 'reports a running spooler and the module' {
            Mock Get-Service { [pscustomobject]@{ Status = 'Running' } } -ModuleName Chekap
            $state = InModuleScope Chekap { Get-ChekapPrintState }
            $state.PrintModule | Should -BeTrue
            $state.SpoolerRunning | Should -BeTrue
            Should -Invoke Get-Service -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'Spooler' -and $ErrorAction -eq 'SilentlyContinue' }
        }

        It 'a spooler in any state but Running is not running' {
            Mock Get-Service { [pscustomobject]@{ Status = 'Stopped' } } -ModuleName Chekap
            (InModuleScope Chekap { Get-ChekapPrintState }).SpoolerRunning | Should -BeFalse
        }

        It 'a missing Spooler service is not running, not an error' {
            Mock Get-Service { } -ModuleName Chekap
            (InModuleScope Chekap { Get-ChekapPrintState }).SpoolerRunning | Should -BeFalse
        }

        It 'reports a missing PrintManagement module' {
            Mock Get-Service { [pscustomobject]@{ Status = 'Running' } } -ModuleName Chekap
            Mock Get-Command { } -ModuleName Chekap -ParameterFilter { $Name -eq 'Get-Printer' }
            $state = InModuleScope Chekap { Get-ChekapPrintState }
            $state.PrintModule | Should -BeFalse
            $state.SpoolerRunning | Should -BeTrue
        }
    }
}

Describe 'Printing checks: Collect' {
    BeforeEach {
        # A PC whose spooler runs and has no printers; each test overrides what it needs. Nothing may reach the real spooler.
        Mock Get-Service { [pscustomobject]@{ Status = 'Running'; StartType = 'Automatic' } } -ModuleName Chekap
        Mock Get-Printer { } -ModuleName Chekap
        Mock Get-PrintJob { } -ModuleName Chekap
        Mock Get-PrinterPort { } -ModuleName Chekap
        Mock Get-PrinterDriver { } -ModuleName Chekap
        Mock Get-ItemProperty { $null } -ModuleName Chekap
        Mock Get-CimInstance { [pscustomobject]@{ ProductType = 1 } } -ModuleName Chekap
        Mock Test-ChekapTcpPort { $true } -ModuleName Chekap
    }

    Context 'spooler-dependent checks' {
        It '<Id> asks nothing of the print cmdlets when the spooler is stopped' -ForEach $script:dependentCases {
            Mock Get-Service { [pscustomobject]@{ Status = 'Stopped' } } -ModuleName Chekap
            $check = $script:byId[$Id]
            $data = & $check.Collect $check.Settings
            $data.PrintModule | Should -BeTrue
            $data.SpoolerRunning | Should -BeFalse
            foreach ($command in 'Get-Printer', 'Get-PrintJob', 'Get-PrinterPort', 'Get-PrinterDriver') {
                Should -Invoke $command -ModuleName Chekap -Times 0 -Exactly
            }
            Should -Invoke Get-CimInstance -ModuleName Chekap -Times 0 -Exactly
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 0 -Exactly
        }

        It '<Id> asks nothing of the print cmdlets when PrintManagement is missing' -ForEach $script:dependentCases {
            Mock Get-Command { } -ModuleName Chekap -ParameterFilter { $Name -eq 'Get-Printer' }
            $check = $script:byId[$Id]
            $data = & $check.Collect $check.Settings
            $data.PrintModule | Should -BeFalse
            foreach ($command in 'Get-Printer', 'Get-PrintJob', 'Get-PrinterPort', 'Get-PrinterDriver') {
                Should -Invoke $command -ModuleName Chekap -Times 0 -Exactly
            }
            Should -Invoke Get-CimInstance -ModuleName Chekap -Times 0 -Exactly
        }
    }

    Context 'PRN-SPOOLER-001' {
        It 'reports the service state and start type as strings, and the product type' {
            Mock Get-Service { [pscustomobject]@{ Status = [System.ServiceProcess.ServiceControllerStatus]::Running; StartType = [System.ServiceProcess.ServiceStartMode]::Disabled } } -ModuleName Chekap
            Mock Get-CimInstance { [pscustomobject]@{ ProductType = [uint32]2 } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            $check = $script:byId['PRN-SPOOLER-001']
            $data = & $check.Collect $check.Settings
            $data.Status | Should -Be 'Running'
            $data.Status | Should -BeOfType [string]
            $data.StartType | Should -Be 'Disabled'
            $data.StartType | Should -BeOfType [string]
            $data.ProductType | Should -Be 2
            $data.ProductType | Should -BeOfType [int]
            Should -Invoke Get-Service -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'Spooler' }
        }

        It 'a missing Spooler service is Skipped NoSpooler, not an Error' {
            # The real cmdlet writes an error for an unknown service; the mock fails unless the caller silenced it.
            Mock Get-Service { & $script:failUnlessSilenced $PesterBoundParameters } -ModuleName Chekap
            $check = $script:byId['PRN-SPOOLER-001']
            $data = & $check.Collect $check.Settings
            $data.Status | Should -BeNullOrEmpty
            $data.StartType | Should -BeNullOrEmpty
            $verdicts = @(& $check.Evaluate $data $check.Settings)
            $verdicts.Count | Should -Be 1
            $verdicts[0].Status | Should -Be 'Skipped'
            $verdicts[0].Message | Should -Be 'NoSpooler'
        }
    }

    Context 'PRN-QUEUE-001' {
        BeforeEach {
            Mock Get-ChekapFolderSize { } -ModuleName Chekap
            Mock Get-ChildItem { } -ModuleName Chekap
        }

        It 'does not query jobs when spooler stopped' {
            Mock Get-Service { [pscustomobject]@{ Status = 'Stopped' } } -ModuleName Chekap
            Mock Get-Printer { & $script:newPrinter 'PRN-2F-HP' 'Local' 'USB001' } -ModuleName Chekap
            $check = $script:byId['PRN-QUEUE-001']
            $data = & $check.Collect $check.Settings
            $data.SpoolerRunning | Should -BeFalse
            Should -Invoke Get-PrintJob -ModuleName Chekap -Times 0 -Exactly
        }

        It 'queries jobs only for local printers' {
            Mock Get-Printer {
                & $script:newPrinter 'PRN-2F-HP' 'Local' 'USB001'
                & $script:newPrinter 'Принтер бухгалтерії' 'Local' 'IP_192.0.2.51'
                & $script:newPrinter '\\PRINT-SRV\HP-3F' 'Connection' '\\PRINT-SRV\HP-3F'
            } -ModuleName Chekap
            $check = $script:byId['PRN-QUEUE-001']
            $null = & $check.Collect $check.Settings
            Should -Invoke Get-PrintJob -ModuleName Chekap -Times 2 -Exactly
            Should -Invoke Get-PrintJob -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $PrinterName -eq 'PRN-2F-HP' }
            Should -Invoke Get-PrintJob -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $PrinterName -eq 'Принтер бухгалтерії' }
            Should -Invoke Get-PrintJob -ModuleName Chekap -Times 0 -Exactly -ParameterFilter { $PrinterName -like '\\*' }
        }

        It 'maps a job to printer, id, status string and submit time, and leaves out the document and the user' {
            $submitted = [datetime]'2026-05-04T11:00:00'
            Mock Get-Printer { & $script:newPrinter 'PRN-2F-HP' 'Local' 'USB001' } -ModuleName Chekap
            Mock Get-PrintJob {
                [pscustomobject]@{ ID = 7; JobStatus = [ChekapTestJobStatus]'Error, Printing'; SubmittedTime = $submitted; DocumentName = 'Budget-secret.xlsx'; UserName = 'olena.k' }
            } -ModuleName Chekap
            $check = $script:byId['PRN-QUEUE-001']
            $data = & $check.Collect $check.Settings
            @($data.Jobs).Count | Should -Be 1
            $data.Jobs[0].Printer | Should -Be 'PRN-2F-HP'
            $data.Jobs[0].Id | Should -Be 7
            $data.Jobs[0].Status | Should -Be 'Error, Printing'
            $data.Jobs[0].Status | Should -BeOfType [string]
            $data.Jobs[0].Submitted | Should -Be $submitted
            $json = $data | ConvertTo-Json -Depth 5
            $json | Should -Not -Match 'Budget-secret'
            $json | Should -Not -Match 'olena'
        }

        It 'collects the time it judged the age by' {
            $before = Get-Date
            $check = $script:byId['PRN-QUEUE-001']
            $data = & $check.Collect $check.Settings
            $data.Now | Should -BeOfType [datetime]
            $data.Now | Should -BeGreaterOrEqual $before
        }

        It 'has no jobs and silences the error when a printer cannot be asked' {
            Mock Get-Printer { & $script:newPrinter 'PRN-2F-HP' 'Local' 'USB001' } -ModuleName Chekap
            Mock Get-PrintJob { & $script:failUnlessSilenced $PesterBoundParameters } -ModuleName Chekap
            $check = $script:byId['PRN-QUEUE-001']
            @((& $check.Collect $check.Settings).Jobs).Count | Should -Be 0
            Should -Invoke Get-PrintJob -ModuleName Chekap -Times 1 -Exactly
        }

        It 'counts the files and bytes of the spool folder' {
            Mock Get-ChekapFolderSize { [long]20480 } -ModuleName Chekap
            Mock Get-ChildItem { 1..3 | ForEach-Object { [pscustomobject]@{ Name = "$_.SPL" } } } -ModuleName Chekap
            $check = $script:byId['PRN-QUEUE-001']
            $data = & $check.Collect $check.Settings
            $data.SpoolFiles | Should -Be 3
            $data.SpoolBytes | Should -Be 20480
            Should -Invoke Get-ChekapFolderSize -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Path -like '*spool\PRINTERS' }
        }

        It 'has a null spool folder when access is denied, and does not list it' {
            $check = $script:byId['PRN-QUEUE-001']
            $data = & $check.Collect $check.Settings
            $data.SpoolBytes | Should -BeNullOrEmpty
            $data.SpoolFiles | Should -BeNullOrEmpty
            Should -Invoke Get-ChildItem -ModuleName Chekap -Times 0 -Exactly
        }
    }

    Context 'PRN-PORT-001' {
        It 'maps a Standard TCP/IP port to its host and port number' {
            Mock Get-Printer { & $script:newPrinter 'PRN-2F-HP' 'Local' 'IP_192.0.2.50' 'Offline' } -ModuleName Chekap
            Mock Get-PrinterPort { [pscustomobject]@{ Name = 'IP_192.0.2.50'; PrinterHostAddress = '192.0.2.50'; PortNumber = [uint32]9101 } } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            @($data.Printers).Count | Should -Be 1
            $data.Printers[0].Name | Should -Be 'PRN-2F-HP'
            $data.Printers[0].Kind | Should -Be 'Network'
            $data.Printers[0].Host | Should -Be '192.0.2.50'
            $data.Printers[0].Port | Should -Be 9101
            $data.Printers[0].Port | Should -BeOfType [int]
            $data.Printers[0].Type | Should -Be 'Local'
            $data.Printers[0].Type | Should -BeOfType [string]
            $data.Printers[0].PortName | Should -Be 'IP_192.0.2.50'
            $data.Printers[0].Status | Should -Be 'Offline'
            $data.Printers[0].Status | Should -BeOfType [string]
        }

        It 'maps PortNumber 0 to 9100' {
            Mock Get-Printer { & $script:newPrinter 'PRN-2F-HP' 'Local' 'IP_192.0.2.50' } -ModuleName Chekap
            Mock Get-PrinterPort { [pscustomobject]@{ Name = 'IP_192.0.2.50'; PrinterHostAddress = '192.0.2.50'; PortNumber = [uint32]0 } } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            $data.Printers[0].Port | Should -Be 9100
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.50' -and $Port -eq 9100 -and $TimeoutMs -eq 1000 }
        }

        It 'maps IPP URL to host and 631' {
            Mock Get-Printer {
                & $script:newPrinter 'PRN-2F-HP' 'Local' 'http://192.0.2.50:631/ipp/print'
                & $script:newPrinter 'PRN-3F-HP' 'Local' 'ipp://printer.contoso.local/ipp/print'
            } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            $data.Printers[0].Kind | Should -Be 'Network'
            $data.Printers[0].Host | Should -Be '192.0.2.50'
            $data.Printers[0].Port | Should -Be 631
            $data.Printers[1].Host | Should -Be 'printer.contoso.local'
            $data.Printers[1].Port | Should -Be 631
        }

        It 'keeps the port written in an IPP URL, and the scheme port when none is written' {
            Mock Get-Printer {
                & $script:newPrinter 'PRN-2F-HP' 'Local' 'http://192.0.2.50:8631/ipp/print'
                & $script:newPrinter 'PRN-3F-HP' 'Local' 'https://192.0.2.51/ipp/print'
            } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            $data.Printers[0].Port | Should -Be 8631
            $data.Printers[1].Port | Should -Be 443
        }

        It 'maps an ipps URL to 443 when no port is written, and keeps a written port' {
            Mock Get-Printer {
                & $script:newPrinter 'PRN-2F-HP' 'Local' 'ipps://192.0.2.50/ipp/print'
                & $script:newPrinter 'PRN-3F-HP' 'Local' 'ipps://192.0.2.51:631/ipp/print'
                & $script:newPrinter 'PRN-4F-HP' 'Local' 'ipp://192.0.2.52/ipp/print'
            } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            $data.Printers[0].Kind | Should -Be 'Network'
            $data.Printers[0].Host | Should -Be '192.0.2.50'
            $data.Printers[0].Port | Should -Be 443
            $data.Printers[1].Port | Should -Be 631
            $data.Printers[2].Port | Should -Be 631
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.50' -and $Port -eq 443 }
        }

        It 'probes port 515 for a Standard TCP/IP port in LPR mode, and the port number for raw printing' {
            Mock Get-Printer {
                & $script:newPrinter 'PRN-2F-HP' 'Local' 'IP_192.0.2.50'
                & $script:newPrinter 'PRN-3F-HP' 'Local' 'IP_192.0.2.51'
            } -ModuleName Chekap
            Mock Get-PrinterPort {
                [pscustomobject]@{ Name = 'IP_192.0.2.50'; PrinterHostAddress = '192.0.2.50'; PortNumber = [uint32]9100; Protocol = [ChekapTestPortProtocol]'LPR' }
                [pscustomobject]@{ Name = 'IP_192.0.2.51'; PrinterHostAddress = '192.0.2.51'; PortNumber = [uint32]9101; Protocol = [ChekapTestPortProtocol]'RAW' }
            } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            $data.Printers[0].Port | Should -Be 515
            $data.Printers[1].Port | Should -Be 9101
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.50' -and $Port -eq 515 }
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.51' -and $Port -eq 9101 }
        }

        It 'does not test a WSD port, a virtual port or a USB port' {
            Mock Get-Printer {
                & $script:newPrinter 'PRN-2F-HP' 'Local' 'WSD-0a1b2c3d-0000-1111-2222-333344445555'
                & $script:newPrinter 'Microsoft Print to PDF' 'Local' 'PORTPROMPT:'
                & $script:newPrinter 'OneNote' 'Local' 'nul:'
                & $script:newPrinter 'PRN-USB' 'Local' 'USB001'
            } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            (@($data.Printers | ForEach-Object { $_.Kind }) -join ',') | Should -Be 'Wsd,Virtual,Virtual,Local'
            @($data.Reachable.Keys).Count | Should -Be 0
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 0 -Exactly
        }

        It 'a Standard TCP/IP port is network even when its name looks like a virtual one' {
            Mock Get-Printer { & $script:newPrinter 'PRN-2F-HP' 'Local' 'TS_Office_Port' } -ModuleName Chekap
            Mock Get-PrinterPort { [pscustomobject]@{ Name = 'TS_Office_Port'; PrinterHostAddress = '192.0.2.60'; PortNumber = [uint32]9100 } } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            $data.Printers[0].Kind | Should -Be 'Network'
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.60' }
        }

        It 'tests a shared printer on port 445 of its print server' {
            Mock Get-Printer { & $script:newPrinter '\\PRINT-SRV\Принтер-3F' 'Connection' '\\PRINT-SRV\Принтер-3F' } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            $data.Printers[0].Kind | Should -Be 'Connection'
            $data.Printers[0].Type | Should -Be 'Connection'
            $data.Printers[0].Server | Should -Be 'PRINT-SRV'
            $data.Printers[0].Host | Should -Be 'PRINT-SRV'
            $data.Printers[0].Port | Should -Be 445
            $data.Reachable['\\PRINT-SRV\Принтер-3F'] | Should -BeTrue
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'PRINT-SRV' -and $Port -eq 445 }
        }

        It 'probes an endpoint shared by several printers once' {
            Mock Get-Printer {
                & $script:newPrinter '\\PRINT-SRV\HP-1F' 'Connection' '\\PRINT-SRV\HP-1F'
                & $script:newPrinter '\\PRINT-SRV\HP-2F' 'Connection' '\\PRINT-SRV\HP-2F'
                & $script:newPrinter '\\PRINT-SRV\HP-3F' 'Connection' '\\PRINT-SRV\HP-3F'
                & $script:newPrinter 'PRN-A' 'Local' 'IP_192.0.2.50'
                & $script:newPrinter 'PRN-B' 'Local' 'IP_192.0.2.50'
            } -ModuleName Chekap
            Mock Get-PrinterPort { [pscustomobject]@{ Name = 'IP_192.0.2.50'; PrinterHostAddress = '192.0.2.50'; PortNumber = [uint32]9100 } } -ModuleName Chekap
            Mock Test-ChekapTcpPort { $ComputerName -eq '192.0.2.50' } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 2 -Exactly
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'PRINT-SRV' -and $Port -eq 445 }
            @($data.Reachable.Keys).Count | Should -Be 5
            $data.Reachable['\\PRINT-SRV\HP-3F'] | Should -BeFalse
            $data.Reachable['PRN-B'] | Should -BeTrue
        }

        It 'reports an endpoint that does not answer as not reachable' {
            Mock Get-Printer { & $script:newPrinter 'PRN-2F-HP' 'Local' 'IP_192.0.2.50' } -ModuleName Chekap
            Mock Get-PrinterPort { [pscustomobject]@{ Name = 'IP_192.0.2.50'; PrinterHostAddress = '192.0.2.50'; PortNumber = [uint32]9100 } } -ModuleName Chekap
            Mock Test-ChekapTcpPort { $false } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect $check.Settings
            $data.Reachable.ContainsKey('PRN-2F-HP') | Should -BeTrue
            $data.Reachable['PRN-2F-HP'] | Should -BeFalse
            $data.Reachable['PRN-2F-HP'] | Should -BeOfType [bool]
        }

        It 'probes nothing when the time budget is zero' {
            Mock Get-Printer { & $script:newPrinter 'PRN-2F-HP' 'Local' 'IP_192.0.2.50' } -ModuleName Chekap
            Mock Get-PrinterPort { [pscustomobject]@{ Name = 'IP_192.0.2.50'; PrinterHostAddress = '192.0.2.50'; PortNumber = [uint32]9100 } } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect @{ TimeoutMs = 1000; BudgetMs = 0 }
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 0 -Exactly
            $data.Reachable.ContainsKey('PRN-2F-HP') | Should -BeFalse
            $data.Printers[0].Kind | Should -Be 'Network'
        }

        It 'stops probing once the time budget is spent, but keeps the answers it has' {
            Mock Get-Printer {
                & $script:newPrinter 'PRN-A' 'Local' 'IP_192.0.2.50'
                & $script:newPrinter 'PRN-B' 'Local' 'IP_192.0.2.51'
                & $script:newPrinter 'PRN-C' 'Local' 'IP_192.0.2.52'
                & $script:newPrinter 'PRN-D' 'Local' 'IP_192.0.2.50'
            } -ModuleName Chekap
            Mock Get-PrinterPort {
                foreach ($last in 50, 51, 52) { [pscustomobject]@{ Name = "IP_192.0.2.$last"; PrinterHostAddress = "192.0.2.$last"; PortNumber = [uint32]9100 } }
            } -ModuleName Chekap
            # Each probe takes longer than the whole budget, so only the first one may start.
            Mock Test-ChekapTcpPort { Start-Sleep -Milliseconds 450; $false } -ModuleName Chekap
            $check = $script:byId['PRN-PORT-001']
            $data = & $check.Collect @{ TimeoutMs = 1000; BudgetMs = 300 }
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly
            (@($data.Reachable.Keys | Sort-Object) -join ',') | Should -Be 'PRN-A,PRN-D'
            $data.Reachable['PRN-D'] | Should -BeFalse
        }
    }

    Context 'PRN-DEFAULT-001' {
        It 'counts the printers that are not virtual' {
            Mock Get-Printer {
                & $script:newPrinter 'Microsoft Print to PDF' 'Local' 'PORTPROMPT:'
                & $script:newPrinter 'OneNote' 'Local' 'nul:'
                & $script:newPrinter 'PRN-USB' 'Local' 'USB001'
                & $script:newPrinter 'PRN-2F-HP' 'Local' 'IP_192.0.2.50'
            } -ModuleName Chekap
            $check = $script:byId['PRN-DEFAULT-001']
            $data = & $check.Collect $check.Settings
            $data.Printers | Should -Be 2
            $data.Printers | Should -BeOfType [int]
        }

        It 'reads the default printer from Win32_Printer' {
            Mock Get-CimInstance { [pscustomobject]@{ Name = 'Принтер бухгалтерії'; Default = $true } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_Printer' }
            $check = $script:byId['PRN-DEFAULT-001']
            $data = & $check.Collect $check.Settings
            $data.Default | Should -Be 'Принтер бухгалтерії'
            Should -Invoke Get-CimInstance -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ClassName -eq 'Win32_Printer' -and $Filter -match 'Default' }
        }

        It 'has a null default when Windows reports none' {
            Mock Get-CimInstance { } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_Printer' }
            $check = $script:byId['PRN-DEFAULT-001']
            (& $check.Collect $check.Settings).Default | Should -BeNullOrEmpty
        }

        It 'WindowsManaged is <Expected> when LegacyDefaultPrinterMode is <Value>' -ForEach @(
            @{ Value = 'missing'; Expected = $true }
            @{ Value = 0; Expected = $true }
            @{ Value = 1; Expected = $false }
        ) {
            if ($Value -eq 'missing') {
                Mock Get-ItemProperty { [pscustomobject]@{ Other = 1 } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Windows NT*CurrentVersion*Windows' }
            }
            else {
                Mock Get-ItemProperty { [pscustomobject]@{ LegacyDefaultPrinterMode = $Value } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Windows NT*CurrentVersion*Windows' }
            }
            $check = $script:byId['PRN-DEFAULT-001']
            $data = & $check.Collect $check.Settings
            $data.WindowsManaged | Should -Be $Expected
            $data.WindowsManaged | Should -BeOfType [bool]
            Should -Invoke Get-ItemProperty -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'LegacyDefaultPrinterMode' -and $ErrorAction -eq 'SilentlyContinue' }
        }

        It 'WindowsManaged when the key is not there at all' {
            Mock Get-ItemProperty { $null } -ModuleName Chekap
            $check = $script:byId['PRN-DEFAULT-001']
            (& $check.Collect $check.Settings).WindowsManaged | Should -BeTrue
        }
    }

    Context 'PRN-DRIVER-001' {
        It 'lists the drivers and the driver names in use, once each' {
            Mock Get-PrinterDriver {
                [pscustomobject]@{ Name = 'Contoso Laser'; Manufacturer = 'Contoso'; PrinterEnvironment = 'Windows x64' }
                [pscustomobject]@{ Name = 'Microsoft XPS Class Driver'; Manufacturer = 'Microsoft'; PrinterEnvironment = 'Windows x64' }
            } -ModuleName Chekap
            Mock Get-Printer {
                & $script:newPrinter 'PRN-1F-HP' 'Local' 'USB001' 'Normal' 'Contoso Laser'
                & $script:newPrinter 'PRN-2F-HP' 'Local' 'USB002' 'Normal' 'Contoso Laser'
                & $script:newPrinter 'PRN-3F-HP' 'Local' 'USB003' 'Normal' 'Fabrikam Inkjet'
            } -ModuleName Chekap
            $check = $script:byId['PRN-DRIVER-001']
            $data = & $check.Collect $check.Settings
            @($data.Drivers).Count | Should -Be 2
            $data.Drivers[0].Name | Should -Be 'Contoso Laser'
            $data.Drivers[0].Manufacturer | Should -Be 'Contoso'
            (@($data.Used) -join '|') | Should -Be 'Contoso Laser|Fabrikam Inkjet'
        }

        It 'has empty lists when nothing is installed' {
            $check = $script:byId['PRN-DRIVER-001']
            $data = & $check.Collect $check.Settings
            @($data.Drivers).Count | Should -Be 0
            @($data.Used).Count | Should -Be 0
        }
    }

    Context 'PRN-RPC-001' {
        It 'reads RpcAuthnLevelPrivacyEnabled from the Print key' {
            Mock Get-ItemProperty { [pscustomobject]@{ RpcAuthnLevelPrivacyEnabled = 0 } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*Control\Print' }
            $check = $script:byId['PRN-RPC-001']
            $data = & $check.Collect $check.Settings
            $data.RpcAuthnLevelPrivacyEnabled | Should -Be 0
            $data.RpcAuthnLevelPrivacyEnabled | Should -Not -BeNullOrEmpty -Because 'a stored 0 is a value, not an absent one'
            Should -Invoke Get-ItemProperty -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'RpcAuthnLevelPrivacyEnabled' -and $ErrorAction -eq 'SilentlyContinue' }
        }

        It 'has a null value when the registry value is not there' {
            $check = $script:byId['PRN-RPC-001']
            $data = & $check.Collect $check.Settings
            $data.ContainsKey('RpcAuthnLevelPrivacyEnabled') | Should -BeTrue
            $data.RpcAuthnLevelPrivacyEnabled | Should -BeNullOrEmpty
        }

        It 'lists shared printers and connections to other computers, and the product type' {
            Mock Get-CimInstance { [pscustomobject]@{ ProductType = [uint32]3 } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            Mock Get-Printer {
                & $script:newPrinter 'PRN-1F-HP' 'Local' 'USB001' 'Normal' 'Contoso Laser' $true
                & $script:newPrinter 'Принтер бухгалтерії' 'Local' 'USB002' 'Normal' 'Contoso Laser' $true
                & $script:newPrinter 'PRN-3F-HP' 'Local' 'USB003' 'Normal' 'Contoso Laser' $false
                & $script:newPrinter '\\PRINT-SRV\HP-4F' 'Connection' '\\PRINT-SRV\HP-4F'
            } -ModuleName Chekap
            $check = $script:byId['PRN-RPC-001']
            $data = & $check.Collect $check.Settings
            (@($data.Shared) -join '|') | Should -Be 'PRN-1F-HP|Принтер бухгалтерії'
            @($data.Connections).Count | Should -Be 1
            $data.Connections[0].Name | Should -Be '\\PRINT-SRV\HP-4F'
            $data.Connections[0].Server | Should -Be 'PRINT-SRV'
            $data.ProductType | Should -Be 3
            $data.ProductType | Should -BeOfType [int]
        }
    }

    Context 'PRN-SCAN-001' {
        BeforeEach {
            # With no imaging device the real cmdlet writes an error (CmdletizationQuery_NotFound).
            Mock Get-PnpDevice { & $script:failUnlessSilenced $PesterBoundParameters } -ModuleName Chekap
            Mock Test-Path { $false } -ModuleName Chekap
        }

        It 'lists the imaging devices that are present' {
            Mock Get-PnpDevice {
                [pscustomobject]@{ FriendlyName = 'Contoso Scan 3000'; Status = 'OK' }
                [pscustomobject]@{ FriendlyName = 'Integrated Camera'; Status = 'Error' }
            } -ModuleName Chekap
            $check = $script:byId['PRN-SCAN-001']
            $data = & $check.Collect $check.Settings
            Should -Invoke Get-PnpDevice -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Class -eq 'Image' -and $PresentOnly -and $ErrorAction -eq 'SilentlyContinue' }
            @($data.Devices).Count | Should -Be 2
            $data.Devices[0].Name | Should -Be 'Contoso Scan 3000'
            $data.Devices[1].Status | Should -Be 'Error'
        }

        It 'has no devices when Windows finds none, and silences the cmdlet error' {
            $check = $script:byId['PRN-SCAN-001']
            @((& $check.Collect $check.Settings).Devices).Count | Should -Be 0
            Should -Invoke Get-PnpDevice -ModuleName Chekap -Times 1 -Exactly
        }

        It 'reads stisvc and ShellHWDetection with their state, start type and trigger' {
            Mock Get-Service {
                [pscustomobject]@{ Name = 'stisvc'; Status = [System.ServiceProcess.ServiceControllerStatus]::Stopped; StartType = [System.ServiceProcess.ServiceStartMode]::Automatic }
                [pscustomobject]@{ Name = 'ShellHWDetection'; Status = [System.ServiceProcess.ServiceControllerStatus]::Running; StartType = [System.ServiceProcess.ServiceStartMode]::Automatic }
            } -ModuleName Chekap -ParameterFilter { $Name -contains 'stisvc' }
            Mock Test-Path { $true } -ModuleName Chekap -ParameterFilter { $LiteralPath -like '*Services\stisvc\TriggerInfo' }
            $check = $script:byId['PRN-SCAN-001']
            $data = & $check.Collect $check.Settings
            Should -Invoke Get-Service -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { (@($Name) -join ',') -eq 'stisvc,ShellHWDetection' -and $ErrorAction -eq 'SilentlyContinue' }
            @($data.Services).Count | Should -Be 2
            $data.Services[0].Name | Should -Be 'stisvc'
            $data.Services[0].Status | Should -Be 'Stopped'
            $data.Services[0].Status | Should -BeOfType [string]
            $data.Services[0].StartType | Should -Be 'Automatic'
            $data.Services[0].StartType | Should -BeOfType [string]
            $data.Services[0].TriggerStart | Should -BeTrue
            $data.Services[1].Name | Should -Be 'ShellHWDetection'
            $data.Services[1].TriggerStart | Should -BeFalse
            $data.Services[1].TriggerStart | Should -BeOfType [bool]
        }

        It 'leaves out a service that is not on the PC' {
            Mock Get-Service { [pscustomobject]@{ Name = 'ShellHWDetection'; Status = 'Running'; StartType = 'Automatic' } } -ModuleName Chekap -ParameterFilter { $Name -contains 'stisvc' }
            $check = $script:byId['PRN-SCAN-001']
            $data = & $check.Collect $check.Settings
            @($data.Services).Count | Should -Be 1
        }
    }
}

Describe 'Test-ChekapPrinting' {
    BeforeEach {
        Mock Invoke-ChekapCheck { } -ModuleName Chekap
    }

    It 'runs all Printing checks in the requested language' {
        Test-ChekapPrinting -Language en
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $Language -eq 'en' -and @($Check).Count -eq 7 -and @($Check | Where-Object { $_.Category -ne 'Printing' }).Count -eq 0
        }
    }

    It 'selects checks by -CheckId, wildcards allowed' {
        Test-ChekapPrinting -Language uk -CheckId 'PRN-QUEUE-*', 'PRN-RPC-001'
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $Language -eq 'uk' -and (@($Check | ForEach-Object { $_.Id }) -join ',') -eq 'PRN-QUEUE-001,PRN-RPC-001'
        }
    }

    It 'does not return a Network check even when its ID is asked for' {
        $result = @(Test-ChekapPrinting -Language en -CheckId 'NET-DNS-001' -WarningAction SilentlyContinue)
        $result.Count | Should -Be 0
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 0 -Exactly
    }

    It 'warns about an unknown ID and returns nothing' {
        $result = @(Test-ChekapPrinting -Language en -CheckId 'PRN-NOPE-999' -WarningVariable warnings -WarningAction SilentlyContinue)
        $result.Count | Should -Be 0
        @($warnings).Count | Should -Be 1
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 0 -Exactly
    }
}

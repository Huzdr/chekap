# English UI strings. Every key must also exist in uk-UA, with the same {n} placeholders.
@{
    'Status.OK'                            = 'OK'
    'Status.Warning'                       = 'Warning'
    'Status.Critical'                      = 'Critical'
    'Status.Error'                         = 'Error'
    'Status.Skipped'                       = 'Skipped'

    'Category.System'                      = 'System'
    'Category.Network'                     = 'Network'
    'Category.Printing'                    = 'Printing'

    'Core.ConstrainedLanguage'             = 'Chekap cannot run in Constrained Language Mode (for example under AppLocker or WDAC). Start it in a session that uses FullLanguage mode.'
    'Core.InvalidCheckFile'                = 'Check file {0} is not valid: {1}'
    'Core.InvalidCheckFile.NotHashtable'   = 'The file must return exactly one hashtable.'
    'Core.InvalidCheckFile.BadKey'         = 'The key {0} is missing or has the wrong type.'
    'Core.UnknownCheckId'                  = 'There is no check with the ID "{0}".'
    'Core.Skipped.NotAdmin.Details'        = 'This check needs administrator rights.'
    'Core.Skipped.NotAdmin.Recommendation' = 'Start PowerShell as administrator and run the check again.'
    'Core.Skipped.OldBuild.Details'        = 'This check needs Windows build {0} or newer. This PC runs build {1}.'
    'Core.Skipped.OldBuild.Recommendation' = 'Nothing to fix: this check does not apply to this version of Windows.'
    'Core.Error.Collect.Details'           = 'Could not collect the data: {0}'
    'Core.Error.Evaluate.Details'          = 'Could not evaluate the collected data: {0}'
    'Core.Error.NoVerdict.Details'         = 'The check finished without returning a result.'
    'Core.Error.Recommendation'            = 'Run the check again with -Verbose. If the error repeats, report it in the Chekap repository.'
    'Core.Verbose.Running'                 = 'Running check {0}'
    'Core.Verbose.ReportWritten'           = 'Report written to {0}'

    'Config.Saved'                         = 'Settings saved to {0}'

    # NET-ADAPTER-001
    'NET-ADAPTER-001.Title' = 'Network adapter'
    'NET-ADAPTER-001.Ok.Details' = 'Adapter {0} is connected at {1:N0} Mbps.'
    'NET-ADAPTER-001.NoConnection.Details' = 'No physical network adapter is connected: there is no cable and no Wi-Fi connection.'
    'NET-ADAPTER-001.NoConnection.Recommendation' = 'Check that the network cable is plugged in at both ends and the switch port is on, or connect to Wi-Fi. If the adapter is disabled in Network Connections (ncpa.cpl), enable it; if it is missing there, check Device Manager and update the driver.'
    'NET-ADAPTER-001.SlowLink.Details' = 'Adapter {0} runs at only {1:N0} Mbps. A wired link normally runs at 1000 Mbps (gigabit).'
    'NET-ADAPTER-001.SlowLink.Recommendation' = 'Replace the patch cord, try another switch port or wall socket and update the adapter driver. In the adapter properties (Configure > Advanced) make sure Speed & Duplex is set to Auto Negotiation. If the switch or the cabling supports only 100 Mbps, this is normal.'

    # NET-DHCP-001
    'NET-DHCP-001.Title' = 'IP address from DHCP'
    'NET-DHCP-001.Ok.Details' = 'IPv4 addresses on the connected adapters: {0}. None of them is a self-assigned 169.254.x.x (APIPA) address.'
    'NET-DHCP-001.Apipa.Details' = 'Adapter {0} has the address {1}. Windows assigns a 169.254.x.x address itself when no DHCP server answers, so the adapter has no working network settings.'
    'NET-DHCP-001.Apipa.Recommendation' = 'Check the cable or the Wi-Fi connection, then run "ipconfig /renew". If the address stays 169.254.x.x, check that the DHCP server (or router) is running and has free addresses in its pool, that the switch port or Wi-Fi network is in the right VLAN, and that the DHCP Client service is running. As a test you can set a static address from the right subnet.'

    # NET-DNS-001
    'NET-DNS-001.Title' = 'DNS servers'
    'NET-DNS-001.Ok.Details' = 'The DNS servers answer: {0}.'
    'NET-DNS-001.NoServers.Details' = 'No DNS server is set on the connected adapters, so names cannot be resolved.'
    'NET-DNS-001.NoServers.Recommendation' = 'If the settings come from DHCP, run "ipconfig /renew" and check that the DHCP server hands out DNS servers. For a static address, enter the DNS servers in the IPv4 properties of the adapter (in a domain these are the domain controllers).'
    'NET-DNS-001.NoneRespond.Details' = 'None of the DNS servers answers: {0}. Names cannot be resolved.'
    'NET-DNS-001.NoneRespond.Recommendation' = 'First check the cable or Wi-Fi and the gateway. Then check that the DNS server addresses are correct, that the servers are running and that a firewall does not block port 53 (UDP and TCP). You can test a server with "Resolve-DnsName localhost -Server <address>".'
    'NET-DNS-001.ServerDown.Details' = 'The DNS server {0} does not answer.'
    'NET-DNS-001.ServerDown.Recommendation' = 'Check that this DNS server is running and reachable and that its address is correct. If the server no longer exists, remove it from the adapter settings: the PC waits for every dead server before it tries the next one, so names resolve slowly.'
    'NET-DNS-001.PublicOnDomain.Details' = 'This PC is in a domain, but the DNS server {0} is a public one. Public DNS servers know nothing about the domain, so logon, group policies and domain resources can fail at random.'
    'NET-DNS-001.PublicOnDomain.Recommendation' = 'Set the domain controllers (the internal DNS servers) as the only DNS servers of the adapter. If internet names must also resolve, set forwarders on the domain DNS servers instead of adding a public DNS server to the PC.'

    # NET-DNS-002
    'NET-DNS-002.Title' = 'Name resolution'
    'NET-DNS-002.Ok.Details' = 'Names resolve correctly: {0}.'
    'NET-DNS-002.DomainFail.Details' = 'The domain name {0} does not resolve. The PC cannot find the domain controllers, so domain logon, group policies and shared resources will not work.'
    'NET-DNS-002.DomainFail.Recommendation' = 'Check that the DNS servers of this PC are the DNS servers of the domain (check NET-DNS-001). On the domain controller, check that the DNS Server service is running and that the zone of the domain has records for the domain controllers. Then run "ipconfig /flushdns" and repeat the check.'
    'NET-DNS-002.ExternalFail.Details' = 'The internet name {0} does not resolve.'
    'NET-DNS-002.ExternalFail.Recommendation' = 'In a network without internet access this is normal. Otherwise check the DNS servers (check NET-DNS-001), the internet connection of the router and, on the DNS server, the forwarders or root hints. Then run "ipconfig /flushdns".'

    # NET-GATEWAY-001
    'NET-GATEWAY-001.Title' = 'Default gateway'
    'NET-GATEWAY-001.Ok.Details' = 'The gateway {0} answers ping in {1} ms.'
    'NET-GATEWAY-001.NoGateway.Details' = 'No default gateway is set, so this PC can reach only its own subnet.'
    'NET-GATEWAY-001.NoGateway.Recommendation' = 'If the address comes from DHCP, run "ipconfig /renew" and check that the DHCP server hands out the gateway (router) option. For a static address, enter the address of the router as the default gateway in the IPv4 properties of the adapter.'
    'NET-GATEWAY-001.Multiple.Details' = 'Default gateways are set on more than one adapter: {0}. Windows uses the route with the lowest metric, so traffic may go through the wrong network.'
    'NET-GATEWAY-001.Multiple.Recommendation' = 'If a VPN is connected, this is normal. Otherwise disable the adapter you do not need (for example Wi-Fi while the cable is plugged in) or remove the gateway from the adapter that must not carry internet traffic. The order of the routes is shown by "Get-NetRoute -DestinationPrefix 0.0.0.0/0".'
    'NET-GATEWAY-001.NoReply.Details' = 'The gateway {0} does not answer ping.'
    'NET-GATEWAY-001.NoReply.Recommendation' = 'Some routers are set not to answer ping, so this alone does not prove a fault. If the network does not work, check the cable or Wi-Fi, the power of the router and that the gateway address is correct (it must be in the same subnet as the address of the PC).'

    # NET-INTERNET-001
    'NET-INTERNET-001.Title' = 'Internet access'
    'NET-INTERNET-001.Ok.Details' = 'The connection to {0}, port {1} works.'
    'NET-INTERNET-001.NoInternet.Details' = 'Cannot connect to {0}, port {1}. The internet may be unreachable from this PC.'
    'NET-INTERNET-001.NoInternet.Recommendation' = 'If the network is isolated from the internet on purpose, this is normal. Otherwise check the router and the connection to the provider, then check whether a proxy server (check NET-PROXY-001) or a firewall blocks the connection. In an office the internet is often reachable only through a proxy server.'

    # NET-PROFILE-001
    'NET-PROFILE-001.Title' = 'Network profile'
    'NET-PROFILE-001.Ok.Details' = 'The network profile is {0}.'
    'NET-PROFILE-001.NoProfile.Details' = 'Windows reports no active network connection, so there is no network profile to check.'
    'NET-PROFILE-001.NoProfile.Recommendation' = 'Connect the PC to a network (check NET-ADAPTER-001). If it is connected, make sure the services Network List Service (netprofm) and Network Location Awareness (NlaSvc) are running, then run the check again.'
    'NET-PROFILE-001.Public.Details' = 'The network "{0}" has the Public profile. On a Public network Windows blocks file and printer sharing and network discovery, so shared folders and printers may be unreachable.'
    'NET-PROFILE-001.Public.Recommendation' = 'If this is a trusted network (office, home), switch it to Private: Settings > Network & internet > the connection > Network profile type > Private, or run "Set-NetConnectionProfile -InterfaceAlias <name> -NetworkCategory Private" as administrator. Keep Public for guest and public Wi-Fi networks. If the PC is in a domain and the profile is not DomainAuthenticated, the PC cannot reach a domain controller (checks NET-DNS-001 and NET-DNS-002).'

    # NET-PROXY-001
    'NET-PROXY-001.Title' = 'Proxy server'
    'NET-PROXY-001.Direct.Details' = 'No proxy server is set. The PC connects to the internet directly.'
    'NET-PROXY-001.Pac.Details' = 'The PC takes its proxy settings from the configuration script {0}.'
    'NET-PROXY-001.Proxy.Details' = 'The proxy server {0} answers.'
    'NET-PROXY-001.ProxyDown.Details' = 'The proxy server {0} does not answer, so programs that use it cannot reach the internet.'
    'NET-PROXY-001.ProxyDown.Recommendation' = 'If the PC has left the network where the proxy works (a laptop at home), turn the proxy off in Settings > Network & internet > Proxy and run "netsh winhttp reset proxy" as administrator. Otherwise check that the proxy server is running and that its address and port are correct.'

    # NET-TIME-001
    'NET-TIME-001.Title' = 'Time synchronization'
    'NET-TIME-001.Ok.Details' = 'The clock differs from the time source {1} by only {0:N3} s.'
    'NET-TIME-001.NoSource.Details' = 'Could not get the time from the time source {0}, so the clock of this PC cannot be checked.'
    'NET-TIME-001.NoSource.Recommendation' = 'Check that the time source is reachable and that UDP port 123 is open in the firewall. In a domain the PC takes its time from the domain controller: check the connection to it. Check that the Windows Time service (W32Time) is running ("Get-Service W32Time"). For a PC outside a domain, set the time server as administrator with "w32tm /config /manualpeerlist:<server> /syncfromflags:manual /update" and then "w32tm /resync".'
    'NET-TIME-001.NoSourceConfigured.Details' = 'No time source is configured on this PC, so its clock is not synchronized with anything.'
    'NET-TIME-001.NoSourceConfigured.Recommendation' = 'Set a time server as administrator with "w32tm /config /manualpeerlist:<server> /syncfromflags:manual /update", then run "w32tm /resync". Make sure the Windows Time service (W32Time) starts automatically. In a domain the PC should take its time from the domain: run "w32tm /config /syncfromflags:domhier /update".'
    'NET-TIME-001.Drift.Details' = 'The clock of this PC differs from the time source by {0:N1} s.'
    'NET-TIME-001.Drift.Recommendation' = 'Synchronize the clock now: run "w32tm /resync" as administrator. If the difference comes back, check the time source (the domain controller or the NTP server) and the battery of the motherboard (CMOS). A wrong time breaks certificate (TLS) checks, and beyond the limit it breaks domain logon.'
    'NET-TIME-001.DriftKerberos.Details' = 'The clock of this PC differs from the time source by {0:N1} s. By default Kerberos accepts a difference of at most 5 minutes, so domain logon and access to shared resources may already fail.'
    'NET-TIME-001.DriftKerberos.Recommendation' = 'Fix it now: run "w32tm /resync /rediscover" as administrator (if the PC is not in a domain, also check the time zone). Then find out why the time drifts: check the time source (the domain controller or the NTP server), the Windows Time service and the battery of the motherboard (CMOS); for a virtual machine check the time synchronization with the host.'

    # SYS-APPCRASH-001
    'SYS-APPCRASH-001.Title' = 'Application crashes'
    'SYS-APPCRASH-001.Ok.Details' = 'Application crashes in the last {1} days: {0}. No application crashed repeatedly. Stability index: {2:N1}.'
    'SYS-APPCRASH-001.Crashing.Details' = 'In the last {1} days these applications crashed repeatedly: {0}.'
    'SYS-APPCRASH-001.Crashing.Recommendation' = 'Update or reinstall the listed applications. Open Event Viewer (eventvwr.msc) > Windows Logs > Application, find the Application Error events (ID 1000), note the faulting module, and look for a fix on the vendor''s site.'

    # SYS-BATTERY-001
    'SYS-BATTERY-001.Title' = 'Battery wear'
    'SYS-BATTERY-001.NoBattery.Details' = 'This PC has no battery, or Windows does not report one.'
    'SYS-BATTERY-001.NoBattery.Recommendation' = 'Nothing to fix: this check applies to laptops and tablets.'
    'SYS-BATTERY-001.NoData.Details' = 'The battery report has no design capacity for this battery, so its wear cannot be calculated.'
    'SYS-BATTERY-001.NoData.Recommendation' = 'Update the BIOS and the battery and power management drivers from the PC vendor, then run the check again.'
    'SYS-BATTERY-001.Worn.Details' = 'The battery now holds only {0:N0}% of its original capacity.'
    'SYS-BATTERY-001.Worn.Recommendation' = 'Replace the battery. Until then keep the laptop plugged in and save your work often.'
    'SYS-BATTERY-001.Aging.Details' = 'The battery now holds {0:N0}% of its original capacity: it is wearing out.'
    'SYS-BATTERY-001.Aging.Recommendation' = 'Plan to replace the battery. To slow the wear, avoid full discharges and heat.'
    'SYS-BATTERY-001.Ok.Details' = 'The battery still holds {0:N0}% of its original capacity.'

    # SYS-BSOD-001
    'SYS-BSOD-001.Title' = 'Blue screen crashes (BSOD)'
    'SYS-BSOD-001.Ok.Details' = 'No blue screen crashes in the last {0} days.'
    'SYS-BSOD-001.Crashes.Details' = 'Blue screen crashes in the last {1} days: {0}. The latest was on {2:yyyy-MM-dd HH:mm}. Bug check codes: {3}.'
    'SYS-BSOD-001.Crashes.Recommendation' = 'Look up each bug check code in the Microsoft bug check code reference. Install Windows updates and update the drivers of the device the code points to (graphics, network, storage). If the codes differ every time, run the memory test (mdsched.exe).'
    'SYS-BSOD-001.ManyCrashes.Details' = 'Blue screen crashes in the last {1} days: {0}. The latest was on {2:yyyy-MM-dd HH:mm}. Bug check codes: {3}.'
    'SYS-BSOD-001.ManyCrashes.Recommendation' = 'The PC crashes often. Remember what changed before the first crash (a new driver, update or device) and undo it. Test the RAM (mdsched.exe), check the disk health and the temperatures, and analyze the dumps in %SystemRoot%\Minidump with WinDbg. If it keeps happening, contact the PC vendor.'

    # SYS-DISK-001
    'SYS-DISK-001.Title' = 'Free space on the system drive'
    'SYS-DISK-001.Ok.Details' = 'Free space: {0:N1} GB ({1:N0}% of the drive).'
    'SYS-DISK-001.Low.Details' = 'Only {0:N1} GB ({1:N0}%) is free. What can be cleaned (size in GB): {2}. User profiles not used for over 90 days: {3}.'
    'SYS-DISK-001.Low.Recommendation' = 'Run Disk Cleanup (cleanmgr) as administrator and choose Clean up system files. Empty the folders listed above and delete old user profiles that are no longer needed (System Properties > Advanced > User Profiles > Settings). Move large files to another drive.'
    'SYS-DISK-001.CriticalLow.Details' = 'Critically low: only {0:N1} GB ({1:N0}%) is free. What can be cleaned (size in GB): {2}. User profiles not used for over 90 days: {3}.'
    'SYS-DISK-001.CriticalLow.Recommendation' = 'Free up space now: Windows needs room for updates, the page file and crash dumps, and without it updates fail and the system becomes unstable. Run Disk Cleanup (cleanmgr) as administrator, empty the folders listed above, delete old user profiles and move large files to another drive.'

    # SYS-MEMORY-001
    'SYS-MEMORY-001.Title' = 'Memory and page file'
    'SYS-MEMORY-001.Ok.Details' = 'RAM available to Windows: {0:N1} GB, {1:N0}% of it is free.'
    'SYS-MEMORY-001.LowRam.Details' = 'Only {0:N0}% of the RAM is free.'
    'SYS-MEMORY-001.LowRam.Recommendation' = 'Close heavy applications and extra browser tabs, and check which processes use the most memory (check SYS-PERF-001). If the PC is short of memory all the time, add RAM.'
    'SYS-MEMORY-001.CommitHigh.Details' = 'Committed memory (RAM plus page file) has reached {0:N0}% of the limit. New memory requests may start to fail.'
    'SYS-MEMORY-001.CommitHigh.Recommendation' = 'Close heavy applications and restart the ones whose memory use keeps growing (a memory leak). Make sure the page file is on and large enough (System Properties > Advanced > Performance Settings > Advanced > Virtual memory). If this happens often, add RAM.'
    'SYS-MEMORY-001.NoPagefile.Details' = 'The page file is turned off.'
    'SYS-MEMORY-001.NoPagefile.Recommendation' = 'Turn the page file on with a system managed size (System Properties > Advanced > Performance Settings > Advanced > Virtual memory). Windows needs it to write crash dumps and to survive peaks in memory use.'

    # SYS-PERF-001
    'SYS-PERF-001.Title' = 'CPU and memory load'
    'SYS-PERF-001.Ok.Details' = 'CPU load is {0:N0}%. Top processes by CPU (%): {1}. Top processes by memory (MB): {2}.'
    'SYS-PERF-001.HighCpu.Details' = 'CPU load is {0:N0}%. Heaviest processes by CPU (%): {1}.'
    'SYS-PERF-001.NoCounters.Details' = 'The performance counters (WMI classes Win32_PerfFormattedData) are missing or damaged on this PC, so the load of the CPU and of the processes cannot be measured.'
    'SYS-PERF-001.NoCounters.Recommendation' = 'Rebuild the performance counters: in PowerShell as administrator run lodctr /R and then winmgmt /resyncperf, restart the PC and run the check again.'
    'SYS-PERF-001.HighCpu.Recommendation' = 'Check whether the load is expected: a scan, an update or a backup can load the CPU for a while. If it stays high, restart or update the heaviest application and scan the PC for malware.'

    # SYS-REBOOT-001
    'SYS-REBOOT-001.Title' = 'Pending restart'
    'SYS-REBOOT-001.Ok.Details' = 'No restart is pending.'
    'SYS-REBOOT-001.Pending.Details' = 'The PC is waiting for a restart. Sources: {0}.'
    'SYS-REBOOT-001.Pending.Recommendation' = 'Save your work and restart the PC. Choose Restart: with Fast Startup, Shut down does not fully restart the system. Install further updates only after the restart.'

    # SYS-SHUTDOWN-001
    'SYS-SHUTDOWN-001.Title' = 'Unexpected shutdowns'
    'SYS-SHUTDOWN-001.Ok.Details' = 'No unexpected shutdowns in the last {0} days.'
    'SYS-SHUTDOWN-001.Unexpected.Details' = 'Unexpected shutdowns or restarts in the last {1} days: {0}. The latest was on {2:yyyy-MM-dd HH:mm}.'
    'SYS-SHUTDOWN-001.Unexpected.Recommendation' = 'Check the power cable and the outlet. In Event Viewer open the System log and look at what happened just before each event (Kernel-Power 41, EventLog 6008) to tell a power loss from a crash. Install Windows updates and update the drivers.'
    'SYS-SHUTDOWN-001.Frequent.Details' = 'Unexpected shutdowns or restarts in the last {1} days: {0}. The latest was on {2:yyyy-MM-dd HH:mm}.'
    'SYS-SHUTDOWN-001.Frequent.Recommendation' = 'Power problems are likely. Connect the PC through a UPS (uninterruptible power supply) or to another outlet, check the power supply unit, and on a laptop check the battery and the charger. If the PC switches off under load, check the temperatures and the RAM.'

    # SYS-STARTUP-001
    'SYS-STARTUP-001.Title' = 'Startup programs'
    'SYS-STARTUP-001.Ok.Details' = 'Programs that start with Windows: {0}.'
    'SYS-STARTUP-001.Many.Details' = 'Too many programs start with Windows: {0}. The first ones: {1}.'
    'SYS-STARTUP-001.Many.Recommendation' = 'Open Task Manager (Ctrl+Shift+Esc), go to the startup apps and turn off what is not needed at sign-in (updaters, helpers, trial software). The PC will start faster and use less memory.'

    # SYS-UPTIME-001
    'SYS-UPTIME-001.Title' = 'Uptime'
    'SYS-UPTIME-001.Ok.Details' = 'The PC has been running for {0} days since the last restart.'
    'SYS-UPTIME-001.Long.Details' = 'The PC has not been restarted for {0} days.'
    'SYS-UPTIME-001.Long.Recommendation' = 'Restart the PC to apply pending updates and to free memory held by programs that have been running for a long time.'
    'SYS-UPTIME-001.LongFastStartup.Details' = 'The PC has not been restarted for {0} days. Fast Startup is on, so Shut down does not reset the uptime.'
    'SYS-UPTIME-001.LongFastStartup.Recommendation' = 'Choose Restart, not Shut down: with Fast Startup only Restart restarts the system fully. You can also turn Fast Startup off in the power settings.'
}

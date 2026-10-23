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

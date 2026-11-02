@{
    Id            = 'PRN-QUEUE-001'
    Category      = 'Printing'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/printmanagement/get-printjob'
        'https://learn.microsoft.com/powershell/module/printmanagement/get-printer'
    )
    Settings      = @{ StuckMinutes = 60 }
    Collect       = {
        $state = Get-ChekapPrintState
        if (-not ($state.PrintModule -and $state.SpoolerRunning)) { return $state }

        # Only a local printer has its queue on this PC; the queue of a connected printer is on its print server.
        # DocumentName and UserName are left out on purpose: they are personal data.
        $jobs = @(foreach ($printer in @(Get-Printer | Where-Object { [string]$_.Type -eq 'Local' })) {
                foreach ($job in @(Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue)) {
                    @{ Printer = [string]$printer.Name; Id = [int]$job.Id; Status = [string]$job.JobStatus; Submitted = $job.SubmittedTime }
                }
            })

        # Access denied (no administrator rights) gives $null for both, not a wrong 0.
        $spool = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
        $bytes = Get-ChekapFolderSize -Path $spool
        $files = $null
        if ($null -ne $bytes) { $files = @(Get-ChildItem -LiteralPath $spool -File -Force -ErrorAction SilentlyContinue).Count }
        @{ PrintModule = $true; SpoolerRunning = $true; Jobs = $jobs; SpoolFiles = $files; SpoolBytes = $bytes; Now = Get-Date }
    }
    Evaluate      = {
        param($Data, $Settings)
        if (-not $Data.PrintModule) { return @{ Status = 'Skipped'; Message = 'NoPrintModule' } }
        if (-not $Data.SpoolerRunning) { return @{ Status = 'Skipped'; Message = 'SpoolerStopped' } }

        # Age comes from the time collected with the jobs, never from the clock at evaluation.
        $jobs = @(@($Data.Jobs) | ForEach-Object {
                $minutes = 0
                if ($_.Submitted) { $minutes = [math]::Floor(($Data.Now - $_.Submitted).TotalMinutes) }
                @{ Printer = $_.Printer; Minutes = $minutes; Stuck = ([string]$_.Status -match 'Error|Deleting') -or ($minutes -ge $Settings.StuckMinutes) }
            })
        $stuck = @($jobs | Where-Object { $_.Stuck })
        if ($stuck.Count -eq 0) {
            return @{ Status = 'OK'; Message = 'Ok'; Args = @($jobs.Count) }
        }
        # Not Group-Object: its group order differs between PowerShell 7 versions; printers keep the order they were listed in.
        foreach ($printer in @($stuck | ForEach-Object { $_.Printer } | Select-Object -Unique)) {
            $group = @($stuck | Where-Object { $_.Printer -ceq $printer })
            $oldest = ($group | ForEach-Object { $_.Minutes } | Measure-Object -Maximum).Maximum
            @{ Status = 'Warning'; Message = 'Stuck'; Target = $printer; Args = @($group.Count, $oldest); Evidence = @{ Printer = $printer; StuckJobs = $group.Count; OldestMinutes = $oldest } }
        }
    }
}

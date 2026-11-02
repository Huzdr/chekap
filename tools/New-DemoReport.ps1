[CmdletBinding()]
param(
    # Folder for the demo reports; defaults to out/demo in the repository. Each language gets its own subfolder.
    [string]$OutputPath,

    # Also render docs/images/report-uk.png and report-en.png from the demo reports with headless Microsoft Edge.
    [switch]$Screenshot
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty in a param() default on Windows PowerShell 5.1, so resolve it here.
$root = Split-Path -Path $PSScriptRoot -Parent
if (-not $OutputPath) { $OutputPath = Join-Path $root 'out/demo' }
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$computer = 'PC-042'
$utf8 = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false

# Everything below is invented. Each entry is the data a check's Collect would return, or the error it would throw.
# The real Evaluate block of the check turns it into the finding, so every sentence in the demo is the real localized text.
$now = Get-Date
$accounting = 'Принтер бухгалтерії'
$specs = @(
    @{ Id = 'SYS-DISK-001'; Data = @{
            Drive       = 'C:'
            SizeBytes   = [long](238GB)
            FreeBytes   = [long](2.1GB)
            Candidates  = @(
                @{ Path = 'C:\Users\user01\AppData\Local\Temp'; Bytes = [long](3.4GB) }
                @{ Path = 'C:\Windows\SoftwareDistribution\Download'; Bytes = [long](1.8GB) }
                @{ Path = 'C:\Windows\Temp'; Bytes = [long](0.4GB) }
            )
            OldProfiles = 3
        }
    }
    @{ Id = 'SYS-UPTIME-001'; Data = @{ LastBoot = $now.AddDays(-37.4); Now = $now; FastStartup = $true } }
    @{ Id = 'SYS-REBOOT-001'; Data = @{ WindowsUpdate = $true; Cbs = $false; FileRenameCount = 0 } }
    # The text of a Windows error comes in the language of Windows, so it is given for both languages.
    @{ Id = 'SYS-BSOD-001'; Throw = @{ uk = 'Відмовлено в доступі.'; en = 'Access is denied.' } }
    @{ Id = 'SYS-APPCRASH-001'; Throw = @{ uk = 'Сервер RPC недоступний.'; en = 'The RPC server is unavailable.' } }
    @{ Id = 'SYS-BATTERY-001'; Data = @{ HasBattery = $false; Batteries = @() } }
    @{ Id = 'NET-GATEWAY-001'; Data = @{
            Routes = @(@{ Alias = 'Ethernet'; NextHop = '192.0.2.1' })
            Ping   = @{ '192.0.2.1' = @{ Success = $true; RoundtripMs = 1 } }
        }
    }
    @{ Id = 'NET-TIME-001'; Data = @{
            Type          = 'NT5DS'
            NtpServer     = $null
            Source        = 'contoso.local'
            Output        = @('{0:HH:mm:ss}, +412.7000000s' -f $now)
            OffsetSeconds = 412.7
            ServiceStatus = 'Running'
        }
    }
    @{ Id = 'PRN-SPOOLER-001'; Data = @{ Status = 'Running'; StartType = 'Automatic'; ProductType = 1 } }
    @{ Id = 'PRN-PORT-001'; Data = @{
            PrintModule    = $true
            SpoolerRunning = $true
            Printers       = @(
                @{ Name = $accounting; Type = 'Local'; PortName = 'IP_192.0.2.50'; Status = 'Normal'; Server = ''; Kind = 'Network'; Host = '192.0.2.50'; Port = 9100 }
                @{ Name = 'PRN-2F-HP'; Type = 'Local'; PortName = 'IP_192.0.2.60'; Status = 'Normal'; Server = ''; Kind = 'Network'; Host = '192.0.2.60'; Port = 9100 }
            )
            Reachable      = @{ $accounting = $false; 'PRN-2F-HP' = $true }
        }
    }
    @{ Id = 'PRN-QUEUE-001'; Data = @{
            PrintModule    = $true
            SpoolerRunning = $true
            Jobs           = @(
                @{ Printer = $accounting; Id = 7; Status = 'Error'; Submitted = $now.AddMinutes(-87) }
                @{ Printer = $accounting; Id = 8; Status = 'Normal'; Submitted = $now.AddMinutes(-64) }
                @{ Printer = $accounting; Id = 9; Status = 'Normal'; Submitted = $now.AddMinutes(-21) }
                @{ Printer = $accounting; Id = 10; Status = 'Normal'; Submitted = $now.AddMinutes(-3) }
            )
            SpoolFiles     = 8
            SpoolBytes     = [long](2.4MB)
            Now            = $now
        }
    }
    @{ Id = 'PRN-SCAN-001'; Data = @{
            Devices  = @()
            Services = @(@{ Name = 'stisvc'; Status = 'Running'; StartType = 'Automatic'; TriggerStart = $false })
        }
    }
)

# The same shape Get-ChekapSystemInfo returns.
$systemInfo = @{
    ComputerName     = $computer
    OsCaption        = 'Microsoft Windows 11 Pro'
    OsBuild          = 22631
    OsDisplayVersion = '23H2'
    Manufacturer     = 'Contoso'
    Model            = 'Desktop D100'
    Cpu              = 'Intel(R) Core(TM) i5-10500 CPU @ 3.10GHz'
    RamGB            = 16
    LastBoot         = $now.AddDays(-37.4)
    IPv4             = [string[]]@('192.0.2.42')
    Domain           = 'contoso.local'
    PartOfDomain     = $true
}
$notes = @{
    uk = 'Заявка INC-4821: PC-042 не друкує на принтер бухгалтерії'
    en = 'Ticket INC-4821: PC-042 does not print to the accounting printer'
}

# The private helpers (the runner and the exporter) are reachable only from inside the module.
$module = Import-Module -Name (Join-Path $root 'Chekap/Chekap.psd1') -Force -PassThru
$savedCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
try {
    $files = foreach ($language in 'uk', 'en') {
        # Numbers in the texts follow the culture of the session: 2,1 GB would be wrong in an English report made on a Ukrainian PC.
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo($(if ($language -eq 'uk') { 'uk-UA' } else { 'en-US' }))
        $folder = Join-Path $OutputPath $language
        $null = [System.IO.Directory]::CreateDirectory($folder)
        # A report is never overwritten, so an earlier demo report has to go first. Only its own files are removed.
        Get-ChildItem -LiteralPath $folder -File -Filter "Chekap-$computer-*" | Remove-Item -Force

        $results = & $module {
            param($specs, $language)
            foreach ($spec in $specs) {
                $check = ($script:ChekapChecks | Where-Object { $_.Id -eq $spec.Id } | Select-Object -First 1).Clone()
                $check.Collect = if ($spec.ContainsKey('Throw')) { { throw $spec.Throw[$language] }.GetNewClosure() } else { { $spec.Data }.GetNewClosure() }
                Invoke-ChekapCheck -Check $check -Language $language
            }
        } $specs $language
        # The runner stamps the name of the PC it runs on.
        foreach ($result in $results) { $result.ComputerName = $computer }

        & $module {
            param($results, $language, $folder, $note, $systemInfo)
            Export-ChekapReport -Result $results -Language $language -OutputPath $folder -Note $note -SystemInfo $systemInfo
        } @($results) $language $folder $notes[$language] $systemInfo
    }
}
finally {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $savedCulture
    Remove-Module -Name Chekap -ErrorAction SilentlyContinue
}
$files

if ($Screenshot) {
    $edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    if (-not $edge) {
        Write-Warning 'Microsoft Edge was not found, so the screenshots were not rendered.'
        return
    }
    $images = Join-Path $root 'docs/images'
    $null = [System.IO.Directory]::CreateDirectory($images)
    # Edge gets its own empty profile: headless mode must not attach to a running Edge or touch the profile of the user.
    $profileFolder = Join-Path $OutputPath '.edge-profile'
    try {
        foreach ($language in 'uk', 'en') {
            $html = $files | Where-Object { $_.Extension -eq '.html' -and $_.Directory.Name -eq $language }
            $png = Join-Path $images "report-$language.png"
            # The picture is made next to the reports and moved over the committed one only when it is good.
            $temp = Join-Path $OutputPath "screenshot-$language.png"
            if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
            # Headless Edge follows the Windows theme. The shot is taken from a copy without the dark-theme rule, so it is light on every PC.
            $copy = Join-Path $html.DirectoryName 'screenshot.html'
            $page = [System.IO.File]::ReadAllText($html.FullName, [System.Text.Encoding]::UTF8)
            $light = $page.Replace('(prefers-color-scheme: dark)', '(prefers-color-scheme: none)')
            if ($light -ceq $page) {
                Write-Warning 'The report has no dark-theme rule to switch off, so the screenshot may follow the Windows theme. Look at it before you commit it.'
            }
            [System.IO.File]::WriteAllText($copy, $light, $utf8)
            try {
                $arguments = @(
                    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--no-first-run', '--disable-extensions',
                    "--user-data-dir=`"$profileFolder`"", '--window-size=1280,1600', "--screenshot=`"$temp`"", ('"{0}"' -f ([System.Uri]$copy).AbsoluteUri)
                )
                $process = Start-Process -FilePath $edge -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
            }
            finally {
                Remove-Item -LiteralPath $copy -Force -ErrorAction SilentlyContinue
            }
            $signature = if (Test-Path -LiteralPath $temp) { [System.IO.File]::ReadAllBytes($temp) | Select-Object -First 8 }
            if (($signature -join ',') -ne '137,80,78,71,13,10,26,10') {
                if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
                throw "Edge (exit code $($process.ExitCode)) did not write a PNG file for $language. $png is unchanged."
            }
            Move-Item -LiteralPath $temp -Destination $png -Force
            Get-Item -LiteralPath $png
        }
    }
    finally {
        if (Test-Path -LiteralPath $profileFolder) { Remove-Item -LiteralPath $profileFolder -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

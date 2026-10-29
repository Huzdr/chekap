BeforeAll {
    $script:root = Split-Path -Path $PSScriptRoot -Parent
    $script:psd1 = Join-Path $script:root 'Chekap/Chekap.psd1'
    Import-Module $script:psd1 -Force

    # Results are built the way the runner builds them. The strings are fixtures; only Report.* keys come from the real tables.
    $script:results = InModuleScope Chekap {
        $pc = 'PC-042'
        $check = { param($id, $category) @{ Id = $id; Category = $category; References = @('https://learn.microsoft.com/windows/') } }
        # A nested date, a one-item array, an empty array and a list of objects: the shapes that Windows PowerShell 5.1 gets wrong.
        $evidence = @{
            Seen  = [datetime]'2026-03-10T11:30:00'
            Jobs  = @(@{ Name = 'job1' })
            One   = @('only')
            Empty = @()
            Count = 3
        }
        @(
            New-ChekapResult -Check (& $check 'PRN-QUEUE-001' 'Printing') -Status Warning -Title 'Print queue' -Details 'Two stuck jobs.' `
                -Recommendation 'Clear the queue.' -Target ('Принтер бухгалтерії') -Evidence $evidence -ComputerName $pc
            New-ChekapResult -Check (& $check 'NET-DNS-001' 'Network') -Status OK -Title 'DNS' -Details 'Printer </script><b>x costs $1 and $& more.' `
                -Target '</script><b>x' -ComputerName $pc
            New-ChekapResult -Check (& $check 'SYS-BATTERY-001' 'System') -Status Skipped -Title 'Battery' -Details 'No battery.' -ComputerName $pc
        )
    }
    $script:system = @{
        ComputerName     = 'PC-042'
        OsCaption        = 'Microsoft Windows 11 Pro'
        OsBuild          = 26100
        OsDisplayVersion = '24H2'
        Manufacturer     = 'Contoso'
        Model            = 'Workstation X1'
        Cpu              = 'Contoso Core 8'
        RamGB            = 16
        LastBoot         = [datetime]'2026-03-01T08:00:00'
        IPv4             = [string[]]@('192.0.2.10')
        Domain           = 'contoso.local'
        PartOfDomain     = $true
    }

    # Calls the private exporter in module scope. $Extra can override Language, Format, Note, SystemInfo.
    $script:export = {
        param($Result, $Path, [hashtable]$Extra = @{})
        $arguments = @{ Language = 'en'; SystemInfo = $script:system }
        foreach ($key in $Extra.Keys) { $arguments[$key] = $Extra[$key] }
        $files = InModuleScope Chekap -Parameters @{ Result = $Result; Path = $Path; Arguments = $arguments } {
            Export-ChekapReport -Result $Result -OutputPath $Path @Arguments
        }
        , @($files)
    }
    # Runs code in a child session of the same engine, like a user typing the command: Pester wraps every test in try/catch, and a try/catch
    # anywhere up the stack turns a statement-terminating error into a throw, which hides the very bug these tests guard against.
    # Output lines come back as strings; the code under test prints a RESULT line that says what the failing call left behind.
    $script:runPlain = {
        param([string]$Body)
        # The child's error text comes back through 2>&1; Pester's own Stop would turn it into an exception here.
        $ErrorActionPreference = 'Continue'
        $preamble = @'
Import-Module '<PSD1>'
$module = Get-Module Chekap
$pc = 'PC-042'
$result = & $module { param($PC) New-ChekapResult -Check @{ Id = 'NET-DNS-001'; Category = 'Network'; References = @('https://learn.microsoft.com/') } -Status OK -Title 'DNS' -Details 'fine' -ComputerName $PC } $pc
function Export-Plain($Dir) { & $module { param($R, $D) Export-ChekapReport -Result @($R) -Language en -OutputPath $D -SystemInfo @{ ComputerName = 'PC-042' } } $result $Dir }
'@
        $code = $preamble.Replace('<PSD1>', $script:psd1) + "`n" + $Body
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($code))
        @(& (Get-Process -Id $PID).Path -NoProfile -NonInteractive -OutputFormat Text -EncodedCommand $encoded 2>&1 | ForEach-Object { "$_" })
    }
    $script:readText = { param($File) [System.IO.File]::ReadAllText($File.FullName, [System.Text.Encoding]::UTF8) }
    # The data block of an HTML report, parsed. Windows PowerShell 5.1 escapes more characters than 7, so tests compare parsed values.
    $script:readHtmlData = {
        param($File)
        $match = [regex]::Match((& $script:readText $File), '<script id="chekap-data" type="application/json">(.*?)</script>', 'Singleline')
        $match.Groups[1].Value | ConvertFrom-Json
    }
}

AfterAll {
    Remove-Module Chekap -ErrorAction SilentlyContinue
}

Describe 'Export-ChekapReport' {
    It 'writes html and json with expected names' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'names')
        $files.Count | Should -Be 2
        ($files | Where-Object Extension -eq '.html').Name | Should -Match '^Chekap-PC-042-\d{8}-\d{4}\.html$'
        ($files | Where-Object Extension -eq '.json').Name | Should -Match '^Chekap-PC-042-\d{8}-\d{4}\.json$'
        ($files[0].BaseName) | Should -Be $files[1].BaseName
        $files | ForEach-Object { Test-Path -LiteralPath $_.FullName | Should -BeTrue }
    }

    It 'writes only the requested format' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'json-only') @{ Format = 'Json' }
        $files.Count | Should -Be 1
        $files[0].Extension | Should -Be '.json'
        @(Get-ChildItem -LiteralPath (Join-Path $TestDrive 'json-only')).Count | Should -Be 1
    }

    It 'json has schemaVersion 1, note, system and ISO timestamps' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'json') @{ Note = 'Ticket 4711' }
        $raw = Get-Content -LiteralPath ($files | Where-Object Extension -eq '.json').FullName -Raw -Encoding UTF8
        $doc = $raw | ConvertFrom-Json
        $doc.schemaVersion | Should -Be 1
        $doc.chekapVersion | Should -Be (Import-PowerShellDataFile -Path $script:psd1).ModuleVersion
        $doc.language | Should -Be 'en'
        $doc.computer | Should -Be 'PC-042'
        $doc.note | Should -Be 'Ticket 4711'
        $doc.system.OsCaption | Should -Be 'Microsoft Windows 11 Pro'
        $doc.system.Domain | Should -Be 'contoso.local'
        $doc.results.Count | Should -Be 3
        # The raw text, not the parsed object: PowerShell 7 turns ISO strings back into dates when it parses.
        $raw | Should -Match '"generated":\s*"\d{4}-\d\d-\d\dT'
        $raw | Should -Match '"Timestamp":\s*"\d{4}-\d\d-\d\dT'
        $raw | Should -Match '"LastBoot":\s*"2026-03-01T08:00:00'
        $raw | Should -Match '"Seen":\s*"2026-03-10T11:30:00'
        $doc.results[0].CheckId | Should -Be 'PRN-QUEUE-001'
        $doc.results[0].PSObject.Properties.Name -join ',' | Should -Be 'CheckId,Category,ComputerName,Status,Target,Title,Details,Recommendation,FixId,FixRiskLevel,Evidence,References,Timestamp'
    }

    It 'json has note null without -Note and system null without -SystemInfo' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'bare') @{ SystemInfo = $null }
        $doc = Get-Content -LiteralPath ($files | Where-Object Extension -eq '.json').FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $doc.note | Should -BeNullOrEmpty
        $doc.system | Should -BeNullOrEmpty
        $doc.computer | Should -Be 'PC-042'
    }

    It 'json round-trips Cyrillic Target' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'cyrillic') @{ Note = 'Скарга: не друкує' }
        $doc = Get-Content -LiteralPath ($files | Where-Object Extension -eq '.json').FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $doc.results[0].Target | Should -Be 'Принтер бухгалтерії'
        $doc.note | Should -Be 'Скарга: не друкує'
    }

    It 'keeps results, arrays and empty arrays as JSON arrays for a single result' {
        $files = & $script:export @($script:results[0]) (Join-Path $TestDrive 'single')
        $raw = Get-Content -LiteralPath ($files | Where-Object Extension -eq '.json').FullName -Raw -Encoding UTF8
        $raw | Should -Match '"results":\s*\['
        $raw | Should -Match '"References":\s*\['
        $raw | Should -Match '"One":\s*\[\s*"only"\s*\]'
        $raw | Should -Match '"Empty":\s*\[\s*\]'
        $raw | Should -Match '"IPv4":\s*\['
        $doc = $raw | ConvertFrom-Json
        $doc.results -is [array] | Should -BeTrue
        $doc.results.Count | Should -Be 1
    }

    It 'never writes the Windows PowerShell date format' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'dates')
        foreach ($file in $files) { (& $script:readText $file) | Should -Not -Match '\\/Date\(' }
    }

    It 'writes UTF-8 without byte order mark' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'bom')
        foreach ($file in $files) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
        }
        $html = & $script:readText ($files | Where-Object Extension -eq '.html')
        $html | Should -Match '<meta charset="utf-8">'
        $html | Should -Match 'Принтер бухгалтерії'
    }

    It 'html escapes script-breaking text' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'escape')
        $htmlFile = $files | Where-Object Extension -eq '.html'
        (& $script:readText $htmlFile) | Should -Not -Match ([regex]::Escape('</script><b>x'))
        # Only the data block and the code block close a script element.
        [regex]::Matches((& $script:readText $htmlFile), '</script>').Count | Should -Be 2
        $data = & $script:readHtmlData $htmlFile
        $data.results[1].Target | Should -Be '</script><b>x'
        # A dollar sign in the data is not a replacement pattern.
        $data.results[1].Details | Should -Be 'Printer </script><b>x costs $1 and $& more.'
    }

    It 'html has no placeholder left' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'token')
        (& $script:readText ($files | Where-Object Extension -eq '.html')) | Should -Not -Match '__CHEKAP_DATA__'
    }

    It 'html strings follow language' -ForEach @(@{ L = 'uk' }, @{ L = 'en' }) {
        $files = & $script:export $script:results (Join-Path $TestDrive "lang-$L") @{ Language = $L }
        $table = InModuleScope Chekap -Parameters @{ L = $L } { Get-ChekapStringTable -Language $L }
        $data = & $script:readHtmlData ($files | Where-Object Extension -eq '.html')
        $data.language | Should -Be $L
        $data.strings.'Report.Title' | Should -Be $table['Report.Title']
        $data.strings.'Status.Critical' | Should -Be $table['Status.Critical']
        $data.strings.'Category.Printing' | Should -Be $table['Category.Printing']
        $data.strings.'Report.Footer' | Should -Be $table['Report.Footer']
        # The other language must not leak in.
        $other = if ($L -eq 'uk') { 'en' } else { 'uk' }
        $otherTable = InModuleScope Chekap -Parameters @{ L = $other } { Get-ChekapStringTable -Language $L }
        $data.strings.'Report.Title' | Should -Not -Be $otherTable['Report.Title']
        # Only the keys the page uses are embedded.
        @($data.strings.PSObject.Properties.Name | Where-Object { $_ -notmatch '^(Report|Status|Category)\.' }) | Should -BeNullOrEmpty
    }

    It 'does not put the interface strings in the json file' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'nostrings')
        (Get-Content -LiteralPath ($files | Where-Object Extension -eq '.json').FullName -Raw -Encoding UTF8) | Should -Not -Match '"strings"'
    }

    It 'resolves a relative output path against the PowerShell location' {
        Push-Location -LiteralPath $TestDrive
        try {
            $files = & $script:export $script:results 'rel-out'
        }
        finally {
            Pop-Location
        }
        foreach ($file in $files) { $file.DirectoryName | Should -Be (Join-Path $TestDrive 'rel-out') }
    }

    It 'creates the output folder with its parents' {
        $files = & $script:export $script:results (Join-Path $TestDrive 'a/b/c')
        Test-Path -LiteralPath (Join-Path $TestDrive 'a/b/c') -PathType Container | Should -BeTrue
        $files.Count | Should -Be 2
    }
}

Describe 'Export-ChekapReport file names and write failures' {
    BeforeEach {
        Mock Get-Date { [datetime]'2026-03-10T12:00:00' } -ModuleName Chekap
        $script:base = 'Chekap-PC-042-20260310-1200'
    }

    It 'never overwrites: a second run in the same minute takes -2 for both files' {
        $dir = Join-Path $TestDrive 'twice'
        $first = & $script:export $script:results $dir
        $second = & $script:export $script:results $dir @{ Language = 'uk' }
        @(Get-ChildItem -LiteralPath $dir -File).Count | Should -Be 4
        ($first.Name | Sort-Object) -join ',' | Should -Be "$script:base.html,$script:base.json"
        ($second.Name | Sort-Object) -join ',' | Should -Be "$script:base-2.html,$script:base-2.json"
        # The first pair is untouched.
        (Get-Content -LiteralPath (Join-Path $dir "$script:base.json") -Raw -Encoding UTF8 | ConvertFrom-Json).language | Should -Be 'en'
        (Get-Content -LiteralPath (Join-Path $dir "$script:base-2.json") -Raw -Encoding UTF8 | ConvertFrom-Json).language | Should -Be 'uk'
    }

    It 'keeps counting: a third run takes -3' {
        $dir = Join-Path $TestDrive 'thrice'
        $null = & $script:export $script:results $dir
        $null = & $script:export $script:results $dir
        $third = & $script:export $script:results $dir
        ($third.Name | Sort-Object) -join ',' | Should -Be "$script:base-3.html,$script:base-3.json"
    }

    It 'takes the suffix for both files when only the other format exists' {
        $dir = Join-Path $TestDrive 'other-format'
        $null = & $script:export $script:results $dir @{ Format = 'Json' }
        $second = & $script:export $script:results $dir
        ($second.Name | Sort-Object) -join ',' | Should -Be "$script:base-2.html,$script:base-2.json"
    }

    It 'a report that cannot be written gives one error and no file' {
        $dir = Join-Path $TestDrive 'plain-blocked'
        # A folder sits where the report file belongs (this minute and the next one): the name is free, but the write fails.
        $body = @'
$dir = '<DIR>'
foreach ($minutes in 0, 1) { $null = New-Item -ItemType Directory -Path (Join-Path $dir ('Chekap-PC-042-{0}.html' -f (Get-Date).AddMinutes($minutes).ToString('yyyyMMdd-HHmm'))) -Force }
$Error.Clear()
$files = Export-Plain $dir
'RESULT files={0} onDisk={1} errors={2}' -f @($files).Count, @(Get-ChildItem -LiteralPath $dir -File).Count, $Error.Count
'@
        $output = & $script:runPlain $body.Replace('<DIR>', $dir)
        # No FileInfo for a file that was never written, no second file after the first one failed, and one error record, not a stack of them.
        $output | Should -Contain 'RESULT files=0 onDisk=0 errors=1'
    }

    It 'an output folder that cannot be created gives one error and no file' {
        $blocker = Join-Path $TestDrive 'plain-blocker'
        Set-Content -LiteralPath $blocker -Value 'not a folder'
        $body = @'
$Error.Clear()
$files = Export-Plain '<DIR>'
'RESULT files={0} errors={1}' -f @($files).Count, $Error.Count
'@
        $output = & $script:runPlain $body.Replace('<DIR>', (Join-Path $blocker 'sub'))
        $output | Should -Contain 'RESULT files=0 errors=1'
    }
}

Describe 'report.html template' {
    BeforeAll {
        $script:templatePath = Join-Path $script:root 'Chekap/Templates/report.html'
        $script:template = [System.IO.File]::ReadAllText($script:templatePath, [System.Text.Encoding]::UTF8)
    }

    It 'has no byte order mark' {
        $bytes = [System.IO.File]::ReadAllBytes($script:templatePath)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
    }

    It 'holds the data token once' {
        [regex]::Matches($script:template, '__CHEKAP_DATA__').Count | Should -Be 1
        $script:template | Should -Match '<script id="chekap-data" type="application/json">__CHEKAP_DATA__</script>'
    }

    It 'blocks every external load' {
        $script:template | Should -Match "http-equiv=""Content-Security-Policy"" content=""default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:"""
        $script:template | Should -Not -Match '<link\b|@import|url\(|<img\b|\bsrc\s*='
    }

    It 'puts data in the page only as text' {
        $script:template | Should -Not -Match 'innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(|new Function'
        $script:template | Should -Match '/\^https\?:\\/\\//i'
    }

    It 'lets the passport labels size to their text' {
        $script:template | Should -Not -Match 'flex:\s*0 0 8\.5rem'
        $script:template | Should -Match 'grid-template-columns:\s*max-content'
    }

    It 'supports dark theme, print and phones' {
        $script:template | Should -Match 'prefers-color-scheme: dark'
        $script:template | Should -Match '@media print'
        $script:template | Should -Match 'name="viewport"'
        $script:template | Should -Match 'aria-pressed'
    }

    It 'asks only for string keys that both tables have' {
        $en = Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/en-US/Chekap.strings.psd1')
        $uk = Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/uk-UA/Chekap.strings.psd1')
        $keys = @([regex]::Matches($script:template, "'((?:Report|Status|Category)(?:\.[A-Za-z]+)+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $keys.Count | Should -BeGreaterThan 15
        foreach ($key in $keys) {
            $en.ContainsKey($key) | Should -BeTrue -Because "$key is missing in en-US"
            $uk.ContainsKey($key) | Should -BeTrue -Because "$key is missing in uk-UA"
        }
    }
}

Describe 'Get-ChekapSystemInfo' {
    BeforeEach {
        Mock Get-CimInstance { [pscustomobject]@{ Caption = 'Microsoft Windows 11 Pro'; BuildNumber = '26100'; LastBootUpTime = [datetime]'2026-03-01T08:00:00' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
        Mock Get-CimInstance { [pscustomobject]@{ Manufacturer = 'Contoso'; Model = 'Workstation X1'; TotalPhysicalMemory = [uint64]17179869184; Domain = 'contoso.local'; PartOfDomain = $true } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
        Mock Get-CimInstance { [pscustomobject]@{ Name = '  Contoso Core 8  ' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_Processor' }
        Mock Get-ItemProperty { [pscustomobject]@{ DisplayVersion = '24H2' } } -ModuleName Chekap
        Mock Get-ChekapConnectedInterface { @{ Index = 4; Alias = 'Ethernet' } } -ModuleName Chekap
        Mock Get-NetIPAddress {
            [pscustomobject]@{ InterfaceIndex = 9; IPAddress = '198.51.100.7' }
            [pscustomobject]@{ InterfaceIndex = 4; IPAddress = '192.0.2.10' }
        } -ModuleName Chekap
    }

    It 'Get-ChekapSystemInfo returns all keys with mocked CIM' {
        $info = InModuleScope Chekap { Get-ChekapSystemInfo }
        $info.Keys | Sort-Object | Should -Be @('ComputerName', 'Cpu', 'Domain', 'IPv4', 'LastBoot', 'Manufacturer', 'Model', 'OsBuild', 'OsCaption', 'OsDisplayVersion', 'PartOfDomain', 'RamGB')
        $info.ComputerName | Should -Be $env:COMPUTERNAME
        $info.OsCaption | Should -Be 'Microsoft Windows 11 Pro'
        $info.OsBuild | Should -Be 26100
        $info.OsDisplayVersion | Should -Be '24H2'
        $info.Manufacturer | Should -Be 'Contoso'
        $info.Model | Should -Be 'Workstation X1'
        $info.Cpu | Should -Be 'Contoso Core 8'
        $info.RamGB | Should -Be 16
        $info.LastBoot | Should -Be ([datetime]'2026-03-01T08:00:00')
        $info.Domain | Should -Be 'contoso.local'
        $info.PartOfDomain | Should -BeTrue
        # Only the connected interface; the other address belongs to an interface that is not in use.
        ($info.IPv4 -join ',') | Should -Be '192.0.2.10'
    }

    It 'leaves OsDisplayVersion $null on a Windows without it' {
        Mock Get-ItemProperty { [pscustomobject]@{ ProductName = 'Windows' } } -ModuleName Chekap -ParameterFilter { $true }
        (InModuleScope Chekap { Get-ChekapSystemInfo }).OsDisplayVersion | Should -BeNullOrEmpty
    }

    It 'fills what it can when CIM and the network cmdlets fail' {
        Mock Get-CimInstance { throw 'WMI is broken' } -ModuleName Chekap -ParameterFilter { $true }
        Mock Get-ItemProperty { throw 'no registry' } -ModuleName Chekap -ParameterFilter { $true }
        Mock Get-NetIPAddress { throw 'no network module' } -ModuleName Chekap -ParameterFilter { $true }
        $info = InModuleScope Chekap { Get-ChekapSystemInfo }
        $info.ComputerName | Should -Be $env:COMPUTERNAME
        $info.OsCaption | Should -BeNullOrEmpty
        $info.RamGB | Should -BeNullOrEmpty
        $info.LastBoot | Should -BeNullOrEmpty
        $info.PartOfDomain | Should -BeNullOrEmpty
        @($info.IPv4).Count | Should -Be 0
    }
}

Describe 'Invoke-ChekapAudit' {
    BeforeEach {
        $fixture = $script:results
        $system = $script:system
        Mock Invoke-ChekapCheck { $fixture }.GetNewClosure() -ModuleName Chekap
        Mock Get-ChekapSystemInfo { $system }.GetNewClosure() -ModuleName Chekap
        Mock Export-ChekapReport { New-Object System.IO.FileInfo 'C:\Reports\Chekap-PC-042-20260310-1200.html' } -ModuleName Chekap
        # A new folder for every test: TestDrive keeps what an earlier test of this block created.
        $script:out = Join-Path (Join-Path $TestDrive ([guid]::NewGuid().ToString())) 'reports'
    }

    It 'Invoke-ChekapAudit writes no files without -OutputPath' {
        $result = @(Invoke-ChekapAudit -Language en -CheckId 'NET-DNS-001')
        $result.Count | Should -Be 3
        $result[0].CheckId | Should -Be 'PRN-QUEUE-001'
        Should -Invoke Export-ChekapReport -ModuleName Chekap -Times 0 -Exactly
        Should -Invoke Get-ChekapSystemInfo -ModuleName Chekap -Times 0 -Exactly
    }

    It 'runs only the selected checks in the chosen language' {
        $null = Invoke-ChekapAudit -Language uk -CheckId 'NET-DNS-001'
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { @($Check).Count -eq 1 -and $Check[0].Id -eq 'NET-DNS-001' -and $Language -eq 'uk' }
    }

    It 'runs every check of the chosen categories' {
        $null = Invoke-ChekapAudit -Language en -Category Network, Printing
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            @($Check | Where-Object { $_.Category -notin 'Network', 'Printing' }).Count -eq 0 -and @($Check | Where-Object Category -eq 'Network').Count -gt 0 -and @($Check | Where-Object Category -eq 'Printing').Count -gt 0
        }
    }

    It 'rejects a category that does not exist' {
        { Invoke-ChekapAudit -Category Storage } | Should -Throw
    }

    It 'passes everything to the report and returns the results' {
        $result = @(Invoke-ChekapAudit -Language uk -CheckId 'NET-DNS-001' -OutputPath $script:out -Format Html -Note 'Ticket 4711')
        $result.Count | Should -Be 3
        # The audit creates the folder itself, before the report is written.
        Test-Path -LiteralPath $script:out -PathType Container | Should -BeTrue
        Should -Invoke Export-ChekapReport -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $Language -eq 'uk' -and $OutputPath -like '*\reports' -and "$Format" -eq 'Html' -and $Note -eq 'Ticket 4711' -and $SystemInfo.ComputerName -eq 'PC-042' -and @($Result).Count -eq 3
        }
    }

    It 'reports every file path with -Verbose in the chosen language' {
        $messages = Invoke-ChekapAudit -Language uk -CheckId 'NET-DNS-001' -OutputPath $script:out -Verbose 4>&1 |
            Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | ForEach-Object { $_.Message }
        @($messages | Where-Object { $_ -match '[Ѐ-ӿ]' -and $_ -like '*Chekap-PC-042-20260310-1200.html' }).Count | Should -Be 1
    }

    It 'writes nothing and returns nothing when no check matches' {
        $result = @(Invoke-ChekapAudit -Language en -CheckId 'NOPE-999' -OutputPath $script:out -WarningAction SilentlyContinue)
        $result.Count | Should -Be 0
        Test-Path -LiteralPath $script:out | Should -BeFalse
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 0 -Exactly
        Should -Invoke Export-ChekapReport -ModuleName Chekap -Times 0 -Exactly
    }

    It 'creates the output folder before it runs the checks' {
        $probe = @{}
        $folder = $script:out
        Mock Invoke-ChekapCheck { $probe.FolderExisted = Test-Path -LiteralPath $folder -PathType Container; $fixture }.GetNewClosure() -ModuleName Chekap
        $null = Invoke-ChekapAudit -Language en -CheckId 'NET-DNS-001' -OutputPath $script:out
        $probe.FolderExisted | Should -BeTrue
    }

    It 'fails before the checks run when the output folder cannot be created' {
        # A file in the way: a folder cannot be created below it.
        $blocker = Join-Path $TestDrive 'blocker'
        Set-Content -LiteralPath $blocker -Value 'not a folder'
        { Invoke-ChekapAudit -Language en -CheckId 'NET-DNS-001' -OutputPath (Join-Path $blocker 'sub') } | Should -Throw
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 0 -Exactly
        Should -Invoke Export-ChekapReport -ModuleName Chekap -Times 0 -Exactly
    }
}

Describe 'Invoke-ChekapAudit with the real exporter' {
    BeforeEach {
        $fixture = $script:results
        $system = $script:system
        Mock Invoke-ChekapCheck { $fixture }.GetNewClosure() -ModuleName Chekap
        Mock Get-ChekapSystemInfo { $system }.GetNewClosure() -ModuleName Chekap
    }

    It 'writes a relative -OutputPath under the PowerShell location' {
        Push-Location -LiteralPath $TestDrive
        try {
            $null = Invoke-ChekapAudit -Language en -CheckId 'NET-DNS-001' -OutputPath 'rel'
        }
        finally {
            Pop-Location
        }
        @(Get-ChildItem -LiteralPath (Join-Path $TestDrive 'rel') -Filter 'Chekap-PC-042-*').Count | Should -Be 2
    }

    It 'writes both files for the three results' {
        $null = Invoke-ChekapAudit -Language uk -CheckId 'NET-DNS-001' -OutputPath (Join-Path $TestDrive 'audit')
        $json = Get-ChildItem -LiteralPath (Join-Path $TestDrive 'audit') -Filter '*.json'
        (Get-Content -LiteralPath $json.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).language | Should -Be 'uk'
    }
}

BeforeAll {
    $script:psd1 = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'Chekap/Chekap.psd1'
    Import-Module $script:psd1 -Force

    # The real English table, so that the Core.* keys are the shipped ones and only the TST-* keys are fake.
    $script:fakeStrings = InModuleScope Chekap { (Get-ChekapStringTable -Language en).Clone() }
    $script:fakeStrings['TST-001.Title'] = 'T'
    $script:fakeStrings['TST-001.Ok.Details'] = 'D {0}'
    $script:fakeStrings['TST-001.Ok.Recommendation'] = 'R-ok'
    $script:fakeStrings['TST-001.Bad.Details'] = 'Bad {0}'
    $script:fakeStrings['TST-001.Bad.Recommendation'] = 'Fix it'
    $script:fakeStrings['TST-001.Plain.Details'] = 'Plain'
    $script:fakeStrings['TST-002.Title'] = 'T2'
    $script:fakeStrings['TST-002.Ok.Details'] = 'D2'
    $script:fakeStrings['TST-003.Title'] = 'T3'

    # Builds a check hashtable the way a check file returns it.
    $script:newCheck = {
        param([string]$Id, [string]$Category, [scriptblock]$Collect, [scriptblock]$Evaluate, [hashtable]$Extra = @{})
        $check = @{
            Id            = $Id
            Category      = $Category
            RequiresAdmin = $false
            MinBuild      = 0
            References    = @('https://learn.microsoft.com/windows/')
            Settings      = @{}
            Collect       = $Collect
            Evaluate      = $Evaluate
        }
        foreach ($key in $Extra.Keys) { $check[$key] = $Extra[$key] }
        $check
    }
    $script:okCollect = { @{ Free = 5 } }
    $script:okEvaluate = { param($Data) @{ Status = 'OK'; Message = 'Ok'; Args = @($Data.Free) } }
}

AfterAll {
    Remove-Module Chekap -ErrorAction SilentlyContinue
}

Describe 'Invoke-ChekapCheck' {
    BeforeEach {
        $table = $script:fakeStrings
        Mock Get-ChekapStringTable { $table }.GetNewClosure() -ModuleName Chekap
        Mock Get-ChekapOSBuild { 22631 } -ModuleName Chekap
        Mock Test-ChekapAdmin { $true } -ModuleName Chekap
    }

    It 'builds localized result with args' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect $script:okEvaluate
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r.Count | Should -Be 1
            $r[0].Details | Should -Be 'D 5'
            $r[0].Status | Should -Be 'OK'
            $r[0].Title | Should -Be 'T'
            $r[0].Recommendation | Should -Be 'R-ok'
            $r[0].CheckId | Should -Be 'TST-001'
            $r[0].Category | Should -Be 'System'
            $r[0].ComputerName | Should -Be $env:COMPUTERNAME
            $r[0].References | Should -Be 'https://learn.microsoft.com/windows/'
            $r[0].FixId | Should -BeNullOrEmpty
            $r[0].FixRiskLevel | Should -BeNullOrEmpty
            $r[0].PSTypeNames[0] | Should -Be 'Chekap.CheckResult'
        }
    }

    It 'result has the 13 properties in contract order' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect $script:okEvaluate
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            ($r[0].PSObject.Properties.Name -join ',') | Should -Be 'CheckId,Category,ComputerName,Status,Target,Title,Details,Recommendation,FixId,FixRiskLevel,Evidence,References,Timestamp'
            $r[0].Timestamp | Should -BeOfType [datetime]
        }
    }

    It 'passes Settings positionally to Collect and Evaluate' {
        $check = & $script:newCheck 'TST-001' 'System' { param($Settings) @{ Limit = $Settings.Limit } } {
            param($Data, $Settings) @{ Status = 'OK'; Message = 'Ok'; Args = @(($Data.Limit + $Settings.Limit)) }
        } @{ Settings = @{ Limit = 21 } }
        InModuleScope Chekap -Parameters @{ C = $check } {
            @(Invoke-ChekapCheck -Check $C -Language en)[0].Details | Should -Be 'D 42'
        }
    }

    It 'skips admin-only check when not elevated' {
        Mock Test-ChekapAdmin { $false } -ModuleName Chekap
        # Collect throws: it must not even run.
        $check = & $script:newCheck 'TST-001' 'System' { throw 'Collect must not run' } $script:okEvaluate @{ RequiresAdmin = $true }
        InModuleScope Chekap -Parameters @{ C = $check; S = $script:fakeStrings } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r.Count | Should -Be 1
            $r[0].Status | Should -Be 'Skipped'
            $r[0].Title | Should -Be 'T'
            $r[0].Details | Should -Be $S['Core.Skipped.NotAdmin.Details']
            $r[0].Recommendation | Should -Be $S['Core.Skipped.NotAdmin.Recommendation']
        }
    }

    It 'runs admin-only check when elevated' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect $script:okEvaluate @{ RequiresAdmin = $true }
        InModuleScope Chekap -Parameters @{ C = $check } {
            @(Invoke-ChekapCheck -Check $C -Language en)[0].Status | Should -Be 'OK'
        }
    }

    It 'skips check above OS build' {
        $check = & $script:newCheck 'TST-001' 'System' { throw 'Collect must not run' } $script:okEvaluate @{ MinBuild = 99999 }
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r.Count | Should -Be 1
            $r[0].Status | Should -Be 'Skipped'
            $r[0].Details | Should -BeLike '*99999*22631*'
        }
    }

    It 'Collect exception gives Error and other checks still run' {
        $bad = & $script:newCheck 'TST-001' 'System' { throw 'boom disk' } $script:okEvaluate
        $good = & $script:newCheck 'TST-002' 'System' $script:okCollect { @{ Status = 'OK'; Message = 'Ok' } }
        InModuleScope Chekap -Parameters @{ B = $bad; G = $good; S = $script:fakeStrings } {
            $r = @(Invoke-ChekapCheck -Check $B, $G -Language en)
            $r.Count | Should -Be 2
            $r[0].Status | Should -Be 'Error'
            $r[0].CheckId | Should -Be 'TST-001'
            $r[0].Details | Should -BeLike '*boom disk*'
            $r[0].Recommendation | Should -Be $S['Core.Error.Recommendation']
            $r[1].Status | Should -Be 'OK'
            $r[1].CheckId | Should -Be 'TST-002'
        }
    }

    It 'Evaluate exception gives Error' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect { throw 'bad logic' }
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r.Count | Should -Be 1
            $r[0].Status | Should -Be 'Error'
            $r[0].Details | Should -BeLike '*bad logic*'
        }
    }

    It 'a malformed verdict gives one Error and no partial results' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect {
            @{ Status = 'OK'; Message = 'Ok' }
            @{ Status = 'Fine'; Message = 'Ok' }
        }
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r.Count | Should -Be 1
            $r[0].Status | Should -Be 'Error'
        }
    }

    # The checks below are written inside InModuleScope, like a real check file: bound to the module, so they see the runner's preferences.
    It 'a non-terminating error in Collect gives Error, not OK' {
        InModuleScope Chekap -Parameters @{ S = $script:fakeStrings } {
            $ErrorActionPreference = 'Continue' # a normal session; Pester itself runs with Stop, which would hide the bug
            $check = @{
                Id = 'TST-001'; Category = 'System'; RequiresAdmin = $false; MinBuild = 0; References = @(); Settings = @{}
                Collect = { Get-Item -LiteralPath 'C:\Chekap-No-Such-Path'; @{ Free = 5 } }
                Evaluate = { param($Data) @{ Status = 'OK'; Message = 'Ok'; Args = @($Data.Free) } }
            }
            $r = @(Invoke-ChekapCheck -Check $check -Language en 2>$null)
            $r.Count | Should -Be 1
            $r[0].Status | Should -Be 'Error'
            $r[0].Details | Should -BeLike 'Could not collect the data: *'
        }
    }

    It 'a non-terminating error in Evaluate gives Error, not OK' {
        InModuleScope Chekap {
            $ErrorActionPreference = 'Continue' # a normal session; Pester itself runs with Stop, which would hide the bug
            $check = @{
                Id = 'TST-001'; Category = 'System'; RequiresAdmin = $false; MinBuild = 0; References = @(); Settings = @{}
                Collect = { @{ Free = 5 } }
                Evaluate = { Get-Item -LiteralPath 'C:\Chekap-No-Such-Path'; @{ Status = 'OK'; Message = 'Ok'; Args = @(1) } }
            }
            $r = @(Invoke-ChekapCheck -Check $check -Language en 2>$null)
            $r.Count | Should -Be 1
            $r[0].Status | Should -Be 'Error'
            $r[0].Details | Should -BeLike 'Could not evaluate the collected data: *'
        }
    }

    It 'an explicit -ErrorAction SilentlyContinue in a check still wins' {
        InModuleScope Chekap {
            $ErrorActionPreference = 'Continue' # a normal session; Pester itself runs with Stop, which would hide the bug
            $check = @{
                Id = 'TST-001'; Category = 'System'; RequiresAdmin = $false; MinBuild = 0; References = @(); Settings = @{}
                Collect = { Get-Item -LiteralPath 'C:\Chekap-No-Such-Path' -ErrorAction SilentlyContinue; @{ Free = 5 } }
                Evaluate = { param($Data) @{ Status = 'OK'; Message = 'Ok'; Args = @($Data.Free) } }
            }
            $r = @(Invoke-ChekapCheck -Check $check -Language en)
            $r.Count | Should -Be 1
            $r[0].Status | Should -Be 'OK'
        }
    }

    It 'Evaluate that yields no verdict gives one Error' -ForEach @(
        @{ Name = 'nothing'; Evaluate = { } }
        @{ Name = 'only $null'; Evaluate = { $null } }
    ) {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect $Evaluate
        InModuleScope Chekap -Parameters @{ C = $check; S = $script:fakeStrings } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r.Count | Should -Be 1
            $r[0].Status | Should -Be 'Error'
            $r[0].Details | Should -Be $S['Core.Error.NoVerdict.Details']
            $r[0].Details | Should -Not -Be 'Core.Error.NoVerdict.Details'
            $r[0].Recommendation | Should -Be $S['Core.Error.Recommendation']
        }
    }

    It 'prints the exception to the verbose stream when Collect or Evaluate fails' {
        $bad = & $script:newCheck 'TST-001' 'System' { throw 'boom disk' } $script:okEvaluate
        $bad2 = & $script:newCheck 'TST-002' 'System' $script:okCollect { throw 'bad logic' }
        InModuleScope Chekap -Parameters @{ B = $bad; B2 = $bad2 } {
            $verbose = @(Invoke-ChekapCheck -Check $B, $B2 -Language en -Verbose 4>&1 |
                    Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | ForEach-Object { $_.Message })
            @($verbose | Where-Object { $_ -like '*boom disk*' }).Count | Should -Be 1
            @($verbose | Where-Object { $_ -like '*bad logic*' }).Count | Should -Be 1
        }
    }

    It 'Evaluate returning two verdicts gives two results with Targets' {
        $check = & $script:newCheck 'TST-001' 'Printing' $script:okCollect {
            @{ Status = 'Critical'; Message = 'Bad'; Args = @('x'); Target = 'PRN-2F-HP' }
            @{ Status = 'OK'; Message = 'Ok'; Args = @(1); Target = 'PRN-3F' }
        }
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r.Count | Should -Be 2
            $r[0].Target | Should -Be 'PRN-2F-HP'
            $r[0].Status | Should -Be 'Critical'
            $r[0].Details | Should -Be 'Bad x'
            $r[0].Recommendation | Should -Be 'Fix it'
            $r[1].Target | Should -Be 'PRN-3F'
        }
    }

    It 'missing Details key falls back to key name' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect { @{ Status = 'OK'; Message = 'NoSuchKey' } }
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r[0].Details | Should -Be 'TST-001.NoSuchKey.Details'
            $r[0].Recommendation | Should -BeNullOrEmpty
        }
    }

    It 'a verdict that is not OK and has no Recommendation key shows the key name, like a missing Details' -ForEach @('Warning', 'Critical', 'Skipped') {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect ([scriptblock]::Create("@{ Status = '$_'; Message = 'Plain' }"))
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r[0].Details | Should -Be 'Plain'
            $r[0].Recommendation | Should -Be 'TST-001.Plain.Recommendation'
        }
    }

    It 'formats a single falsy argument' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect { @{ Status = 'OK'; Message = 'Ok'; Args = @(0) } }
        InModuleScope Chekap -Parameters @{ C = $check } {
            @(Invoke-ChekapCheck -Check $C -Language en)[0].Details | Should -Be 'D 0'
        }
    }

    It 'Evidence defaults to collected data' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect $script:okEvaluate
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r[0].Evidence.Free | Should -Be 5
        }
    }

    It 'a verdict Evidence wins over the collected data' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect { @{ Status = 'OK'; Message = 'Ok'; Evidence = @{ Only = 1 } } }
        InModuleScope Chekap -Parameters @{ C = $check } {
            $r = @(Invoke-ChekapCheck -Check $C -Language en)
            $r[0].Evidence.Only | Should -Be 1
            $r[0].Evidence.ContainsKey('Free') | Should -BeFalse
        }
    }

    It 'writes a verbose line before each check' {
        $check = & $script:newCheck 'TST-001' 'System' $script:okCollect $script:okEvaluate
        InModuleScope Chekap -Parameters @{ C = $check } {
            $verbose = Invoke-ChekapCheck -Check $C -Language en -Verbose 4>&1 |
                Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | ForEach-Object { $_.Message }
            $verbose | Should -Contain 'Running check TST-001'
        }
    }
}

Describe 'Select-ChekapCheck' {
    BeforeEach {
        $table = $script:fakeStrings
        Mock Get-ChekapStringTable { $table }.GetNewClosure() -ModuleName Chekap
        Mock Resolve-ChekapLanguage { 'en' } -ModuleName Chekap
        $registry = @(
            (& $script:newCheck 'TST-001' 'Network' $script:okCollect $script:okEvaluate)
            (& $script:newCheck 'TST-002' 'Network' $script:okCollect $script:okEvaluate)
            (& $script:newCheck 'TST-003' 'Printing' $script:okCollect $script:okEvaluate)
        )
        $script:savedRegistry = InModuleScope Chekap { , $script:ChekapChecks }
        InModuleScope Chekap -Parameters @{ R = $registry } { $script:ChekapChecks = $R }
    }

    AfterEach {
        InModuleScope Chekap -Parameters @{ R = $script:savedRegistry } { $script:ChekapChecks = $R }
    }

    It 'filters by Category and wildcard CheckId' {
        InModuleScope Chekap {
            @(Select-ChekapCheck).Count | Should -Be 3
            (@(Select-ChekapCheck -Category Network).Id -join ',') | Should -Be 'TST-001,TST-002'
            (@(Select-ChekapCheck -Category Network, Printing).Id -join ',') | Should -Be 'TST-001,TST-002,TST-003'
            (@(Select-ChekapCheck -CheckId 'TST-00[13]').Id -join ',') | Should -Be 'TST-001,TST-003'
            (@(Select-ChekapCheck -CheckId 'TST-*' -Category Printing).Id -join ',') | Should -Be 'TST-003'
            (@(Select-ChekapCheck -CheckId 'TST-002', 'TST-003').Id -join ',') | Should -Be 'TST-002,TST-003'
        }
    }

    It 'warns about an ID that matches nothing and still returns the rest' {
        InModuleScope Chekap {
            $r = @(Select-ChekapCheck -CheckId 'TST-001', 'NOPE-9' -WarningVariable warned -WarningAction SilentlyContinue)
            $r.Count | Should -Be 1
            @($warned).Count | Should -Be 1
            "$($warned[0])" | Should -Be 'There is no check with the ID "NOPE-9".'
        }
    }

    It 'does not warn about an ID that exists in another category' {
        InModuleScope Chekap {
            $r = @(Select-ChekapCheck -CheckId 'TST-003' -Category Network -WarningVariable warned -WarningAction SilentlyContinue)
            $r.Count | Should -Be 0
            @($warned).Count | Should -Be 0
        }
    }
}

Describe 'Import-ChekapCheck' {
    BeforeEach {
        $table = $script:fakeStrings
        Mock Get-ChekapStringTable { $table }.GetNewClosure() -ModuleName Chekap
        Mock Resolve-ChekapLanguage { 'en' } -ModuleName Chekap
        $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $dir 'Network') -Force | Out-Null
    }

    It 'returns an empty array when the folder does not exist' {
        $missing = Join-Path $TestDrive 'no-such-folder'
        InModuleScope Chekap -Parameters @{ P = $missing } {
            @(Import-ChekapCheck -Path $P).Count | Should -Be 0
        }
    }

    It 'loads check files sorted by Id and fills the defaults' {
        Set-Content -LiteralPath (Join-Path $dir 'Network/TST-009.ps1') -Value "@{ Id = 'TST-009'; Category = 'Network'; Collect = { 1 }; Evaluate = { 2 } }"
        Set-Content -LiteralPath (Join-Path $dir 'Network/TST-002.ps1') -Value "@{ Id = 'TST-002'; Category = 'Network'; RequiresAdmin = `$true; MinBuild = 17763; References = @('https://example.com/'); Settings = @{ A = 1 }; Collect = { 1 }; Evaluate = { 2 } }"
        InModuleScope Chekap -Parameters @{ P = $dir } {
            $checks = @(Import-ChekapCheck -Path $P)
            $checks.Count | Should -Be 2
            ($checks.Id -join ',') | Should -Be 'TST-002,TST-009'
            $checks[0] | Should -BeOfType [hashtable]
            $checks[0].RequiresAdmin | Should -BeTrue
            $checks[0].MinBuild | Should -Be 17763
            $checks[0].Settings.A | Should -Be 1
            $checks[1].RequiresAdmin | Should -BeFalse
            $checks[1].MinBuild | Should -Be 0
            $checks[1].Settings | Should -BeOfType [hashtable]
            $checks[1].Settings.Count | Should -Be 0
            $checks[1].Collect | Should -BeOfType [scriptblock]
        }
    }

    It 'throws with the file name for a file that is not a check' -ForEach @(
        @{ Name = 'text.ps1'; Body = "'just text'" }
        @{ Name = 'nocollect.ps1'; Body = "@{ Id = 'TST-001'; Category = 'Network'; Evaluate = { 2 } }" }
        @{ Name = 'badtype.ps1'; Body = "@{ Id = 'TST-001'; Category = 'Network'; Collect = 'x'; Evaluate = { 2 } }" }
        @{ Name = 'throws.ps1'; Body = "throw 'broken on load'" }
    ) {
        Set-Content -LiteralPath (Join-Path $dir "Network/$Name") -Value $Body
        InModuleScope Chekap -Parameters @{ P = $dir; Name = $Name } {
            { Import-ChekapCheck -Path $P } | Should -Throw -ExpectedMessage "*$Name*"
        }
    }
}

Describe 'Get-ChekapCheck' {
    BeforeEach {
        $table = $script:fakeStrings
        Mock Get-ChekapStringTable { $table }.GetNewClosure() -ModuleName Chekap
        $registry = @(
            (& $script:newCheck 'TST-001' 'Network' $script:okCollect $script:okEvaluate @{ RequiresAdmin = $true; MinBuild = 17763 })
            (& $script:newCheck 'TST-003' 'Printing' $script:okCollect $script:okEvaluate)
        )
        $script:savedRegistry = InModuleScope Chekap { , $script:ChekapChecks }
        InModuleScope Chekap -Parameters @{ R = $registry } { $script:ChekapChecks = $R }
    }

    AfterEach {
        InModuleScope Chekap -Parameters @{ R = $script:savedRegistry } { $script:ChekapChecks = $R }
    }

    It 'lists checks as Chekap.CheckInfo with localized Title' {
        $info = @(Get-ChekapCheck -Language en)
        $info.Count | Should -Be 2
        $info[0].PSObject.TypeNames[0] | Should -Be 'Chekap.CheckInfo'
        ($info[0].PSObject.Properties.Name -join ',') | Should -Be 'Id,Category,Title,RequiresAdmin,MinBuild,References'
        $info[0].Id | Should -Be 'TST-001'
        $info[0].Title | Should -Be 'T'
        $info[0].RequiresAdmin | Should -BeTrue
        $info[0].MinBuild | Should -Be 17763
        $info[0].References | Should -Be 'https://learn.microsoft.com/windows/'
    }

    It 'filters by Category' {
        $info = @(Get-ChekapCheck -Category Printing -Language en)
        $info.Count | Should -Be 1
        $info[0].Id | Should -Be 'TST-003'
    }

    It 'refuses a category that does not exist, as Invoke-ChekapAudit does' {
        { Get-ChekapCheck -Category 'Printin' -Language en } | Should -Throw '*Printin*'
        { Get-ChekapCheck -Category 'System', 'Bogus' -Language en } | Should -Throw
        { Get-ChekapCheck -Category 'System', 'Printing' -Language en } | Should -Not -Throw
    }
}

Describe 'Loading the module from a folder with [brackets] in its path' {
    BeforeAll {
        # A copy of the module next to nothing else, loaded by a fresh process of the same engine as this test run.
        $script:bracketHome = Join-Path $TestDrive 'Chekap [x]'
        Copy-Item -LiteralPath (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'Chekap') -Destination $script:bracketHome -Recurse
        $script:engine = (Get-Process -Id $PID).Path
        $script:runChild = {
            param([string]$Command)
            $env:CHEKAP_TEST_PSD1 = Join-Path $script:bracketHome 'Chekap.psd1'
            # Encoded: the quotes inside a -Command text do not survive the command line of Windows PowerShell 5.1.
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Command))
            try { @(& $script:engine -NoProfile -EncodedCommand $encoded 2>&1) -join "`n" }
            finally { Remove-Item -Path Env:\CHEKAP_TEST_PSD1 -ErrorAction SilentlyContinue }
        }
    }

    It 'imports, reads the string tables and runs a check' {
        $output = & $script:runChild 'Import-Module $env:CHEKAP_TEST_PSD1 -ErrorAction Stop; Test-ChekapHealth -Language en -CheckId SYS-UPTIME-001 | ForEach-Object { "$($_.Status)|$($_.Title)" }'
        $output | Should -Match '^(OK|Warning)\|Uptime$'
    }

    It 'still stops with the message in the Constrained Language Mode guard' {
        $output = & $script:runChild '$ExecutionContext.SessionState.LanguageMode = "ConstrainedLanguage"; try { Import-Module $env:CHEKAP_TEST_PSD1 -ErrorAction Stop } catch { $_.Exception.Message }'
        $output | Should -Match 'Constrained Language Mode'
    }
}

Describe 'Test-ChekapAdmin and Get-ChekapOSBuild' {
    It 'return a bool and a Windows build number' {
        InModuleScope Chekap {
            Test-ChekapAdmin | Should -BeOfType [bool]
            Get-ChekapOSBuild | Should -BeOfType [int]
            Get-ChekapOSBuild | Should -BeGreaterThan 10000
        }
    }
}

Describe 'Chekap.format.ps1xml' {
    It 'registers table views for both result types' {
        Get-FormatData -TypeName 'Chekap.CheckResult' | Should -Not -BeNullOrEmpty
        Get-FormatData -TypeName 'Chekap.CheckInfo' | Should -Not -BeNullOrEmpty
    }

    It 'shows Status, CheckId, Target, Title for a result' {
        $computer = 'PC-042'
        $result = InModuleScope Chekap -Parameters @{ Computer = $computer } {
            New-ChekapResult -Check @{ Id = 'TST-001'; Category = 'System'; References = @() } -Status Warning -Title 'My title' `
                -Details 'd' -Target 'D:' -ComputerName $Computer
        }
        $text = $result | Format-Table | Out-String -Width 200
        $text | Should -Match 'Status\s+CheckId\s+Target\s+Title'
        $text | Should -Match 'Warning\s+TST-001\s+D:\s+My title'
    }
}

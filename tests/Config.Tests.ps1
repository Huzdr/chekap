BeforeAll {
    $script:psd1 = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'Chekap/Chekap.psd1'
    Import-Module $script:psd1 -Force
}

AfterAll {
    Remove-Module Chekap -ErrorAction SilentlyContinue
}

Describe 'Get-ChekapConfig / Set-ChekapConfig' {
    BeforeEach {
        # A fresh, not yet existing sub-folder per test, so that Set-ChekapConfig has to create it.
        $cfg = Join-Path $TestDrive "$([guid]::NewGuid())/config.json"
        Mock Get-ChekapConfigPath { $cfg }.GetNewClosure() -ModuleName Chekap
    }

    It 'returns Language $null when there is no file' {
        (Get-ChekapConfig).Language | Should -BeNullOrEmpty
    }

    It 'returns an object typed Chekap.Config' {
        (Get-ChekapConfig).PSObject.TypeNames[0] | Should -Be 'Chekap.Config'
    }

    It 'round-trips Language and creates the folder' {
        Set-ChekapConfig -Language uk
        (Get-ChekapConfig).Language | Should -Be 'uk'
        Set-ChekapConfig -Language en
        (Get-ChekapConfig).Language | Should -Be 'en'
    }

    It 'writes UTF-8 JSON without BOM' {
        Set-ChekapConfig -Language uk
        $bytes = [System.IO.File]::ReadAllBytes($cfg)
        $bytes[0] | Should -Be ([byte][char]'{')
        ([System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json).Language | Should -Be 'uk'
    }

    It '-WhatIf writes nothing' {
        Set-ChekapConfig -Language en -WhatIf
        Test-Path $cfg | Should -BeFalse
    }

    It 'reports the saved path in the chosen language' {
        $messages = Set-ChekapConfig -Language uk -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | ForEach-Object { $_.Message }
        # The Ukrainian text, not the bare key; the other verbose line is PowerShell's own ShouldProcess message.
        @($messages | Where-Object { $_ -match '[Ѐ-ӿ]' }) | Should -BeLike "*$cfg"
    }

    It 'a corrupt file returns defaults without throwing' {
        New-Item -ItemType Directory -Path (Split-Path $cfg) -Force | Out-Null
        Set-Content -LiteralPath $cfg -Value '{oops'
        { Get-ChekapConfig } | Should -Not -Throw
        (Get-ChekapConfig).Language | Should -BeNullOrEmpty
    }

    It 'an unknown Language value in the file is ignored' {
        New-Item -ItemType Directory -Path (Split-Path $cfg) -Force | Out-Null
        Set-Content -LiteralPath $cfg -Value '{"Language":"xx"}'
        (Get-ChekapConfig).Language | Should -BeNullOrEmpty
    }
}

Describe 'Resolve-ChekapLanguage' {
    It 'resolves: param > config > UI culture' -ForEach @(
        @{ P = 'en'; C = 'uk'; Ui = 'uk-UA'; E = 'en' }
        @{ P = $null; C = 'uk'; Ui = 'en-US'; E = 'uk' }
        @{ P = $null; C = $null; Ui = 'uk-UA'; E = 'uk' }
        @{ P = $null; C = $null; Ui = 'ru-RU'; E = 'en' }
    ) {
        $cfg = Join-Path $TestDrive "$([guid]::NewGuid())/config.json"
        $ui = $Ui
        Mock Get-ChekapConfigPath { $cfg }.GetNewClosure() -ModuleName Chekap
        Mock Get-ChekapUICulture { $ui }.GetNewClosure() -ModuleName Chekap
        if ($C) { Set-ChekapConfig -Language $C }
        # $P is passed through even when $null: callers forward their own optional -Language.
        InModuleScope Chekap -Parameters @{ P = $P; E = $E } {
            Resolve-ChekapLanguage -Language $P | Should -Be $E
        }
    }
}

Describe 'Get-ChekapStringTable' {
    AfterEach {
        # Never leave a fake table behind for the other tests.
        InModuleScope Chekap { $script:ChekapStringCache = @{} }
    }

    It 'returns the table of the requested language' {
        InModuleScope Chekap {
            $uk = Get-ChekapStringTable -Language uk
            $en = Get-ChekapStringTable -Language en
            $uk['Category.Network'] | Should -Match '[Ѐ-ӿ]'
            $en['Category.Network'] | Should -Be 'Network'
            # Asking again, in the other order, must not hand back the wrong language.
            (Get-ChekapStringTable -Language en)['Category.Network'] | Should -Be 'Network'
            (Get-ChekapStringTable -Language uk)['Category.Network'] | Should -Match '[Ѐ-ӿ]'
        }
    }

    It 'loads each table once' {
        InModuleScope Chekap {
            $script:ChekapStringCache = @{}
            Mock Import-LocalizedData { @{ 'A.Key' = 'x' } }
            $null = Get-ChekapStringTable -Language en
            $null = Get-ChekapStringTable -Language en
            Should -Invoke Import-LocalizedData -Times 1 -Exactly
        }
    }
}

Describe 'Get-ChekapText' {
    BeforeAll {
        $script:strings = @{ 'A.Fmt' = 'X {0} and {1}'; 'A.Plain' = 'Plain {0}' }
    }

    It 'formats the arguments' {
        InModuleScope Chekap -Parameters @{ S = $script:strings } {
            Get-ChekapText -Strings $S -Key 'A.Fmt' -FormatArgs 5, 'z' | Should -Be 'X 5 and z'
        }
    }

    It 'does not format when there are no arguments' {
        InModuleScope Chekap -Parameters @{ S = $script:strings } {
            Get-ChekapText -Strings $S -Key 'A.Plain' | Should -Be 'Plain {0}'
        }
    }

    It 'returns the key itself when it is missing' {
        InModuleScope Chekap -Parameters @{ S = $script:strings } {
            Get-ChekapText -Strings $S -Key 'No.Such.Key' | Should -Be 'No.Such.Key'
        }
    }

    It 'returns $null for a missing key with -Optional' {
        InModuleScope Chekap -Parameters @{ S = $script:strings } {
            Get-ChekapText -Strings $S -Key 'No.Such.Key' -Optional | Should -BeNullOrEmpty
        }
    }
}

Describe 'Constrained Language guard' {
    It 'refuses to load with a localized message' {
        $exe = (Get-Process -Id $PID).Path
        # Single quotes only: double quotes inside a native argument get mangled by Windows PowerShell 5.1.
        $command = "`$ExecutionContext.SessionState.LanguageMode = 'ConstrainedLanguage'; " +
            "try { Import-Module '$($script:psd1)' -ErrorAction Stop; 'LOADED' } catch { `$_.Exception.Message }"
        $out = (& $exe -NoProfile -Command $command) | Out-String
        $out | Should -Not -BeLike '*LOADED*'
        $out | Should -Not -BeLike '*Core.ConstrainedLanguage*'
        $out | Should -BeLike '*FullLanguage*'
    }
}

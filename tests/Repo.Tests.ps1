BeforeAll {
    $script:root = Split-Path -Path $PSScriptRoot -Parent
    $script:manifest = Join-Path $script:root 'Chekap/Chekap.psd1'
    # Scripts under the repo, excluding .git and out.
    $script:scripts = Get-ChildItem -Path $script:root -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
        Where-Object { $_.FullName.Substring($script:root.Length) -notmatch '[\\/](\.git|out)[\\/]' }
}

Describe 'Repository hygiene' {
    It 'every ps1/psm1/psd1 starts with UTF-8 BOM' {
        $noBom = $script:scripts | Where-Object {
            $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
            -not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        } | ForEach-Object { $_.FullName }
        $noBom | Should -BeNullOrEmpty
    }

    It 'module code contains no Cyrillic (no hardcoded UI text)' {
        $hits = $script:scripts | Where-Object { $_.Extension -in '.ps1', '.psm1' -and $_.FullName.StartsWith((Join-Path $script:root 'Chekap')) } |
            Select-String -Pattern '[Ѐ-ӿ]' -Encoding UTF8
        $hits | Should -BeNullOrEmpty
    }

    It 'manifest is valid' {
        { Test-ModuleManifest -Path $script:manifest -ErrorAction Stop } | Should -Not -Throw
    }

    It 'FunctionsToExport equals Public/*.ps1 basenames' {
        $exported = @((Import-PowerShellDataFile -Path $script:manifest).FunctionsToExport | Sort-Object)
        $publicFiles = @(Get-ChildItem -Path (Join-Path $script:root 'Chekap/Public') -Filter '*.ps1' -ErrorAction SilentlyContinue |
                ForEach-Object { $_.BaseName } | Sort-Object)
        $exported | Should -Be $publicFiles
    }
}

Describe 'Localization tables' {
    BeforeAll {
        $script:en = Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/en-US/Chekap.strings.psd1')
        $script:uk = Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/uk-UA/Chekap.strings.psd1')
    }

    It 'en-US and uk-UA have the same keys' {
        $diff = Compare-Object -ReferenceObject @($script:en.Keys) -DifferenceObject @($script:uk.Keys) |
            ForEach-Object { '{0} only in {1}' -f $_.InputObject, $(if ($_.SideIndicator -eq '<=') { 'en-US' } else { 'uk-UA' }) }
        $diff | Should -BeNullOrEmpty
    }

    It 'format placeholders {n}, {n:format} and {n,align} match per key' {
        $placeholders = { param($text) @([regex]::Matches([string]$text, '\{(\d+)(?:[,:][^}]*)?\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ',' }
        $bad = $script:en.Keys | Where-Object { $script:uk.ContainsKey($_) -and (& $placeholders $script:en[$_]) -ne (& $placeholders $script:uk[$_]) }
        $bad | Should -BeNullOrEmpty
    }
}

BeforeDiscovery {
    $checksDir = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'Chekap/Checks'
    # One case per check file. A check file only builds a hashtable, so running it here is safe.
    # No check files yet is fine: git keeps no empty folders, and the loop just yields no cases.
    $script:checkCases = @(Get-ChildItem -Path $checksDir -Filter '*.ps1' -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object { @{ Name = $_.BaseName; Folder = $_.Directory.Name; Check = (& $_.FullName) } })
}

Describe 'Check file <Name>' -ForEach $script:checkCases {
    BeforeAll {
        $script:en = Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/en-US/Chekap.strings.psd1')
        $script:uk = Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/uk-UA/Chekap.strings.psd1')
        $script:allowedCommands = 'ForEach-Object', 'Where-Object', 'Sort-Object', 'Select-Object', 'Measure-Object', 'Group-Object'
        $ast = $Check.Evaluate.Ast

        # A verdict is any hashtable literal in Evaluate with a Message key. Its Message and Status must be string literals.
        $script:verdicts = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $true) | ForEach-Object {
                $pairs = @{}
                foreach ($pair in $_.KeyValuePairs) {
                    if ($pair.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $pairs[$pair.Item1.Value] = $pair.Item2 }
                }
                if ($pairs.ContainsKey('Message')) {
                    $literal = {
                        param($statement)
                        $expression = if ($statement -is [System.Management.Automation.Language.PipelineBaseAst]) { $statement.GetPureExpression() }
                        if ($expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $expression.Value }
                    }
                    @{ Message = (& $literal $pairs['Message']); Status = $(if ($pairs.ContainsKey('Status')) { & $literal $pairs['Status'] }) }
                }
            })
        $script:commandNames = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object {
                $commandName = $_.GetCommandName()
                if ($commandName) { $commandName } else { '<dynamic command>' }
            })
    }

    It 'Id equals file name' {
        $Check.Id | Should -Be $Name
    }

    It 'Category equals folder' {
        $Check.Category | Should -Be $Folder
    }

    It 'has https References' {
        @($Check.References).Count | Should -BeGreaterThan 0
        @($Check.References | Where-Object { $_ -notlike 'https://*' }) | Should -BeNullOrEmpty
    }

    It 'has Title key in both languages' {
        $script:en.ContainsKey("$Name.Title") | Should -BeTrue
        $script:uk.ContainsKey("$Name.Title") | Should -BeTrue
    }

    It 'every Message literal in Evaluate has Details in both languages' {
        $script:verdicts.Count | Should -BeGreaterThan 0
        $missing = foreach ($verdict in $script:verdicts) {
            if (-not $verdict.Message) { 'a Message that is not a string literal'; continue }
            foreach ($table in @{ 'en-US' = $script:en; 'uk-UA' = $script:uk }.GetEnumerator()) {
                if (-not $table.Value.ContainsKey("$Name.$($verdict.Message).Details")) { "$Name.$($verdict.Message).Details missing in $($table.Key)" }
            }
        }
        $missing | Should -BeNullOrEmpty
    }

    It 'non-OK verdicts have Recommendation in both languages' {
        $missing = foreach ($verdict in $script:verdicts) {
            if ($verdict.Status -notin 'OK', 'Warning', 'Critical', 'Skipped') { "Message '$($verdict.Message)' has a Status that is not a literal OK/Warning/Critical/Skipped"; continue }
            if ($verdict.Status -eq 'OK') { continue }
            foreach ($table in @{ 'en-US' = $script:en; 'uk-UA' = $script:uk }.GetEnumerator()) {
                if (-not $table.Value.ContainsKey("$Name.$($verdict.Message).Recommendation")) { "$Name.$($verdict.Message).Recommendation missing in $($table.Key)" }
            }
        }
        $missing | Should -BeNullOrEmpty
    }

    It 'Evaluate calls only allowed commands' {
        @($script:commandNames | Where-Object { $_ -notin $script:allowedCommands }) | Should -BeNullOrEmpty
    }
}

BeforeDiscovery {
    $publicDir = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'Chekap/Public'
    $script:helpCases = @(Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | ForEach-Object { @{ Command = $_.BaseName } })
    $script:helpLanguages = @(@{ Lang = 'en' }, @{ Lang = 'uk' })
}

Describe 'Command help' {
    BeforeAll {
        Import-Module (Join-Path $script:root 'Chekap/Chekap.psd1') -Force
    }

    AfterAll {
        Remove-Module Chekap -ErrorAction SilentlyContinue
    }

    Context '<Command>' -ForEach $script:helpCases {
        BeforeAll {
            $script:pagePath = { param($lang) Join-Path $script:root "docs/$lang/$Command.md" }
            $script:readPage = { param($lang) Get-Content -LiteralPath (& $script:pagePath $lang) -Raw -Encoding UTF8 -ErrorAction Stop }
            $script:synopsis = { param($lang) [regex]::Match((& $script:readPage $lang), '(?ms)^## SYNOPSIS\r?\n(.*?)^## ').Groups[1].Value }
        }

        It 'has a docs/<Lang> page' -ForEach $script:helpLanguages {
            Test-Path -LiteralPath (& $script:pagePath $Lang) -PathType Leaf | Should -BeTrue
        }

        It 'docs/<Lang> page has no platyPS placeholder left' -ForEach $script:helpLanguages {
            (& $script:readPage $Lang) | Should -Not -Match '\{\{.*?\}\}'
        }

        It 'docs/<Lang> parameter headings equal the real parameters of the command' -ForEach $script:helpLanguages {
            $documented = @([regex]::Matches((& $script:readPage $Lang), '(?m)^### -(\w+)\s*$') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
            $real = @((Get-Command -Name $Command).Parameters.Keys | Where-Object { $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters } | Sort-Object)
            # Joined: an empty list piped to Should would be $null, and a command without parameters has none.
            ($documented -join ',') | Should -Be ($real -join ',')
        }

        It 'the function body starts with the ExternalHelp line' {
            $source = Get-Content -LiteralPath (Join-Path $script:root "Chekap/Public/$Command.ps1") -Raw -Encoding UTF8
            $source | Should -Match '^function [\w-]+ \{\r?\n[ \t]*# \.ExternalHelp Chekap-help\.xml\r?\n'
        }

        It 'docs/uk SYNOPSIS is translated' {
            (& $script:synopsis 'uk') | Should -Match '[Ѐ-ӿ]'
        }

        It 'docs/en page has no Cyrillic' {
            (& $script:readPage 'en') | Should -Not -Match '[Ѐ-ӿ]'
        }
    }
}

Describe 'Start-Chekap.cmd launcher' {
    BeforeAll {
        $script:cmdPath = Join-Path $script:root 'Start-Chekap.cmd'
        $script:cmdBytes = [System.IO.File]::ReadAllBytes($script:cmdPath)
        $script:cmdText = [System.Text.Encoding]::ASCII.GetString($script:cmdBytes)
    }

    It 'is plain ASCII' {
        @($script:cmdBytes | Where-Object { $_ -ge 0x80 }) | Should -BeNullOrEmpty
    }

    It 'has no BOM: it would break @echo off' {
        $script:cmdBytes[0] | Should -Be ([byte][char]'@')
        $script:cmdText | Should -Match '^@echo off\r\n'
    }

    It 'uses CRLF line endings only' {
        [regex]::Matches($script:cmdText, '(?<!\r)\n').Count | Should -Be 0
        [regex]::Matches($script:cmdText, '\r(?!\n)').Count | Should -Be 0
    }

    It 'tests for administrator rights with fltmc, which does not depend on the Server service' {
        $script:cmdText | Should -Match '(?m)^fltmc >nul 2>&1\r$'
        $script:cmdText | Should -Not -Match 'net session'
    }

    It 'asks for elevation once: it passes the elevated marker and skips the request when it has it' {
        $script:cmdText | Should -Match '(?m)^if "%~1"=="elevated" goto menu\r$'
        $script:cmdText | Should -Match "-ArgumentList 'elevated' -Verb RunAs"
        # The marker test comes first, otherwise a copy that already has the marker could ask again.
        $script:cmdText.IndexOf('if "%~1"=="elevated"') | Should -BeLessThan $script:cmdText.IndexOf('-Verb RunAs')
        $script:cmdText | Should -Match '(?m)^:menu\r$'
    }

    It 'hands its own paths to PowerShell through environment variables, not inside a quoted string' {
        # A path with an apostrophe (Дем'ян, U+2019) would end a PowerShell single-quoted string early.
        $script:cmdText | Should -Not -Match "'%~"
        $script:cmdText | Should -Match '(?m)^setlocal\r$'
        $script:cmdText | Should -Match '(?m)^set "CHEKAP_SELF=%~f0"\r$'
        $script:cmdText | Should -Match '(?m)^set "CHEKAP_HOME=%~dp0"\r$'
        $script:cmdText | Should -Match ([regex]::Escape('-FilePath $env:CHEKAP_SELF -ArgumentList'))
        # Both are set before the elevated marker is tested: the elevated copy needs them too.
        $guard = $script:cmdText.IndexOf('if "%~1"=="elevated"')
        $script:cmdText.IndexOf('set "CHEKAP_SELF=') | Should -BeLessThan $guard
        $script:cmdText.IndexOf('set "CHEKAP_HOME=') | Should -BeLessThan $guard
    }

    It 'imports the module that sits next to it and starts the menu' {
        $script:cmdText | Should -Match ([regex]::Escape("-Command ""Import-Module (Join-Path `$env:CHEKAP_HOME 'Chekap\Chekap.psd1'); Start-Chekap"""))
        Test-Path -LiteralPath (Join-Path $script:root 'Chekap/Chekap.psd1') | Should -BeTrue
    }

    It 'closes the window when the menu ends and pauses only after a failure' {
        $script:cmdText | Should -Not -Match '-NoExit'
        $lines = @($script:cmdText -split '\r\n' | Where-Object { $_ })
        $lines[-2] | Should -BeLike '*Start-Chekap"'
        $lines[-1] | Should -Be 'if errorlevel 1 pause'
    }

    It 'is left alone by tools/Add-Bom.ps1' {
        $copy = Join-Path $TestDrive 'launcher'
        $null = New-Item -ItemType Directory -Path $copy
        Copy-Item -LiteralPath $script:cmdPath -Destination $copy
        & (Join-Path $script:root 'tools/Add-Bom.ps1') -Path $copy
        [System.IO.File]::ReadAllBytes((Join-Path $copy 'Start-Chekap.cmd')) | Should -Be $script:cmdBytes
    }
}

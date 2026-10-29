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

        It 'docs/<Lang> Accept wildcard characters equals SupportsWildcards of each parameter' -ForEach $script:helpLanguages {
            $text = & $script:readPage $Lang
            $mismatch = foreach ($parameter in (Get-Command -Name $Command).Parameters.Values) {
                if ($parameter.Name -in [System.Management.Automation.PSCmdlet]::CommonParameters) { continue }
                $block = [regex]::Match($text, "(?ms)^### -$($parameter.Name)\s*\r?\n((?:(?!^### ).)*)").Groups[1].Value
                $documented = [regex]::Match($block, '(?m)^Accept wildcard characters: (\w+)').Groups[1].Value
                $real = [bool]($parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.SupportsWildcardsAttribute] })
                if ($documented -ne [string]$real) { "-$($parameter.Name): page says '$documented', the code says $real" }
            }
            $mismatch | Should -BeNullOrEmpty
        }

        It 'docs/uk has as many examples as docs/en' {
            $examples = { param($lang) [regex]::Matches([regex]::Match((& $script:readPage $lang), '(?ms)^## EXAMPLES\r?\n(.*?)^## PARAMETERS').Groups[1].Value, '(?m)^### ').Count }
            (& $examples 'en') | Should -BeGreaterThan 0
            (& $examples 'uk') | Should -Be (& $examples 'en')
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

Describe 'GitHub workflows' {
    BeforeAll {
        $script:workflowFiles = @('ci.yml', 'release.yml') | ForEach-Object { Join-Path $script:root ".github/workflows/$_" }
    }

    It 'ci.yml and release.yml exist' {
        @($script:workflowFiles | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }) | Should -BeNullOrEmpty
    }

    It 'are UTF-8 without a BOM' {
        $bom = $script:workflowFiles | Where-Object {
            $bytes = [System.IO.File]::ReadAllBytes($_)
            $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        }
        $bom | Should -BeNullOrEmpty
    }

    It 'use one line-ending style and no tabs' {
        $bad = $script:workflowFiles | Where-Object {
            $text = [System.IO.File]::ReadAllText($_)
            $mixed = [regex]::Matches($text, '\r\n').Count -gt 0 -and [regex]::Matches($text, '(?<!\r)\n').Count -gt 0
            $mixed -or $text.Contains("`t")
        }
        $bad | Should -BeNullOrEmpty
    }

    It 'use only the GitHub-owned actions at their current major' {
        $used = @(foreach ($file in $script:workflowFiles) {
                foreach ($match in [regex]::Matches([System.IO.File]::ReadAllText($file), '(?m)^\s*(?:-\s+)?uses:\s*(\S+)')) { $match.Groups[1].Value }
            })
        $used | Should -Contain 'actions/checkout@v7'
        @($used | Where-Object { $_ -cnotin 'actions/checkout@v7', 'actions/upload-artifact@v7' }) | Should -BeNullOrEmpty
    }

    It 'grant only the contents permission each needs and cap every job at 20 minutes' {
        $permission = @{ 'ci.yml' = 'read'; 'release.yml' = 'write' }
        $bad = foreach ($name in $permission.Keys) {
            $text = [System.IO.File]::ReadAllText((Join-Path $script:root ".github/workflows/$name"))
            if ($text -cnotmatch "(?m)^permissions:\r?\n  contents: $($permission[$name])\r?\n(?!  )") { "$name permissions" }
            if ($text -cnotmatch '(?m)^    timeout-minutes: 20\r?$') { "$name timeout-minutes" }
        }
        $bad | Should -BeNullOrEmpty
    }
}

BeforeDiscovery {
    $script:readmeCases = @(
        @{ Lang = 'en'; File = 'README.md' }
        @{ Lang = 'uk'; File = 'README.uk.md' }
    )
    $script:formNames = @('bug', 'check-idea', 'translation')
}

Describe 'Documentation and community files' {
    BeforeAll {
        $script:markdown = @('README.md', 'README.uk.md', 'CONTRIBUTING.md', 'CONTRIBUTING.uk.md', 'CODE_OF_CONDUCT.md', 'SECURITY.md', 'CHANGELOG.md', 'docs/glossary.md', '.github/pull_request_template.md')
        $script:forms = @('bug.yml', 'check-idea.yml', 'translation.yml', 'config.yml') | ForEach-Object { ".github/ISSUE_TEMPLATE/$_" }
        $script:readText = { param($relative) [System.IO.File]::ReadAllText((Join-Path $script:root $relative), [System.Text.Encoding]::UTF8) }
    }

    It 'every document, issue form and screenshot exists' {
        $needed = @($script:markdown) + @($script:forms) + @('docs/images/report-uk.png', 'docs/images/report-en.png')
        @($needed | Where-Object { -not (Test-Path -LiteralPath (Join-Path $script:root $_) -PathType Leaf) }) | Should -BeNullOrEmpty
    }

    It 'documents and issue forms are UTF-8 without a BOM' {
        $bom = @($script:markdown) + @($script:forms) | Where-Object {
            $path = Join-Path $script:root $_
            (Test-Path -LiteralPath $path) -and ((([System.IO.File]::ReadAllBytes($path) | Select-Object -First 3) -join ',') -eq '239,187,191')
        }
        $bom | Should -BeNullOrEmpty
    }

    It 'relative links in the documents point to files that exist' {
        $broken = foreach ($relative in $script:markdown) {
            $path = Join-Path $script:root $relative
            if (-not (Test-Path -LiteralPath $path)) { continue }
            $folder = Split-Path -Path $path -Parent
            foreach ($match in [regex]::Matches((& $script:readText $relative), '\]\(([^)\s]+)\)')) {
                $target = $match.Groups[1].Value
                if ($target -match '^(https?:|mailto:|#)') { continue }
                $file = ($target -split '#')[0]
                if (-not (Test-Path -LiteralPath (Join-Path $folder $file))) { "$relative -> $target" }
            }
        }
        $broken | Should -BeNullOrEmpty
    }

    It 'no file of the repository names the PC or the domain the tests run on' {
        # Real names must not leak into docs, fixtures or demo data. Generic words (a user called Admin) are not checked here.
        $names = @($env:COMPUTERNAME, $env:USERDOMAIN) | Where-Object { $_ -and $_.Length -ge 4 } | Select-Object -Unique
        $files = Get-ChildItem -Path $script:root -Recurse -File -Force |
            Where-Object { $_.FullName.Substring($script:root.Length) -notmatch '[\\/](\.git|out|\.superpowers)[\\/]' -and $_.Extension -in '.md', '.yml', '.ps1', '.psm1', '.psd1', '.html', '.json', '.cmd' }
        $hits = foreach ($name in $names) {
            $files | Select-String -Pattern ('(?<![\w-])' + [regex]::Escape($name) + '(?![\w-])') -Encoding UTF8 | ForEach-Object { $_.Path }
        }
        $hits | Should -BeNullOrEmpty
    }

    It 'both screenshots are PNG files 1280 pixels wide and under 500 KB' {
        $bad = foreach ($name in 'report-uk.png', 'report-en.png') {
            $path = Join-Path $script:root "docs/images/$name"
            if (-not (Test-Path -LiteralPath $path)) { "$name is missing"; continue }
            $bytes = [System.IO.File]::ReadAllBytes($path)
            if (($bytes[0..7] -join ',') -ne '137,80,78,71,13,10,26,10') { "$name is not a PNG file"; continue }
            $width = $bytes[16] * 16777216 + $bytes[17] * 65536 + $bytes[18] * 256 + $bytes[19]
            if ($width -ne 1280) { "$name is $width pixels wide" }
            if ($bytes.Length -gt 500KB) { "$name is $($bytes.Length) bytes" }
        }
        $bad | Should -BeNullOrEmpty
    }

    It 'both CONTRIBUTING files show the real SYS-UPTIME-001 file as the template' {
        $check = [System.IO.File]::ReadAllText((Join-Path $script:root 'Chekap/Checks/System/SYS-UPTIME-001.ps1'), [System.Text.Encoding]::UTF8).Replace("`r`n", "`n").TrimEnd()
        foreach ($file in 'CONTRIBUTING.md', 'CONTRIBUTING.uk.md') {
            (& $script:readText $file).Replace("`r`n", "`n").Contains($check) | Should -BeTrue -Because "$file must show the current SYS-UPTIME-001.ps1"
        }
    }
    It 'README.md and README.uk.md have the same sections' {
        $count = { param($file) @([regex]::Matches((& $script:readText $file), '(?m)^## ')).Count }
        (& $count 'README.uk.md') | Should -BeGreaterThan 5
        (& $count 'README.uk.md') | Should -Be (& $count 'README.md')
    }

    It 'CONTRIBUTING.md and CONTRIBUTING.uk.md have the same sections' {
        $count = { param($file) @([regex]::Matches((& $script:readText $file), '(?m)^## ')).Count }
        (& $count 'CONTRIBUTING.uk.md') | Should -BeGreaterThan 3
        (& $count 'CONTRIBUTING.uk.md') | Should -Be (& $count 'CONTRIBUTING.md')
    }

    It 'the English documents have Cyrillic only in the link to the Ukrainian version' {
        $lines = foreach ($file in 'README.md', 'CONTRIBUTING.md') {
            foreach ($line in ((& $script:readText $file) -split '\r?\n')) { if ($line -match '[Ѐ-ӿ]') { "${file}: $line" } }
        }
        @($lines).Count | Should -BeLessOrEqual 2
    }

    It 'every section heading of the Ukrainian documents is in Ukrainian' {
        $english = foreach ($file in 'README.uk.md', 'CONTRIBUTING.uk.md') {
            foreach ($line in ((& $script:readText $file) -split '\r?\n')) { if ($line -match '^##? ' -and $line -notmatch '[Ѐ-ӿ]' -and $line -notmatch '^# Chekap\s*$') { "${file}: $line" } }
        }
        $english | Should -BeNullOrEmpty
    }

    It 'the glossary has at least 20 terms and every Ukrainian term is used in the Ukrainian strings or help' {
        $text = & $script:readText 'docs/glossary.md'
        $rows = @([regex]::Matches($text, '(?m)^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|[^\r\n]*\|\s*$') | Where-Object { $_.Groups[1].Value -notmatch '^(-+|English)$' -and $_.Groups[2].Value -notmatch '^-+$' })
        $rows.Count | Should -BeGreaterOrEqual 20
        # The values of the table, not its source: in the source an apostrophe is doubled.
        $corpus = @((Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/uk-UA/Chekap.strings.psd1')).Values) -join "`n"
        foreach ($page in Get-ChildItem -Path (Join-Path $script:root 'docs/uk') -Filter '*.md') { $corpus += [System.IO.File]::ReadAllText($page.FullName, [System.Text.Encoding]::UTF8) }
        $unused = foreach ($row in $rows) {
            $term = $row.Groups[2].Value
            if ($corpus.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { $term }
        }
        $unused | Should -BeNullOrEmpty
    }
}

Describe 'CHANGELOG' {
    It 'has an Unreleased section and a section for the version of the manifest, and the release notes step can read it' {
        $text = [System.IO.File]::ReadAllText((Join-Path $script:root 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
        $text | Should -Match '(?m)^## \[Unreleased\]'
        $version = (Import-PowerShellDataFile -Path $script:manifest).ModuleVersion
        $notes = & (Join-Path $script:root 'tools/Get-ChangelogNotes.ps1') -Version $version
        $notes | Should -Not -BeNullOrEmpty
        $text | Should -Match ('(?m)^\[' + [regex]::Escape($version) + '\]: https://github\.com/Huzdr/chekap/')
        $text | Should -Match '(?m)^\[Unreleased\]: https://github\.com/Huzdr/chekap/'
    }
}

Describe 'README check tables' {
    BeforeAll {
        # -Check only compares: nothing is written.
        $script:tables = @(& (Join-Path $script:root 'tools/Update-ReadmeChecks.ps1') -Check)
        $script:checkIds = @(Get-ChildItem -Path (Join-Path $script:root 'Chekap/Checks') -Filter '*.ps1' -Recurse -File | ForEach-Object { $_.BaseName })
    }

    Context '<File>' -ForEach $script:readmeCases {
        It 'has exactly one checks block' {
            $text = [System.IO.File]::ReadAllText((Join-Path $script:root $File), [System.Text.Encoding]::UTF8)
            [regex]::Matches($text, '<!-- checks:start -->').Count | Should -Be 1
            [regex]::Matches($text, '<!-- checks:end -->').Count | Should -Be 1
        }

        It 'lists every check Id' {
            $text = [System.IO.File]::ReadAllText((Join-Path $script:root $File), [System.Text.Encoding]::UTF8)
            $script:checkIds.Count | Should -BeGreaterThan 0
            @($script:checkIds | Where-Object { $text -notmatch [regex]::Escape($_) }) | Should -BeNullOrEmpty
        }

        It 'has the table that the generator would write now' {
            $table = @($script:tables | Where-Object { $_.Language -eq $Lang })
            $table.Count | Should -Be 1
            $table[0].Current | Should -Not -BeNullOrEmpty
            $table[0].Current | Should -BeExactly $table[0].Expected
        }
    }
}

Describe 'Issue forms and pull request template' {
    BeforeAll {
        $script:formText = { param($name) [System.IO.File]::ReadAllText((Join-Path $script:root ".github/ISSUE_TEMPLATE/$name"), [System.Text.Encoding]::UTF8) }
    }

    Context '<_>.yml' -ForEach $script:formNames {
        It 'is an issue form with a name, a description, the label and a body, without tabs' {
            $text = & $script:formText "$_.yml"
            $text | Should -Match '(?m)^name: \S'
            $text | Should -Match '(?m)^description: \S'
            $text | Should -Match ('(?m)^labels:\s*\r?\n\s+- ' + [regex]::Escape($_) + '\s*$')
            $text | Should -Match '(?m)^body:'
            $text | Should -Not -Match "`t"
        }

        It 'has unique ids made of lowercase letters, digits, - and _' {
            $ids = @([regex]::Matches((& $script:formText "$_.yml"), '(?m)^\s+id: (.*?)\s*$') | ForEach-Object { $_.Groups[1].Value })
            $ids.Count | Should -BeGreaterThan 0
            @($ids | Where-Object { $_ -cnotmatch '^[a-z0-9_-]+$' }) | Should -BeNullOrEmpty
            @($ids | Select-Object -Unique).Count | Should -Be $ids.Count
        }
    }

    It 'the bug form has a required confirmation that real names were replaced' {
        $text = & $script:formText 'bug.yml'
        $text | Should -Match '(?m)^\s+(?:- )?type: checkboxes'
        $text | Should -Match '(?ms)- label: [^\r\n]*\r?\n\s+required: true'
    }

    It 'blank issues are off and the contact link goes to private security advisories' {
        $text = & $script:formText 'config.yml'
        $text | Should -Match '(?m)^blank_issues_enabled: false\s*$'
        $text | Should -Match 'url: https://github\.com/Huzdr/chekap/security/advisories/new'
    }
}

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

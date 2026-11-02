BeforeAll {
    $script:tool = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'tools/Get-ChangelogNotes.ps1'
}

Describe 'Get-ChangelogNotes' {
    BeforeAll {
        # Versions that contain 0.1.0 as a prefix come first: a loose match would stop at one of them.
        $text = @'
# Changelog

All notable changes are documented here.

## [Unreleased]

### Added
- Not released yet.

## [0.1.1] - 2026-11-05

### Fixed
- A fix.

## [0.1.01] - 2026-11-04

- Not 0.1.0.

## [0.1.0-beta] - 2026-11-03

- Beta notes.

## [0.1.0] - 2026-11-01

### Added
- Console menu.
- Звіти українською.

### Fixed
- Printer check no longer hangs.

## [0.0.9] - 2026-10-01

## [0.0.8] - 2026-09-01

- Last real section.

[Unreleased]: https://example.invalid/compare/v0.1.1...HEAD
[0.1.1]: https://example.invalid/compare/v0.1.0...v0.1.1
[0.0.8]: https://example.invalid/releases/tag/v0.0.8
'@
        # CRLF and no BOM, like the file after a checkout on Windows (.gitattributes: eol=crlf).
        $noBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        $script:changelog = Join-Path $TestDrive 'CHANGELOG.md'
        [System.IO.File]::WriteAllText($script:changelog, ($text -replace "`r?`n", "`r`n"), $noBom)

        $script:onlyLinks = Join-Path $TestDrive 'only-links.md'
        [System.IO.File]::WriteAllText($script:onlyLinks, "## [0.2.0] - 2026-12-01`r`n`r`n[0.2.0]: https://example.invalid/releases/tag/v0.2.0`r`n", $noBom)
    }

    It 'returns the text of a section: from after its heading to the next ## heading, ### headings kept' {
        $expected = "### Added`n- Console menu.`n- Звіти українською.`n`n### Fixed`n- Printer check no longer hangs."
        & $script:tool -Version '0.1.0' -Path $script:changelog | Should -BeExactly $expected
    }

    It 'stops the last section before the link reference lines' {
        & $script:tool -Version '0.0.8' -Path $script:changelog | Should -BeExactly '- Last real section.'
    }

    It 'matches the whole version: 0.1.0 is not a prefix of 0.1.01 or 0.1.0-beta' {
        & $script:tool -Version '0.1.01' -Path $script:changelog | Should -BeExactly '- Not 0.1.0.'
        & $script:tool -Version '0.1.0-beta' -Path $script:changelog | Should -BeExactly '- Beta notes.'
        { & $script:tool -Version '0.1' -Path $script:changelog } | Should -Throw -ExpectedMessage '*No section*0.1*'
    }

    It 'throws when the version has no section' {
        { & $script:tool -Version '0.2.0' -Path $script:changelog } | Should -Throw -ExpectedMessage '*No section*0.2.0*'
    }

    It 'throws when the section is empty' {
        { & $script:tool -Version '0.0.9' -Path $script:changelog } | Should -Throw -ExpectedMessage '*0.0.9*is empty*'
        { & $script:tool -Version '0.2.0' -Path $script:onlyLinks } | Should -Throw -ExpectedMessage '*0.2.0*is empty*'
    }
}

Describe 'Update-ReadmeChecks' {
    BeforeAll {
        $script:tool = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'tools/Update-ReadmeChecks.ps1'
        $script:utf8 = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        $script:checkCount = @(Get-ChildItem -Path (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'Chekap/Checks') -Filter '*.ps1' -Recurse -File).Count

        # A fresh pair of READMEs with a stale table, CRLF like a checkout on Windows, and text around the block that must survive.
        $script:newWork = {
            param($name)
            $folder = Join-Path $TestDrive $name
            $null = New-Item -ItemType Directory -Path $folder
            foreach ($file in 'README.md', 'README.uk.md') {
                $text = "# Intro`r`n`r`nBefore the table.`r`n`r`n<!-- checks:start -->`r`n| old | table |`r`n<!-- checks:end -->`r`n`r`nAfter the table: Привіт.`r`n"
                [System.IO.File]::WriteAllText((Join-Path $folder $file), $text, $script:utf8)
            }
            $folder
        }
        $script:read = { param($folder, $file) [System.IO.File]::ReadAllText((Join-Path $folder $file), [System.Text.Encoding]::UTF8) }
    }

    It 'rewrites only what is between the markers, keeps CRLF and adds no BOM' {
        $folder = & $script:newWork 'rewrite'
        $null = & $script:tool -Path $folder
        foreach ($file in 'README.md', 'README.uk.md') {
            $text = & $script:read $folder $file
            $text | Should -Match '^# Intro\r\n\r\nBefore the table\.\r\n\r\n<!-- checks:start -->\r\n\| '
            $text | Should -Match '\|\r\n<!-- checks:end -->\r\n\r\nAfter the table: Привіт\.\r\n$'
            $text | Should -Not -Match '\| old \|'
            [regex]::Matches($text, '(?<!\r)\n').Count | Should -Be 0
            [System.IO.File]::ReadAllBytes((Join-Path $folder $file))[0] | Should -Be ([byte][char]'#')
            [regex]::Matches($text, '(?m)^\| `[A-Z]{3}-[A-Z]+-\d{3}` \|').Count | Should -Be $script:checkCount
        }
    }

    It 'writes the headings, categories and the Admin column in the language of the README' {
        $folder = & $script:newWork 'languages'
        $null = & $script:tool -Path $folder
        (& $script:read $folder 'README.md') | Should -Match '\| Id \| Category \| What it checks \| Admin \|'
        (& $script:read $folder 'README.md') | Should -Match '\| `PRN-SPOOLER-001` \| Printing \| Print Spooler service \| no \|'
        (& $script:read $folder 'README.uk.md') | Should -Match '\| Id \| Категорія \| Що перевіряє \| Адмін \|'
        (& $script:read $folder 'README.uk.md') | Should -Match '\| `PRN-SPOOLER-001` \| Друк \| Служба Print Spooler \| ні \|'
    }

    It 'a second run changes nothing' {
        $folder = & $script:newWork 'twice'
        $null = & $script:tool -Path $folder
        $first = foreach ($file in 'README.md', 'README.uk.md') { (Get-FileHash -LiteralPath (Join-Path $folder $file)).Hash }
        $second = @(& $script:tool -Path $folder)
        $after = foreach ($file in 'README.md', 'README.uk.md') { (Get-FileHash -LiteralPath (Join-Path $folder $file)).Hash }
        $after | Should -Be $first
        @($second | Where-Object { -not $_.UpToDate }) | Should -BeNullOrEmpty
    }

    It '-Check reports a stale table and writes nothing' {
        $folder = & $script:newWork 'check'
        $before = foreach ($file in 'README.md', 'README.uk.md') { (Get-FileHash -LiteralPath (Join-Path $folder $file)).Hash }
        $result = @(& $script:tool -Path $folder -Check)
        $result.Count | Should -Be 2
        @($result | Where-Object UpToDate) | Should -BeNullOrEmpty
        $result[0].Expected | Should -Not -Be $result[0].Current
        $after = foreach ($file in 'README.md', 'README.uk.md') { (Get-FileHash -LiteralPath (Join-Path $folder $file)).Hash }
        $after | Should -Be $before
    }

    It 'stops with an error when a README has no markers' {
        $folder = & $script:newWork 'nomarkers'
        [System.IO.File]::WriteAllText((Join-Path $folder 'README.md'), "# Intro`r`n", $script:utf8)
        { & $script:tool -Path $folder } | Should -Throw
    }
}

Describe 'New-DemoReport' {
    BeforeAll {
        $script:repo = Split-Path -Path $PSScriptRoot -Parent
        $script:demoOut = Join-Path $TestDrive 'demo'
        $null = & (Join-Path $script:repo 'tools/New-DemoReport.ps1') -OutputPath $script:demoOut
        $script:reports = @{}
        foreach ($language in 'uk', 'en') {
            $json = @(Get-ChildItem -Path (Join-Path $script:demoOut $language) -Filter '*.json' -ErrorAction SilentlyContinue)
            $script:reports[$language] = if ($json.Count -eq 1) { [System.IO.File]::ReadAllText($json[0].FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
        }
        $script:allText = (Get-ChildItem -Path $script:demoOut -Recurse -File | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8) }) -join "`n"
    }

    It 'writes one HTML and one JSON report for each language into its own folder' {
        foreach ($language in 'uk', 'en') {
            @(Get-ChildItem -Path (Join-Path $script:demoOut $language) -Filter '*.html').Count | Should -Be 1
            @(Get-ChildItem -Path (Join-Path $script:demoOut $language) -Filter '*.json').Count | Should -Be 1
            $script:reports[$language].language | Should -Be $language
        }
    }

    It 'has two or three findings of each status in each language' {
        foreach ($language in 'uk', 'en') {
            $count = @{}
            foreach ($group in ($script:reports[$language].results | Group-Object -Property Status)) { $count[$group.Name] = $group.Count }
            foreach ($status in 'OK', 'Warning', 'Critical', 'Error', 'Skipped') {
                $count[$status] | Should -BeGreaterOrEqual 2
                $count[$status] | Should -BeLessOrEqual 3
            }
        }
    }

    It 'both languages hold the same findings' {
        $list = { param($language) @($script:reports[$language].results | ForEach-Object { '{0}|{1}|{2}' -f $_.CheckId, $_.Status, $_.Target }) }
        (& $list 'uk') | Should -Be (& $list 'en')
    }

    It 'shows the fake PC everywhere and nothing of this PC' {
        foreach ($language in 'uk', 'en') {
            $script:reports[$language].computer | Should -Be 'PC-042'
            $script:reports[$language].system.ComputerName | Should -Be 'PC-042'
            @($script:reports[$language].results | Where-Object { $_.ComputerName -ne 'PC-042' }) | Should -BeNullOrEmpty
        }
        # Only a name with a digit: a PC called DESKTOP or SERVER would match ordinary words.
        foreach ($name in @($env:COMPUTERNAME | Where-Object { $_ -match '\d' -and $_ -ne 'PC-042' })) {
            $script:allText | Should -Not -Match ('(?i)(?<![\w-])' + [regex]::Escape($name) + '(?![\w-])')
        }
    }

    It 'uses only documentation IP addresses (192.0.2.x)' {
        $other = @([regex]::Matches($script:allText, '(?<![\d.])\d{1,3}(?:\.\d{1,3}){3}(?![\d.])') | ForEach-Object { $_.Value } | Where-Object { $_ -notlike '192.0.2.*' } | Select-Object -Unique)
        $other | Should -BeNullOrEmpty
    }

    It 'the texts are the real localized strings: no key is left in place of a sentence' {
        foreach ($language in 'uk', 'en') {
            $keys = @($script:reports[$language].results | ForEach-Object { $_.Title; $_.Details; $_.Recommendation } | Where-Object { $_ -and $_ -match '^[A-Z]{3}-[A-Z]+-\d{3}\.|^Core\.' })
            $keys | Should -BeNullOrEmpty
        }
        $script:reports['uk'].results[0].Details | Should -Match '[Ѐ-ӿ]'
        ($script:reports['en'].results | ForEach-Object { $_.Title }) -join ' ' | Should -Not -Match '[Ѐ-ӿ]'
    }
}

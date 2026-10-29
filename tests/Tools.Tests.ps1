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

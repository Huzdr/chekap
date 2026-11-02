# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-02

First release. It only diagnoses: nothing is changed on the PC.

### Added

- 26 read-only checks in three categories: System (10), Network (9) and Printing (7). Every finding has a status, a description, a recommendation and links to the documentation it is based on.
- Findings and reports in Ukrainian and in English, from the same checks. The language is taken from `-Language`, then from the setting saved by `Set-ChekapConfig`, then from the language of Windows.
- Commands: `Test-ChekapHealth`, `Test-ChekapNetwork`, `Test-ChekapPrinting`, `Invoke-ChekapAudit`, `Get-ChekapCheck`, `Get-ChekapConfig`, `Set-ChekapConfig` and `Start-Chekap`.
- `Invoke-ChekapAudit -OutputPath` writes a report as one HTML file and as JSON. The HTML report works offline, shows the passport of the PC, counters, filters by status and category, a light and a dark theme and a layout for printing.
- `Start-Chekap`, a console menu, and `Start-Chekap.cmd`, which starts it by a double click from the offline package (it runs as the signed-in user and does not ask for administrator rights).
- Help for every command in English and in Ukrainian.
- Detection of Constrained Language Mode (AppLocker, WDAC): the module explains why it cannot work there.
- Documentation in two languages: README, CONTRIBUTING and a glossary; issue forms and a pull request template.
- Build and CI: `build.ps1` (Bootstrap, Lint, Test, Build, Smoke), tests on Windows PowerShell 5.1 and PowerShell 7, and a release workflow that builds the package and creates a GitHub release.

[Unreleased]: https://github.com/Huzdr/chekap/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Huzdr/chekap/releases/tag/v0.1.0

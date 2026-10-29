# Contributing to Chekap

English | [Українська](CONTRIBUTING.uk.md)

Thank you for helping. Chekap is made for sysadmins of small and medium Windows networks, and most of its checks come from problems that someone met at work. If you met one, you can add the check for it, and it takes about ten minutes.

## Ways to help

- **A bug or a wrong finding.** Open an issue with the bug form. It asks you to replace real computer names, IP addresses and user names before you paste any output.
- **An idea for a check.** Describe the problem and how you recognize it on a PC in the check idea form. You do not need to write the code.
- **A translation or a wording fix.** Use the translation form, or open a pull request that changes the string tables. Ukrainian texts must read as plain, correct Ukrainian written by a sysadmin. See [Wording and translations](#wording-and-translations).
- **A new check.** Follow the next sections.

## Set up

You need Windows, Git and PowerShell. Clone the repository and install the development modules (Pester 5, PSScriptAnalyzer, platyPS 0.14.2) for your user; this needs the internet once:

```powershell
git clone https://github.com/Huzdr/chekap.git
cd chekap
./build.ps1 -Task Bootstrap
```

Chekap itself has no runtime dependencies. These modules are for development only.

## A check in 10 minutes

A check is one file. The core is not touched. The file returns a hashtable with two script blocks: `Collect` reads data from the PC and `Evaluate` turns that data into a verdict. A third part, the texts, lives in the string tables.

### 1. Choose the Id and create the file

The file is `Chekap/Checks/<Category>/<Id>.ps1`. The Id has the form `CAT-NAME-001` and is never translated or reused. The `Id` inside the file must equal the file name and `Category` must equal the folder name (`System`, `Network` or `Printing` in version 0.1); the tests check both. A new category needs more changes (a `Category.<Name>` string, the `-Category` list of `Invoke-ChekapAudit`, usually a new `Test-Chekap<Name>` command), so ask in an issue first.

Start from this real check. Copy it and change it:

```powershell
@{
    Id            = 'SYS-UPTIME-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-operatingsystem'
        'https://learn.microsoft.com/troubleshoot/windows-client/setup-upgrade-and-drivers/updates-not-install-with-fast-startup'
    )
    Settings      = @{ WarnDays = 14 }
    Collect       = {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $power = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -ErrorAction SilentlyContinue
        @{
            LastBoot    = [datetime]$os.LastBootUpTime
            Now         = Get-Date
            FastStartup = ($null -ne $power -and $power.HiberbootEnabled -eq 1)
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        $totalDays = ($Data.Now - $Data.LastBoot).TotalDays
        $days = [int][math]::Floor($totalDays)
        if ($totalDays -lt $Settings.WarnDays) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($days) }
        }
        elseif ($Data.FastStartup) {
            @{ Status = 'Warning'; Message = 'LongFastStartup'; Args = @($days) }
        }
        else {
            @{ Status = 'Warning'; Message = 'Long'; Args = @($days) }
        }
    }
}
```

### 2. The rules a check follows

- **`Collect` returns only plain data:** strings, numbers, booleans, `[datetime]`, arrays and hashtables. Turn an enum into a `[string]`. Never return a CIM object.
- **`Collect` does not parse localized output.** Read CIM, the registry or `Get-WinEvent -FilterHashtable` (use `Properties[n]`, not the message text). Native tools (`w32tm`, `powercfg`) are called by their bare name, so Pester can mock them, and only their numeric or XML output is read.
- **Network access only through the helpers that have a timeout:** `Test-ChekapPing`, `Test-ChekapTcpPort`, `Test-ChekapDnsServer` in `Chekap/Private/Collect/`.
- **`Evaluate` is pure:** no system calls. It may use only `ForEach-Object`, `Where-Object`, `Sort-Object`, `Select-Object`, `Measure-Object` and `Group-Object`.
- **Every verdict is a hashtable literal** with a literal `Status` (`OK`, `Warning`, `Critical` or `Skipped`) and a literal `Message`. Optional keys: `Args` (values for `{0}`, `{1}` in the text), `Target` (the object the finding is about, such as `D:` or a printer name) and `Evidence` (the data to show; without it the whole `Collect` result is shown). `Evaluate` may return several verdicts, for example one for each printer. `Error` is not a verdict: it is what the core reports when a block throws.
- **A block declares only the parameters it uses:** `param($Settings)` in `Collect`, `param($Data)` or `param($Data, $Settings)` in `Evaluate`.
- **Thresholds go to `Settings`**, not into the code of `Evaluate`.
- **`References` has at least one `https://` link** to the Microsoft documentation or another authoritative source.
- **Syntax of Windows PowerShell 5.1 only:** no `??`, `?:`, `?.`, `&&`, `||` and no `ForEach-Object -Parallel`. No `Invoke-Expression`, no `Win32_Product`, no other modules.
- **A check only reads.** Anything that changes the PC does not belong in version 0.1.
- **Fake data only**, in the code, the tests and the issues: `PC-042`, `contoso.local`, `192.0.2.x`, `PRN-2F-HP`.

### 3. Add the texts to both string tables

The texts are never in the code. Add the keys to `Chekap/en-US/Chekap.strings.psd1` and to `Chekap/uk-UA/Chekap.strings.psd1` at once, with the same `{n}` placeholders in both:

| Key | Text |
|---|---|
| `<Id>.Title` | The name of the check |
| `<Id>.<Message>.Details` | What was found, for every `Message` of the check |
| `<Id>.<Message>.Recommendation` | What to do. Required for every `Message` that is not `OK` |

For the check above:

```powershell
'SYS-UPTIME-001.Title' = 'Uptime'
'SYS-UPTIME-001.Long.Details' = 'The PC has not been restarted for {0} days.'
'SYS-UPTIME-001.Long.Recommendation' = 'Restart the PC to apply pending updates and to free memory held by programs that have been running for a long time.'
```

A single quote inside a text is doubled (`''`). Describe the problem first, then say what to do, in short sentences.

### 4. Add a test

Tests are table-driven: one row for every `Message`, in `tests/Checks/<Category>.Tests.ps1`. The row gives the `Collect` data that you invent and the verdict you expect:

```powershell
@{ Id = 'SYS-UPTIME-001'; Name = 'long uptime is Long'; Data = @{ LastBoot = (& $daysAgo 20); Now = $now; FastStartup = $false }; Expect = @(@{ Status = 'Warning'; Message = 'Long'; Args = @(20) }) }
```

`Collect` gets its own test in the same file with the system calls mocked (`Mock Get-CimInstance ...`), because the tests never touch the real system. The test of the category also counts its checks, so update that number.

### 5. Encoding

All `.ps1`, `.psm1` and `.psd1` files are UTF-8 **with a BOM**; without it Windows PowerShell 5.1 breaks Cyrillic. After you create files run:

```powershell
./tools/Add-Bom.ps1
```

Markdown and YAML files have no BOM. `.editorconfig` sets UTF-8, CRLF line endings and four spaces.

### 6. Run the build

From a PowerShell prompt in the repository folder:

```powershell
./build.ps1                                          # Lint and Test, the default
./build.ps1 -Task Lint                               # PSScriptAnalyzer only; it must report nothing
./build.ps1 -Task Test -TestPath tests/Checks/System.Tests.ps1
```

Run one task per call, as the CI does. With `powershell -File build.ps1` a comma list such as `-Task Lint,Test` arrives as one string; use one task per call or `-Command`. The tests must pass on Windows PowerShell 5.1 and on PowerShell 7, so run both:

```powershell
powershell -NoProfile -File build.ps1
pwsh -NoProfile -File build.ps1
```

### 7. Update the table and the changelog

The table of checks in both READMEs is generated from the checks. Regenerate it, or a test fails:

```powershell
./tools/Update-ReadmeChecks.ps1
```

Add one line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md), for example `- Check SYS-UPTIME-001 ...`.

## Changing a command or its help

The help is the markdown in `docs/en/` and `docs/uk/` (platyPS format); the code has no comment-based help. After you change the parameters of a public command, update the page of the command in both folders: `Update-MarkdownHelp -Path docs/en` does the structure, then edit the texts in English and write the Ukrainian page by hand. The tests compare the documented parameters with the real ones. The release build turns the pages into the help of the module.

## Wording and translations

[docs/glossary.md](docs/glossary.md) lists the words used in both languages (check, finding, recommendation, spooler, gateway and others). Use them, and add a word there when you introduce a new one. Ukrainian: short, plain sentences, no word-for-word translation from English, and the names of Windows windows and buttons as they are in the Ukrainian Windows. The tests check that both string tables have the same keys and the same `{n}` placeholders; they cannot check that the text is good, so read it aloud.

## Commits and pull requests

- Small commits with [Conventional Commits](https://www.conventionalcommits.org/) messages: `feat:`, `fix:`, `docs:`, `i18n:`, `test:`, `ci:`, `chore:`.
- One change in one pull request. Fill in the checklist of the template.
- The CI must be green on Windows PowerShell 5.1 and on PowerShell 7.
- Before you push, look at your diff for real computer names, IP addresses and user names.

## Rules that always apply

- **Safe by default.** Checks only read. Changes to a PC will come later, with `-WhatIf`, a backup and a rollback.
- **No runtime dependencies, no telemetry, no code from the network.** The module must work in an isolated network.
- **No text for the user in the code.** Only string keys.
- **A check that cannot run is `Skipped` with an explanation, not an error.** For example, no battery or a stopped spooler.

By contributing you agree that your contribution is under the [MIT license](LICENSE) and that you follow the [Code of Conduct](CODE_OF_CONDUCT.md).

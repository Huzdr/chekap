[CmdletBinding()]
param(
    # Version to extract, as written in the heading: 0.1.0 for "## [0.1.0] - 2026-11-01".
    [Parameter(Mandatory)]
    [string]$Version,

    # Keep a Changelog file; defaults to CHANGELOG.md in the repository root.
    [string]$Path
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty in a param() default on Windows PowerShell 5.1, so resolve it here.
if (-not $Path) { $Path = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'CHANGELOG.md' }

# ReadAllLines splits CRLF and LF alike and skips a BOM; Get-Content would read UTF-8 as ANSI on 5.1.
$lines = [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).ProviderPath, [System.Text.Encoding]::UTF8)

# The closing bracket is what keeps 0.1.0 from matching 0.1.01 or 0.1.0-beta.
$heading = '^## \[' + [regex]::Escape($Version) + '\]'
$section = New-Object -TypeName 'System.Collections.Generic.List[string]'
$inSection = $false
$endedByHeading = $false
foreach ($line in $lines) {
    if ($line -cmatch '^## ') {
        if ($inSection) { $endedByHeading = $true; break }
        $inSection = $line -cmatch $heading
        continue
    }
    if ($inSection) { $section.Add($line) }
}
if (-not $inSection) { throw "No section for version $Version in $Path." }

# Link reference lines ([0.1.0]: https://...) close the file, so only the last section has them to drop.
$trailing = if ($endedByHeading) { '^\s*$' } else { '^\s*$|^\[[^\]]+\]:\s' }
while ($section.Count -gt 0 -and $section[$section.Count - 1] -match $trailing) { $section.RemoveAt($section.Count - 1) }
while ($section.Count -gt 0 -and $section[0] -match '^\s*$') { $section.RemoveAt(0) }
if ($section.Count -eq 0) { throw "The section for version $Version in $Path is empty." }

$section -join "`n"

[CmdletBinding()]
param(
    # Folder with README.md and README.uk.md; defaults to the repository root.
    [string]$Path,

    # Compare only: write nothing, and return the current and the expected table of each README.
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty in a param() default on Windows PowerShell 5.1, so resolve it here.
$root = Split-Path -Path $PSScriptRoot -Parent
if (-not $Path) { $Path = $root }
$Path = (Resolve-Path -LiteralPath $Path).ProviderPath

$readmes = @(
    @{ File = 'README.md'; Language = 'en'; Culture = 'en-US'; Header = @('Id', 'Category', 'What it checks', 'Admin'); Yes = 'yes'; No = 'no' }
    @{ File = 'README.uk.md'; Language = 'uk'; Culture = 'uk-UA'; Header = @('Id', 'Категорія', 'Що перевіряє', 'Адмін'); Yes = 'так'; No = 'ні' }
)
$utf8 = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
$start = '<!-- checks:start -->'
$end = '<!-- checks:end -->'

# Import the module from this repository, whatever copy of Chekap the session already has.
$null = Import-Module -Name (Join-Path $root 'Chekap/Chekap.psd1') -Force
try {
    # Both READMEs are prepared first and written after that: a problem in the second one must not leave the first one changed.
    $plans = foreach ($readme in $readmes) {
        $file = Join-Path $Path $readme.File
        $text = [System.IO.File]::ReadAllText($file, $utf8)
        $first = $text.IndexOf($start, [System.StringComparison]::Ordinal)
        $last = $text.IndexOf($end, [System.StringComparison]::Ordinal)
        if ($first -lt 0 -or $last -lt $first -or
            $text.IndexOf($start, $first + 1, [System.StringComparison]::Ordinal) -ge 0 -or
            $text.IndexOf($end, $last + 1, [System.StringComparison]::Ordinal) -ge 0) {
            throw "$file must have exactly one $start line followed by one $end line."
        }

        # Category names come from the same string table the reports use.
        $strings = Import-PowerShellDataFile -Path (Join-Path $root "Chekap/$($readme.Culture)/Chekap.strings.psd1")
        $checks = @{}
        foreach ($info in @(Get-ChekapCheck -Language $readme.Language)) { $checks[$info.Id] = $info }
        # Ordinal order: the same table on every engine and in every Windows culture.
        $ids = [string[]]@($checks.Keys)
        [System.Array]::Sort($ids, [System.StringComparer]::Ordinal)

        $lines = New-Object -TypeName 'System.Collections.Generic.List[string]'
        $lines.Add('| ' + ($readme.Header -join ' | ') + ' |')
        $lines.Add('|---|---|---|---|')
        foreach ($id in $ids) {
            $item = $checks[$id]
            $label = "Category.$($item.Category)"
            # An empty cell in a README would pass unnoticed, so a missing label stops the run.
            if (-not $strings.ContainsKey($label)) { throw "$($readme.Culture) has no string $label, needed for the check $id." }
            $admin = if ($item.RequiresAdmin) { $readme.Yes } else { $readme.No }
            $lines.Add(('| `{0}` | {1} | {2} | {3} |' -f $item.Id, $strings[$label], $item.Title.Replace('|', '\|'), $admin))
        }
        $expected = $lines -join "`n"

        $begin = $first + $start.Length
        $current = $text.Substring($begin, $last - $begin).Replace("`r`n", "`n").Trim("`n")
        $content = $null
        if ($current -cne $expected) {
            # The file keeps its own line ending: CRLF after a checkout on Windows, LF elsewhere.
            $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
            $content = $text.Substring(0, $begin) + $newline + $expected.Replace("`n", $newline) + $newline + $text.Substring($last)
        }
        @{ File = $file; Language = $readme.Language; Current = $current; Expected = $expected; Content = $content }
    }

    foreach ($plan in $plans) {
        $updated = $false
        if ($plan.Content -and -not $Check) {
            [System.IO.File]::WriteAllText($plan.File, $plan.Content, $utf8)
            $updated = $true
            Write-Verbose "Table updated: $($plan.File)"
        }
        # UpToDate says that the table is right when the command ends: true after a successful write as well.
        $result = [ordered]@{ Path = $plan.File; Language = $plan.Language; UpToDate = ($updated -or -not $plan.Content); Updated = $updated }
        if ($Check) {
            $result['Current'] = $plan.Current
            $result['Expected'] = $plan.Expected
        }
        [pscustomobject]$result
    }
}
finally {
    Remove-Module -Name Chekap -ErrorAction SilentlyContinue
}

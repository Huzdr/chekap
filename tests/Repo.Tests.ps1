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

    It 'format placeholders {n} match per key' {
        $placeholders = { param($text) @([regex]::Matches([string]$text, '\{(\d+)\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ',' }
        $bad = $script:en.Keys | Where-Object { $script:uk.ContainsKey($_) -and (& $placeholders $script:en[$_]) -ne (& $placeholders $script:uk[$_]) }
        $bad | Should -BeNullOrEmpty
    }
}

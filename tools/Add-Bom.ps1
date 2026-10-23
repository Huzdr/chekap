[CmdletBinding()]
param(
    # Folder to scan recursively; defaults to the repository root.
    [string]$Path
)

# $PSScriptRoot is empty in a param() default on Windows PowerShell 5.1, so resolve it here.
if (-not $Path) { $Path = Split-Path -Path $PSScriptRoot -Parent }
$bom = [byte[]](0xEF, 0xBB, 0xBF)
$root = (Resolve-Path -Path $Path).ProviderPath.TrimEnd('\', '/')
$files = Get-ChildItem -Path $root -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
    Where-Object { $_.FullName.Substring($root.Length) -notmatch '[\\/](\.git|out)[\\/]' }

foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { continue }
    [System.IO.File]::WriteAllBytes($file.FullName, $bom + $bytes)
    Write-Verbose "BOM added: $($file.FullName)"
}

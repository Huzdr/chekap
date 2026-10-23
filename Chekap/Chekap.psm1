$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue) +
    @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private/Collect') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

foreach ($file in $private + $public) {
    . $file.FullName
}

Export-ModuleMember -Function @($public | ForEach-Object { $_.BaseName })

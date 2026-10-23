# Constrained Language Mode (AppLocker, WDAC) breaks the module, so stop with a clear message first.
# Only the system UI language is used here: the config helpers are not loaded yet.
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    $clmCulture = if ($PSUICulture -like 'uk*') { 'uk-UA' } else { 'en-US' }
    $clmStrings = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName 'Chekap.strings.psd1' -UICulture $clmCulture -ErrorAction Stop
    throw $clmStrings['Core.ConstrainedLanguage']
}

$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue) +
    @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private/Collect') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

foreach ($file in $private + $public) {
    . $file.FullName
}

# The check registry is read once. A check file that is not valid stops the import with a localized message.
$script:ChekapChecks = @(Import-ChekapCheck -Path (Join-Path $PSScriptRoot 'Checks'))

Export-ModuleMember -Function @($public | ForEach-Object { $_.BaseName })

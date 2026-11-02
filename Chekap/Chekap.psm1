# Constrained Language Mode (AppLocker, WDAC) breaks the module, so stop with a clear message first.
# Only the system UI language is used here: the config helpers are not loaded yet.
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    $clmCulture = if ($PSUICulture -like 'uk*') { 'uk-UA' } else { 'en-US' }
    # Import-LocalizedData reads -BaseDirectory as a wildcard pattern: [ ] * ? and the backtick of the folder name are escaped.
    $clmStrings = Import-LocalizedData -BaseDirectory ($PSScriptRoot -replace '([\[\]*?`])', '`$1') -FileName 'Chekap.strings.psd1' -UICulture $clmCulture -ErrorAction Stop
    throw $clmStrings['Core.ConstrainedLanguage']
}

# -LiteralPath, and no -ErrorAction SilentlyContinue: a folder name with [brackets] must not hide the files, and a load failure has to be loud.
$public = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File)
$private = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File) +
    @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private/Collect') -Filter '*.ps1' -File)

foreach ($file in $private + $public) {
    . $file.FullName
}

# The check registry is read once. A check file that is not valid stops the import with a localized message.
$script:ChekapChecks = @(Import-ChekapCheck -Path (Join-Path $PSScriptRoot 'Checks'))

Export-ModuleMember -Function @($public | ForEach-Object { $_.BaseName })
# Nothing of the loader stays behind in the module scope.
Remove-Variable -Name file, private, public

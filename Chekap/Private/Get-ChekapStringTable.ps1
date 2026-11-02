function Get-ChekapStringTable {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('uk', 'en')]
        [string]$Language
    )

    if (-not $script:ChekapStringCache) { $script:ChekapStringCache = @{} }
    if (-not $script:ChekapStringCache.ContainsKey($Language)) {
        $culture = if ($Language -eq 'uk') { 'uk-UA' } else { 'en-US' }
        # -BaseDirectory is read as a wildcard pattern: [ ] * ? and the backtick of the module folder are escaped.
        $base = $ExecutionContext.SessionState.Module.ModuleBase -replace '([\[\]*?`])', '`$1'
        $script:ChekapStringCache[$Language] = Import-LocalizedData -BaseDirectory $base `
            -FileName 'Chekap.strings.psd1' -UICulture $culture -ErrorAction Stop
    }
    $script:ChekapStringCache[$Language]
}

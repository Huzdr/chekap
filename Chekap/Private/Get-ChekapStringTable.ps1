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
        $script:ChekapStringCache[$Language] = Import-LocalizedData -BaseDirectory $ExecutionContext.SessionState.Module.ModuleBase `
            -FileName 'Chekap.strings.psd1' -UICulture $culture -ErrorAction Stop
    }
    $script:ChekapStringCache[$Language]
}

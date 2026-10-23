function Resolve-ChekapLanguage {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Callers forward their own optional -Language; $null arrives here as '' and means "not given".
        [ValidateSet('uk', 'en', '')]
        [string]$Language
    )

    if ($Language) { return $Language.ToLowerInvariant() }
    $configured = (Get-ChekapConfig).Language
    if ($configured) { return $configured }
    if ((Get-ChekapUICulture) -like 'uk*') { return 'uk' }
    'en'
}

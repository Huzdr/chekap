function Select-ChekapCheck {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [string[]]$Category,

        # Exact IDs or wildcards such as NET-*.
        [string[]]$CheckId,

        # Language of the warning; callers forward their own optional -Language.
        [ValidateSet('uk', 'en', '')]
        [string]$Language
    )

    foreach ($pattern in $CheckId) {
        if (-not ($script:ChekapChecks | Where-Object { $_.Id -like $pattern })) {
            $strings = Get-ChekapStringTable -Language (Resolve-ChekapLanguage -Language $Language)
            Write-Warning (Get-ChekapText -Strings $strings -Key 'Core.UnknownCheckId' -FormatArgs $pattern)
        }
    }

    $script:ChekapChecks | Where-Object {
        $check = $_
        ((-not $Category) -or ($check.Category -in $Category)) -and
        ((-not $CheckId) -or @($CheckId | Where-Object { $check.Id -like $_ }).Count -gt 0)
    }
}

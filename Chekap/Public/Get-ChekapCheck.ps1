function Get-ChekapCheck {
    <#
    .SYNOPSIS
    Lists the checks that Chekap knows.
    .DESCRIPTION
    Returns one Chekap.CheckInfo object per registered check: ID, category, localized title,
    whether it needs administrator rights, the minimum Windows build and the reference links.
    .PARAMETER Category
    Only the checks of these categories, for example Network or Printing.
    .PARAMETER Language
    Language of the titles: uk or en. By default the saved setting or the system language.
    .EXAMPLE
    Get-ChekapCheck -Category Network -Language en
    #>
    [CmdletBinding()]
    [OutputType('Chekap.CheckInfo')]
    param(
        [string[]]$Category,

        [ValidateSet('uk', 'en')]
        [string]$Language
    )

    $strings = Get-ChekapStringTable -Language (Resolve-ChekapLanguage -Language $Language)
    $selectArgs = @{}
    if ($Category) { $selectArgs.Category = $Category }
    foreach ($check in @(Select-ChekapCheck @selectArgs)) {
        $info = [pscustomobject][ordered]@{
            Id            = $check.Id
            Category      = $check.Category
            Title         = Get-ChekapText -Strings $strings -Key "$($check.Id).Title"
            RequiresAdmin = [bool]$check.RequiresAdmin
            MinBuild      = [int]$check.MinBuild
            References    = $check.References
        }
        $info.PSObject.TypeNames.Insert(0, 'Chekap.CheckInfo')
        $info
    }
}

function Get-ChekapCheck {
    # .ExternalHelp Chekap-help.xml
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

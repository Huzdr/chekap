function New-ChekapResult {
    [CmdletBinding()]
    [OutputType('Chekap.CheckResult')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Only builds an in-memory object.')]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Check,

        [Parameter(Mandatory)]
        [ValidateSet('OK', 'Warning', 'Critical', 'Error', 'Skipped')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Details,

        [string]$Recommendation,

        [string]$Target,

        [object]$Evidence,

        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    # Ordered: the property order is part of the contract (tables, CSV, JSON).
    $result = [pscustomobject][ordered]@{
        CheckId        = $Check.Id
        Category       = $Check.Category
        ComputerName   = $ComputerName
        Status         = $Status
        Target         = if ($Target) { $Target } else { $null }
        Title          = $Title
        Details        = $Details
        Recommendation = if ($Recommendation) { $Recommendation } else { $null }
        FixId          = $null
        FixRiskLevel   = $null
        Evidence       = $Evidence
        References     = $Check.References
        Timestamp      = Get-Date
    }
    $result.PSObject.TypeNames.Insert(0, 'Chekap.CheckResult')
    $result
}

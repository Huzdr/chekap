function ConvertTo-ChekapJsonValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [AllowNull()]
        [object]$Value
    )

    # Makes a value safe for ConvertTo-Json on both engines: Windows PowerShell 5.1 writes a [datetime] as "\/Date(...)\/" and a
    # [version] as an object, and flattens a one-item or empty array. Dates become ISO 8601 text, hashtables and objects become
    # dictionaries with sorted keys, and every array stays an array.
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return $Value.ToString('o') }
    if ($Value -is [datetimeoffset]) { return $Value.ToString('o') }
    if ($Value -is [string] -or $Value -is [bool] -or $Value -is [decimal]) { return $Value }
    if ($Value -is [char] -or $Value -is [enum]) { return [string]$Value }
    if ($Value.GetType().IsPrimitive) { return $Value }
    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in @($Value.Keys | Sort-Object -Property { [string]$_ })) {
            $copy[[string]$key] = ConvertTo-ChekapJsonValue -Value $Value[$key]
        }
        return $copy
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        # Properties keep their order: the order of Chekap.CheckResult is part of the contract.
        $copy = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $copy[$property.Name] = ConvertTo-ChekapJsonValue -Value $property.Value
        }
        return $copy
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @(foreach ($item in $Value) { ConvertTo-ChekapJsonValue -Value $item })
        # The comma stops the pipeline from unrolling the array again.
        return , $items
    }
    # Version, TimeSpan, Guid and the like.
    [string]$Value
}

function Get-ChekapText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Strings,

        [Parameter(Mandatory)]
        [string]$Key,

        [object[]]$FormatArgs,

        # Return $null instead of the key when the key is missing.
        [switch]$Optional
    )

    if (-not $Strings.ContainsKey($Key)) {
        if ($Optional) { return $null }
        return $Key
    }
    if ($FormatArgs) { return ([string]$Strings[$Key]) -f $FormatArgs }
    [string]$Strings[$Key]
}

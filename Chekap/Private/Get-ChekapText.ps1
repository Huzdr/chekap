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
    # Count, not truthiness: a single argument such as 0 or '' is falsy but must still be formatted.
    if ($FormatArgs.Count -gt 0) { return ([string]$Strings[$Key]) -f $FormatArgs }
    [string]$Strings[$Key]
}

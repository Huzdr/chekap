function Get-ChekapUICulture {
    # Thin wrapper so tests can fake the UI culture.
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $PSUICulture
}

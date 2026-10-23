function Get-ChekapConfigPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Join-Path -Path $env:APPDATA -ChildPath 'Chekap\config.json'
}

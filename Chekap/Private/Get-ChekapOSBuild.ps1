function Get-ChekapOSBuild {
    [CmdletBinding()]
    [OutputType([int])]
    param()

    [Environment]::OSVersion.Version.Build
}

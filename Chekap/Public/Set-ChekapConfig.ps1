function Set-ChekapConfig {
    <#
    .SYNOPSIS
    Saves the Chekap settings.
    .DESCRIPTION
    Writes %APPDATA%\Chekap\config.json for the current user. Supports -WhatIf and -Confirm.
    .PARAMETER Language
    Language of the checks, reports and messages: uk (Ukrainian) or en (English).
    Without a saved language Chekap follows the language of the Windows interface.
    .EXAMPLE
    Set-ChekapConfig -Language uk
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('uk', 'en')]
        [string]$Language
    )

    $path = Get-ChekapConfigPath
    if (-not $PSCmdlet.ShouldProcess($path)) { return }

    $Language = $Language.ToLowerInvariant()
    $folder = Split-Path -Path $path -Parent
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    $json = [pscustomobject]@{ Language = $Language } | ConvertTo-Json
    # UTF-8 without BOM: the same bytes on Windows PowerShell 5.1 and PowerShell 7.
    [System.IO.File]::WriteAllText($path, $json, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false))
    Write-Verbose (Get-ChekapText -Strings (Get-ChekapStringTable -Language $Language) -Key 'Config.Saved' -FormatArgs $path)
}

function Get-ChekapConfig {
    <#
    .SYNOPSIS
    Gets the Chekap settings.
    .DESCRIPTION
    Reads %APPDATA%\Chekap\config.json. A missing, unreadable or invalid file gives the defaults,
    so the command never throws because of the settings file.
    .EXAMPLE
    Get-ChekapConfig
    #>
    [CmdletBinding()]
    [OutputType('Chekap.Config')]
    param()

    $language = $null
    $path = Get-ChekapConfigPath
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            # No message here: building one needs the language, which is resolved from this very file.
            $saved = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($saved.Language -in 'uk', 'en') { $language = ([string]$saved.Language).ToLowerInvariant() }
        }
        catch {
            $language = $null
        }
    }
    [pscustomobject]@{
        PSTypeName = 'Chekap.Config'
        Language   = $language
    }
}

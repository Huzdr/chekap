function Import-ChekapCheck {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        # Folder with check files, one per check: <Path>\<Category>\<Id>.ps1
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Git keeps no empty folders, so a missing folder just means "no checks".
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return @() }

    $reason = {
        param([string]$Key, [object[]]$FormatArgs)
        Get-ChekapText -Strings (Get-ChekapStringTable -Language (Resolve-ChekapLanguage)) -Key $Key -FormatArgs $FormatArgs
    }

    $checks = foreach ($file in Get-ChildItem -LiteralPath $Path -Filter '*.ps1' -Recurse -File) {
        try {
            # Runs in this module's scope, so the Collect blocks can call the private helpers.
            $check = & $file.FullName
            if ($check -isnot [hashtable]) { throw (& $reason 'Core.InvalidCheckFile.NotHashtable') }
            foreach ($name in 'Id', 'Category') {
                if ($check[$name] -isnot [string] -or -not $check[$name]) { throw (& $reason 'Core.InvalidCheckFile.BadKey' $name) }
            }
            foreach ($name in 'Collect', 'Evaluate') {
                if ($check[$name] -isnot [scriptblock]) { throw (& $reason 'Core.InvalidCheckFile.BadKey' $name) }
            }
            if (-not $check.ContainsKey('RequiresAdmin')) { $check.RequiresAdmin = $false }
            if (-not $check.ContainsKey('MinBuild')) { $check.MinBuild = 0 }
            if (-not $check.ContainsKey('Settings')) { $check.Settings = @{} }
            if (-not $check.ContainsKey('References')) { $check.References = @() }
            $check
        }
        catch {
            throw (& $reason 'Core.InvalidCheckFile' $file.FullName, $_.Exception.Message)
        }
    }
    @($checks | Sort-Object -Property { $_.Id })
}

function Show-ChekapResult {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Prints for the person at the console; the menu is not meant for the pipeline.')]
    param(
        [Parameter(Mandatory)]
        [object[]]$Result,

        [Parameter(Mandatory)]
        [hashtable]$Strings
    )

    $colors = @{ Critical = 'Red'; Error = 'Magenta'; Warning = 'Yellow'; Skipped = 'DarkGray'; OK = 'Green' }

    # Every line says its status in words: the colour is only a hint (colour-blind users, monochrome consoles, copied text).
    $counters = foreach ($status in 'Critical', 'Error', 'Warning', 'Skipped', 'OK') {
        $count = @($Result | Where-Object { $_.Status -eq $status }).Count
        if ($count -gt 0) {
            Get-ChekapText -Strings $Strings -Key 'Tui.Counter' -FormatArgs (Get-ChekapText -Strings $Strings -Key "Status.$status"), $count
        }
    }
    Write-Host ($counters -join '   ')

    if (@($Result | Where-Object { $_.Status -ne 'OK' }).Count -eq 0) {
        Write-Host (Get-ChekapText -Strings $Strings -Key 'Tui.AllOk') -ForegroundColor $colors.OK
        return
    }

    # The worst first. A loop per status, not Sort-Object: it keeps the order of the checks within a status.
    foreach ($status in 'Critical', 'Error', 'Warning', 'Skipped') {
        $label = Get-ChekapText -Strings $Strings -Key "Status.$status"
        foreach ($item in @($Result | Where-Object { $_.Status -eq $status })) {
            $line = if ($item.Target) {
                Get-ChekapText -Strings $Strings -Key 'Tui.Finding' -FormatArgs $label, $item.Title, $item.Target
            }
            else {
                Get-ChekapText -Strings $Strings -Key 'Tui.FindingNoTarget' -FormatArgs $label, $item.Title
            }
            Write-Host
            Write-Host $line -ForegroundColor $colors[$status]
            if ($item.Details) { Write-Host "    $($item.Details)" }
            if ($item.Recommendation) {
                Write-Host ('    ' + (Get-ChekapText -Strings $Strings -Key 'Tui.Recommendation' -FormatArgs $item.Recommendation))
            }
        }
    }
}

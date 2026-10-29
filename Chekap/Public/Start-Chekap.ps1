function Start-Chekap {
    <#
    .SYNOPSIS
    Opens a console menu for running the Chekap checks without typing commands.
    .DESCRIPTION
    Shows a numbered menu: run all checks or one category, run all checks and save an HTML and a JSON report,
    switch between Ukrainian and English, or exit. Findings are printed from the worst to the best, each with
    its status in words, the details and what to do. The report goes to the Chekap folder inside Documents
    and opens in the default browser. The language chosen in the menu is saved with Set-ChekapConfig.
    The checks only read data. Without administrator rights the checks that need them are reported as Skipped.
    The menu reads from the console, so it needs an interactive PowerShell window.
    .EXAMPLE
    Start-Chekap
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'The menu talks to the person at the console; it is not meant for the pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'An interactive menu: it changes nothing by itself, and each item that writes a file is chosen and seen by the person.')]
    param()

    # The language is session state: item 6 changes this variable, and the saved setting is read only once, here.
    $lang = Resolve-ChekapLanguage
    $strings = Get-ChekapStringTable -Language $lang
    $isAdmin = Test-ChekapAdmin
    $version = $ExecutionContext.SessionState.Module.Version.ToString()
    $categoryOf = @{ '2' = 'System'; '3' = 'Network'; '4' = 'Printing' }
    # Messages for the next screen: the loop starts with Clear-Host, which would wipe a message printed right before it.
    $notices = New-Object -TypeName 'System.Collections.Generic.List[object]'

    while ($true) {
        Clear-Host
        Write-Host (Get-ChekapText -Strings $strings -Key 'Tui.Header' -FormatArgs $version, $env:COMPUTERNAME) -ForegroundColor Cyan
        if (-not $isAdmin) {
            Write-Host (Get-ChekapText -Strings $strings -Key 'Tui.NotAdmin') -ForegroundColor Yellow
        }
        Write-Host
        foreach ($item in 1, 2, 3, 4, 5, 6, 0) {
            Write-Host (Get-ChekapText -Strings $strings -Key "Tui.Menu.$item")
        }
        Write-Host
        foreach ($notice in $notices) {
            Write-Host $notice.Text -ForegroundColor $notice.Color
        }
        $notices.Clear()

        $answer = Read-Host (Get-ChekapText -Strings $strings -Key 'Tui.Prompt')
        # Read-Host gives $null only when the input has ended (a closed pipe). Empty input is a mistake, not the end.
        if ($null -eq $answer) { return }
        $choice = $answer.Trim()

        if ($choice -notmatch '^[0-6]$') {
            $notices.Add(@{ Text = (Get-ChekapText -Strings $strings -Key 'Tui.InvalidChoice'); Color = 'Yellow' })
            continue
        }
        if ($choice -eq '0') { return }

        if ($choice -eq '6') {
            $lang = if ($lang -eq 'uk') { 'en' } else { 'uk' }
            $strings = Get-ChekapStringTable -Language $lang
            $notices.Add(@{ Text = (Get-ChekapText -Strings $strings -Key 'Tui.LanguageSet'); Color = 'Green' })
            try {
                Set-ChekapConfig -Language $lang -ErrorAction Stop
            }
            catch {
                # The switch still works for this session; only the next start would forget it.
                $notices.Add(@{ Text = (Get-ChekapText -Strings $strings -Key 'Tui.LanguageNotSaved' -FormatArgs $_.Exception.Message); Color = 'Yellow' })
            }
            continue
        }

        # Items 1 to 5 run checks: 1 and 5 all of them, 2 to 4 one category.
        Write-Host (Get-ChekapText -Strings $strings -Key 'Tui.Running')
        $select = @{ Language = $lang }
        if ($categoryOf.ContainsKey($choice)) { $select.Category = $categoryOf[$choice] }
        $results = @(Invoke-ChekapCheck -Check @(Select-ChekapCheck @select) -Language $lang)
        Show-ChekapResult -Result $results -Strings $strings

        if ($choice -eq '5') {
            Write-Host
            # A failed export or a missing browser must not close the menu: tell the person and go back to it.
            try {
                $folder = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'Chekap'
                $files = @(Export-ChekapReport -Result $results -Language $lang -OutputPath $folder -SystemInfo (Get-ChekapSystemInfo))
                $html = ($files | Where-Object { $_.Extension -eq '.html' } | Select-Object -First 1).FullName
                Write-Host (Get-ChekapText -Strings $strings -Key 'Tui.ReportSaved' -FormatArgs $html) -ForegroundColor Green
                try {
                    Invoke-Item -LiteralPath $html -ErrorAction Stop
                }
                catch {
                    Write-Host (Get-ChekapText -Strings $strings -Key 'Tui.OpenFailed' -FormatArgs $_.Exception.Message) -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host (Get-ChekapText -Strings $strings -Key 'Tui.ReportFailed' -FormatArgs $_.Exception.Message) -ForegroundColor Red
            }
        }

        Write-Host
        $null = Read-Host (Get-ChekapText -Strings $strings -Key 'Tui.PressEnter')
    }
}

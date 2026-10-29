function Start-Chekap {
    # .ExternalHelp Chekap-help.xml
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'The menu talks to the person at the console; it is not meant for the pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'The person picks each action in the menu; the only config write goes through Set-ChekapConfig, which supports ShouldProcess.')]
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
                $files = @(Export-ChekapReport -Result $results -Language $lang -OutputPath $folder -Format Html, Json -SystemInfo (Get-ChekapSystemInfo))
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

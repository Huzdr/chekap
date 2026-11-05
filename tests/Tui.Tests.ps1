BeforeAll {
    $script:root = Split-Path -Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:root 'Chekap/Chekap.psd1') -Force
    $script:version = (Get-Module Chekap).Version.ToString()
    $script:en = Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/en-US/Chekap.strings.psd1')
    $script:uk = Import-PowerShellDataFile -Path (Join-Path $script:root 'Chekap/uk-UA/Chekap.strings.psd1')

    # The log lines the mocks write, in the order the host would see them: CLEAR, SAY|<colour>|<text>, ASK|<prompt>,
    # CHECK|<language>|<ids>, EXPORT|<language>|<folder>|<result count>|<computer>|<formats>, OPEN|<file>, CONFIG|<language>.
    $script:say = { param([string]$Color, [string]$Text) "SAY|$Color|$Text" }
    # The check IDs a menu item must run, from the real registry. No category means all checks.
    $script:ids = {
        param([string[]]$Category)
        InModuleScope Chekap -Parameters @{ Category = $Category } {
            ($script:ChekapChecks | Where-Object { (-not $Category) -or $_.Category -in $Category } | ForEach-Object { $_.Id }) -join ','
        }
    }
    # Runs Start-Chekap with a queue of answers for Read-Host. Returns what it wrote to the pipeline and the log.
    # The log and the queue are variables of this test file: a mock body sees the scope it was written in, not the module's.
    $script:drive = {
        param([object[]]$Answers)
        $script:TuiLog = [System.Collections.Generic.List[string]]::new()
        $script:TuiAnswers = [System.Collections.Generic.Queue[object]]::new()
        foreach ($answer in $Answers) { $script:TuiAnswers.Enqueue($answer) }
        $output = @(InModuleScope Chekap { Start-Chekap -NoBanner })
        [pscustomobject]@{ Output = $output; Log = $script:TuiLog.ToArray() }
    }
    # 'ok' when the lines occur in the log in this order (other lines may sit between them), otherwise the first line that is missing.
    $script:inOrder = {
        param([string[]]$Log, [string[]]$Lines)
        $from = 0
        foreach ($line in $Lines) {
            $at = if ($from -lt $Log.Count) { [array]::IndexOf($Log, $line, $from) } else { -1 }
            if ($at -lt 0) { return "not found after position ${from}: $line" }
            $from = $at + 1
        }
        'ok'
    }
    # One screen of the log: the lines from the Clear-Host of screen <Number> (counted from 0) up to the next Clear-Host.
    $script:screen = {
        param([string[]]$Log, [int]$Number)
        $starts = @(0..($Log.Count - 1) | Where-Object { $Log[$_] -eq 'CLEAR' })
        $end = if ($Number + 1 -lt $starts.Count) { $starts[$Number + 1] - 1 } else { $Log.Count - 1 }
        , [string[]]@($Log[$starts[$Number]..$end])
    }
    # What every Start-Chekap test starts from. -RealConfig leaves Set-ChekapConfig unmocked (the caller must then fake Get-ChekapConfigPath).
    $script:startMocks = {
        param([switch]$RealConfig)
        $script:TuiConfigLanguage = 'uk'
        $script:TuiResults = InModuleScope Chekap {
            $pc = 'PC-042'
            $check = { param($id, $category) @{ Id = $id; Category = $category; References = @('https://learn.microsoft.com/windows/') } }
            @(
                New-ChekapResult -Check (& $check 'SYS-UPTIME-001' 'System') -Status OK -Title 'Uptime' -Details 'Up for 3 days.' -ComputerName $pc
                New-ChekapResult -Check (& $check 'PRN-SPOOLER-001' 'Printing') -Status Critical -Title 'Print spooler' -Details 'The spooler is stopped.' `
                    -Recommendation 'Start the Print Spooler service.' -Target 'PRN-2F-HP' -ComputerName $pc
            )
        }
        # Nothing here touches the real console, the real settings file or the real Documents folder.
        Mock Clear-Host { $script:TuiLog.Add('CLEAR') } -ModuleName Chekap
        Mock Write-Host { $script:TuiLog.Add(('SAY|{0}|{1}' -f $ForegroundColor, ($Object -join ' '))) } -ModuleName Chekap
        # An empty queue throws, so a loop that never ends fails the test instead of hanging it.
        Mock Read-Host { $script:TuiLog.Add("ASK|$Prompt"); $script:TuiAnswers.Dequeue() } -ModuleName Chekap
        Mock Get-ChekapConfig { [pscustomobject]@{ Language = $script:TuiConfigLanguage } } -ModuleName Chekap
        if (-not $RealConfig) {
            Mock Set-ChekapConfig { $script:TuiLog.Add("CONFIG|$Language") } -ModuleName Chekap
        }
        Mock Test-ChekapAdmin { $true } -ModuleName Chekap
        Mock Get-ChekapSystemInfo { @{ ComputerName = 'PC-042' } } -ModuleName Chekap
        Mock Invoke-ChekapCheck {
            $script:TuiLog.Add(('CHECK|{0}|{1}' -f $Language, (($Check | ForEach-Object { $_.Id }) -join ',')))
            $script:TuiResults
        } -ModuleName Chekap
        Mock Export-ChekapReport {
            $script:TuiLog.Add(('EXPORT|{0}|{1}|{2}|{3}|{4}' -f $Language, $OutputPath, @($Result).Count, $SystemInfo.ComputerName, ($Format -join ',')))
            # The JSON first: the menu must pick the HTML by its extension.
            [System.IO.FileInfo]::new((Join-Path $OutputPath 'Chekap-PC-042-20260310-1130.json'))
            [System.IO.FileInfo]::new((Join-Path $OutputPath 'Chekap-PC-042-20260310-1130.html'))
        } -ModuleName Chekap
        Mock Invoke-Item { $script:TuiLog.Add("OPEN|$LiteralPath") } -ModuleName Chekap
        $script:reportFolder = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Chekap'
        $script:reportHtml = Join-Path $script:reportFolder 'Chekap-PC-042-20260310-1130.html'
    }
}

AfterAll {
    Remove-Module Chekap -ErrorAction SilentlyContinue
}

Describe 'Show-ChekapResult' {
    BeforeAll {
        # Built the way the runner builds them, in a deliberately mixed order.
        $script:results = InModuleScope Chekap {
            $pc = 'PC-042'
            $check = { param($id, $category) @{ Id = $id; Category = $category; References = @('https://learn.microsoft.com/windows/') } }
            $make = {
                param($id, $category, $status, $title, $details, $recommendation, $target)
                New-ChekapResult -Check (& $check $id $category) -Status $status -Title $title -Details $details `
                    -Recommendation $recommendation -Target $target -ComputerName $pc
            }
            @(
                & $make 'SYS-UPTIME-001' 'System' 'OK' 'Uptime' 'Up for 3 days.' $null $null
                & $make 'SYS-DISK-001' 'System' 'Warning' 'Free space on the system drive' 'Only 12% free.' 'Free up space.' $null
                & $make 'SYS-BATTERY-001' 'System' 'Skipped' 'Battery' 'No battery.' $null ''
                & $make 'NET-DNS-001' 'Network' 'Error' 'DNS servers' 'Could not collect the data: timeout' 'Run again with -Verbose.' 'contoso.local'
                & $make 'PRN-SPOOLER-001' 'Printing' 'Critical' 'Print spooler' 'The spooler is stopped.' 'Start the Print Spooler service.' 'PRN-2F-HP'
                & $make 'NET-TIME-001' 'Network' 'Warning' 'Time synchronization' 'The clock is 12 seconds off.' 'Check the time source.' 'contoso.local'
            )
        }
        $script:show = {
            param($Results, $Strings)
            $script:TuiLog = [System.Collections.Generic.List[string]]::new()
            InModuleScope Chekap -Parameters @{ Results = $Results; Strings = $Strings } {
                Show-ChekapResult -Result $Results -Strings $Strings
            }
            $script:TuiLog.ToArray()
        }
    }

    BeforeEach {
        Mock Write-Host { $script:TuiLog.Add(('SAY|{0}|{1}' -f $ForegroundColor, ($Object -join ' '))) } -ModuleName Chekap
    }

    It 'prints the counters, then the findings from the worst to the best, with status words and colours' {
        $lines = & $script:show $script:results $script:en
        $expected = @(
            (& $script:say '' 'Critical: 1   Error: 1   Warning: 2   Skipped: 1   OK: 1')
            (& $script:say '' '')
            (& $script:say 'Red' '[Critical] Print spooler — PRN-2F-HP')
            (& $script:say '' '    The spooler is stopped.')
            (& $script:say '' '    → Start the Print Spooler service.')
            (& $script:say '' '')
            (& $script:say 'Magenta' '[Error] DNS servers — contoso.local')
            (& $script:say '' '    Could not collect the data: timeout')
            (& $script:say '' '    → Run again with -Verbose.')
            (& $script:say '' '')
            (& $script:say 'Yellow' '[Warning] Free space on the system drive')
            (& $script:say '' '    Only 12% free.')
            (& $script:say '' '    → Free up space.')
            (& $script:say '' '')
            (& $script:say 'Yellow' '[Warning] Time synchronization — contoso.local')
            (& $script:say '' '    The clock is 12 seconds off.')
            (& $script:say '' '    → Check the time source.')
            (& $script:say '' '')
            (& $script:say 'DarkGray' '[Skipped] Battery')
            (& $script:say '' '    No battery.')
        )
        ($lines -join "`n") | Should -Be ($expected -join "`n")
    }

    It 'leaves out the target when there is none, and the arrow line when there is no recommendation' {
        $lines = & $script:show $script:results $script:en
        # Free space has no target, Battery has an empty one and no recommendation.
        @($lines | Where-Object { $_ -match '—\s*$' }) | Should -BeNullOrEmpty
        $battery = [array]::IndexOf($lines, (& $script:say 'DarkGray' '[Skipped] Battery'))
        $lines.Count | Should -Be ($battery + 2)
    }

    It 'does not print OK findings' {
        $lines = & $script:show $script:results $script:en
        @($lines | Where-Object { $_ -like '*Uptime*' -or $_ -like '*Up for 3 days*' }) | Should -BeNullOrEmpty
    }

    It 'writes the status labels of the chosen language' {
        $lines = & $script:show $script:results $script:uk
        $lines | Should -Contain (& $script:say 'Red' "[$($script:uk['Status.Critical'])] Print spooler — PRN-2F-HP")
        $lines | Should -Contain (& $script:say 'DarkGray' "[$($script:uk['Status.Skipped'])] Battery")
        $lines[0] | Should -Be (& $script:say '' ('{0}: 1   {1}: 1   {2}: 2   {3}: 1   {4}: 1' -f $script:uk['Status.Critical'], $script:uk['Status.Error'],
                $script:uk['Status.Warning'], $script:uk['Status.Skipped'], $script:uk['Status.OK']))
    }

    It 'prints only the counters of the statuses that are present, then AllOk in green, when everything is OK' {
        $ok = @($script:results | Where-Object { $_.Status -eq 'OK' })
        $lines = & $script:show $ok $script:en
        $lines | Should -Be @((& $script:say '' 'OK: 1'), (& $script:say 'Green' $script:en['Tui.AllOk']))
    }

    It 'prints braces in a title as they are' {
        $odd = InModuleScope Chekap {
            $pc = 'PC-042'
            New-ChekapResult -Check @{ Id = 'PRN-QUEUE-001'; Category = 'Printing'; References = @('https://learn.microsoft.com/') } -Status Warning `
                -Title 'Queue {0} {1:N0}' -Details 'Two stuck jobs.' -Recommendation 'Clear the queue.' -Target 'PRN-2F-HP' -ComputerName $pc
        }
        $lines = & $script:show @($odd) $script:en
        $lines | Should -Contain (& $script:say 'Yellow' '[Warning] Queue {0} {1:N0} — PRN-2F-HP')
    }
}

Describe 'Start-Chekap' {
    BeforeEach {
        & $script:startMocks
    }

    Context 'the screen' {
        It 'clears, then writes the header, the menu items 1 to 6 and 0, and asks at the prompt' {
            $run = & $script:drive -Answers '0'
            $expected = @('CLEAR', (& $script:say 'Cyan' ($script:uk['Tui.Header'] -f $script:version, $env:COMPUTERNAME)), (& $script:say '' ''))
            $expected += 1, 2, 3, 4, 5, 6, 0 | ForEach-Object { & $script:say '' $script:uk["Tui.Menu.$_"] }
            $expected += (& $script:say '' ''), "ASK|$($script:uk['Tui.Prompt'])"
            ($run.Log -join "`n") | Should -Be ($expected -join "`n")
        }

        It 'writes nothing to the pipeline' {
            (& $script:drive -Answers '3', '', '0').Output | Should -BeNullOrEmpty
        }

        It 'tells under the header why checks are skipped when PowerShell is not elevated' {
            Mock Test-ChekapAdmin { $false } -ModuleName Chekap
            $log = (& $script:drive -Answers '0').Log
            $log[1] | Should -Be (& $script:say 'Cyan' ($script:uk['Tui.Header'] -f $script:version, $env:COMPUTERNAME))
            $log[2] | Should -Be (& $script:say 'Yellow' $script:uk['Tui.NotAdmin'])
        }

        It 'does not show the NotAdmin line when PowerShell is elevated' {
            $log = (& $script:drive -Answers '0').Log
            $log | Should -Not -Contain (& $script:say 'Yellow' $script:uk['Tui.NotAdmin'])
        }

        It 'shows the banner above the first menu in an interactive session, and -NoBanner skips it' {
            Mock Show-HuzdrBanner { $script:TuiLog.Add("BANNER|$Subtitle") } -ModuleName Chekap
            $script:TuiLog = [System.Collections.Generic.List[string]]::new()
            $script:TuiAnswers = [System.Collections.Generic.Queue[object]]::new()
            $script:TuiAnswers.Enqueue('0')
            $null = InModuleScope Chekap { Start-Chekap }
            # A CI service runs without a user session: there the banner must stay off, as in a remote session.
            if ([Environment]::UserInteractive -and $Host.Name -ne 'ServerRemoteHost') {
                $script:TuiLog[0] | Should -Be "BANNER|Chekap $script:version"
                $script:TuiLog | Should -Not -Contain 'CLEAR'
            }
            else {
                $script:TuiLog[0] | Should -Be 'CLEAR'
            }
            @((& $script:drive -Answers '0').Log | Where-Object { $_ -like 'BANNER*' }).Count | Should -Be 0
        }
    }

    Context 'the banner' {
        It 'writes the mask, the signature and the subtitle to the host only' {
            $script:TuiLog = [System.Collections.Generic.List[string]]::new()
            $output = @(InModuleScope Chekap { Show-HuzdrBanner -Subtitle 'Chekap 9.9.9' })
            $output | Should -BeNullOrEmpty
            $script:TuiLog | Should -Contain (('SAY|DarkGray|{0}Chekap 9.9.9' -f (' ' * 24)))
            @($script:TuiLog | Where-Object { $_ -like 'SAY|Green|*/____/*' }).Count | Should -Be 1
        }
    }

    Context 'running checks' {
        It 'choice <Choice> runs <What>, shows the findings and waits for Enter' -ForEach @(
            @{ Choice = '1'; What = 'all checks'; Category = $null }
            @{ Choice = '2'; What = 'the System checks'; Category = 'System' }
            @{ Choice = '3'; What = 'the Network checks'; Category = 'Network' }
            @{ Choice = '4'; What = 'the Printing checks'; Category = 'Printing' }
        ) {
            $run = & $script:drive -Answers $Choice, '', '0'
            $ids = & $script:ids $Category
            $ids | Should -Not -BeNullOrEmpty
            @($run.Log | Where-Object { $_ -like 'CHECK|*' }) | Should -Be @("CHECK|uk|$ids")
            @($run.Log | Where-Object { $_ -like 'EXPORT|*' -or $_ -like 'OPEN|*' }) | Should -BeNullOrEmpty
            $order = @(
                (& $script:say '' $script:uk['Tui.Running'])
                "CHECK|uk|$ids"
                (& $script:say '' ('{0}: 1   {1}: 1' -f $script:uk['Status.Critical'], $script:uk['Status.OK']))
                (& $script:say 'Red' "[$($script:uk['Status.Critical'])] Print spooler — PRN-2F-HP")
                "ASK|$($script:uk['Tui.PressEnter'])"
            )
            & $script:inOrder $run.Log $order | Should -Be 'ok'
            # After Enter the menu is drawn again, and 0 ends it.
            @($run.Log | Where-Object { $_ -eq 'CLEAR' }).Count | Should -Be 2
            $run.Log[-1] | Should -Be "ASK|$($script:uk['Tui.Prompt'])"
        }

        It 'keeps the findings on screen until Enter: no Clear-Host between them and the Enter prompt' {
            $log = (& $script:drive -Answers '1', '', '0').Log
            $first = & $script:screen $log 0
            $first | Should -Contain (& $script:say 'Red' "[$($script:uk['Status.Critical'])] Print spooler — PRN-2F-HP")
            $first[-1] | Should -Be "ASK|$($script:uk['Tui.PressEnter'])"
        }

        It 'trims the answer' {
            $run = & $script:drive -Answers ' 3 ', '', '0'
            @($run.Log | Where-Object { $_ -like 'CHECK|*' }) | Should -Be @("CHECK|uk|$(& $script:ids 'Network')")
        }

        It 'does not run anything on 0' {
            $run = & $script:drive -Answers '0'
            @($run.Log | Where-Object { $_ -like 'CHECK|*' }) | Should -BeNullOrEmpty
        }
    }

    Context 'a wrong answer' {
        It 'shows InvalidChoice for <Name> and runs nothing' -ForEach @(
            @{ Name = 'empty input'; Answer = '' }
            @{ Name = 'spaces only'; Answer = '   ' }
            @{ Name = '7'; Answer = '7' }
            @{ Name = '-1'; Answer = '-1' }
            @{ Name = '01'; Answer = '01' }
            @{ Name = '3x'; Answer = '3x' }
            @{ Name = 'a letter'; Answer = 'x' }
            @{ Name = 'two answers in one'; Answer = '1 2' }
        ) {
            $run = & $script:drive -Answers $Answer, '0'
            @($run.Log | Where-Object { $_ -like 'CHECK|*' -or $_ -like 'CONFIG|*' -or $_ -like 'EXPORT|*' }) | Should -BeNullOrEmpty
            @($run.Log | Where-Object { $_ -eq (& $script:say 'Yellow' $script:uk['Tui.InvalidChoice']) }).Count | Should -Be 1
        }

        It 'keeps the message on screen: the next screen ends with it, right before the prompt' {
            $log = (& $script:drive -Answers 'x', '0').Log
            $second = & $script:screen $log 1
            $second[-2] | Should -Be (& $script:say 'Yellow' $script:uk['Tui.InvalidChoice'])
            $second[-1] | Should -Be "ASK|$($script:uk['Tui.Prompt'])"
        }

        It 'shows the message once, not again on the next screens' {
            $log = (& $script:drive -Answers 'x', '3', '', '0').Log
            @($log | Where-Object { $_ -eq (& $script:say 'Yellow' $script:uk['Tui.InvalidChoice']) }).Count | Should -Be 1
        }
    }

    Context 'item 5: report' {
        It 'runs all checks, exports with the PC passport into Documents\Chekap, prints the path, then opens the HTML' {
            $run = & $script:drive -Answers '5', '', '0'
            $ids = & $script:ids $null
            $order = @(
                "CHECK|uk|$ids"
                "EXPORT|uk|$($script:reportFolder)|2|PC-042|Html,Json"
                (& $script:say 'Green' ($script:uk['Tui.ReportSaved'] -f $script:reportHtml))
                "OPEN|$($script:reportHtml)"
                "ASK|$($script:uk['Tui.PressEnter'])"
            )
            & $script:inOrder $run.Log $order | Should -Be 'ok'
            Should -Invoke Invoke-Item -ModuleName Chekap -Times 1 -Exactly
        }

        It 'does not write a report for the other items' {
            $run = & $script:drive -Answers '1', '', '2', '', '3', '', '4', '', '0'
            @($run.Log | Where-Object { $_ -like 'EXPORT|*' -or $_ -like 'OPEN|*' }) | Should -BeNullOrEmpty
        }

        It 'reports a failed export, opens nothing and returns to the menu' {
            Mock Export-ChekapReport { throw 'The disk is full.' } -ModuleName Chekap
            $run = & $script:drive -Answers '5', '', '0'
            $order = @(
                (& $script:say 'Red' ($script:uk['Tui.ReportFailed'] -f 'The disk is full.'))
                "ASK|$($script:uk['Tui.PressEnter'])"
                'CLEAR'
            )
            & $script:inOrder $run.Log $order | Should -Be 'ok'
            @($run.Log | Where-Object { $_ -like 'OPEN|*' }) | Should -BeNullOrEmpty
            $run.Log[-1] | Should -Be "ASK|$($script:uk['Tui.Prompt'])"
        }

        It 'reports a PC passport that cannot be read the same way and does not crash the menu' {
            Mock Get-ChekapSystemInfo { throw 'WMI is not available.' } -ModuleName Chekap
            $run = & $script:drive -Answers '5', '', '0'
            $run.Log | Should -Contain (& $script:say 'Red' ($script:uk['Tui.ReportFailed'] -f 'WMI is not available.'))
        }

        It 'says where the report is, then that it could not be opened, and returns to the menu' {
            Mock Invoke-Item { throw 'No application is associated with this file.' } -ModuleName Chekap
            $run = & $script:drive -Answers '5', '', '0'
            $order = @(
                (& $script:say 'Green' ($script:uk['Tui.ReportSaved'] -f $script:reportHtml))
                (& $script:say 'Yellow' ($script:uk['Tui.OpenFailed'] -f 'No application is associated with this file.'))
                "ASK|$($script:uk['Tui.PressEnter'])"
                'CLEAR'
            )
            & $script:inOrder $run.Log $order | Should -Be 'ok'
            $run.Log[-1] | Should -Be "ASK|$($script:uk['Tui.Prompt'])"
        }

        It 'keeps the failure message on screen until Enter is pressed' {
            Mock Export-ChekapReport { throw 'The disk is full.' } -ModuleName Chekap
            $log = (& $script:drive -Answers '5', '', '0').Log
            $first = & $script:screen $log 0
            $first | Should -Contain (& $script:say 'Red' ($script:uk['Tui.ReportFailed'] -f 'The disk is full.'))
            $first[-1] | Should -Be "ASK|$($script:uk['Tui.PressEnter'])"
        }
    }

    Context 'item 6: language' {
        It 'switches uk to en, saves it and tells so in English on the next screen' {
            $run = & $script:drive -Answers '6', '0'
            Should -Invoke Set-ChekapConfig -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Language -eq 'en' }
            $order = @(
                'CONFIG|en'
                'CLEAR'
                (& $script:say 'Cyan' ($script:en['Tui.Header'] -f $script:version, $env:COMPUTERNAME))
                (& $script:say '' $script:en['Tui.Menu.1'])
                (& $script:say '' $script:en['Tui.Menu.0'])
                (& $script:say 'Green' $script:en['Tui.LanguageSet'])
                "ASK|$($script:en['Tui.Prompt'])"
            )
            & $script:inOrder $run.Log $order | Should -Be 'ok'
            $second = & $script:screen $run.Log 1
            $second[-2] | Should -Be (& $script:say 'Green' $script:en['Tui.LanguageSet'])
            $second[-1] | Should -Be "ASK|$($script:en['Tui.Prompt'])"
        }

        It 'switches en to uk' {
            $script:TuiConfigLanguage = 'en'
            $run = & $script:drive -Answers '6', '0'
            Should -Invoke Set-ChekapConfig -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Language -eq 'uk' }
            $run.Log | Should -Contain (& $script:say 'Green' $script:uk['Tui.LanguageSet'])
            $run.Log[-1] | Should -Be "ASK|$($script:uk['Tui.Prompt'])"
        }

        It 'switches back and forth from the language of the session, not from the saved one' {
            $run = & $script:drive -Answers '6', '6', '6', '0'
            @($run.Log | Where-Object { $_ -like 'CONFIG|*' }) | Should -Be @('CONFIG|en', 'CONFIG|uk', 'CONFIG|en')
        }

        It 'uses the new language for every later run, and reads the saved language only once' {
            $run = & $script:drive -Answers '6', '1', '', '0'
            $ids = & $script:ids $null
            $order = @(
                'CONFIG|en'
                (& $script:say '' $script:en['Tui.Running'])
                "CHECK|en|$ids"
                (& $script:say 'Red' "[$($script:en['Status.Critical'])] Print spooler — PRN-2F-HP")
                "ASK|$($script:en['Tui.PressEnter'])"
            )
            & $script:inOrder $run.Log $order | Should -Be 'ok'
            @($run.Log | Where-Object { $_ -like 'CHECK|*' }) | Should -Be @("CHECK|en|$ids")
            Should -Invoke Get-ChekapConfig -ModuleName Chekap -Times 1 -Exactly
        }

        It 'exports the report in the new language' {
            $run = & $script:drive -Answers '6', '5', '', '0'
            @($run.Log | Where-Object { $_ -like 'EXPORT|*' }) | Should -Be @("EXPORT|en|$($script:reportFolder)|2|PC-042|Html,Json")
            $run.Log | Should -Contain (& $script:say 'Green' ($script:en['Tui.ReportSaved'] -f $script:reportHtml))
        }

        It 'still switches for the session when the setting cannot be saved, and says so after the next Clear-Host' {
            Mock Set-ChekapConfig { throw 'Access to the path is denied.' } -ModuleName Chekap
            $run = & $script:drive -Answers '6', '1', '', '0'
            # The second screen up to its prompt; what the run printed after the prompt is not part of the check.
            $second = & $script:screen $run.Log 1
            $second = $second[0..([array]::IndexOf($second, "ASK|$($script:en['Tui.Prompt'])"))]
            $second[-3] | Should -Be (& $script:say 'Green' $script:en['Tui.LanguageSet'])
            $second[-2] | Should -Be (& $script:say 'Yellow' ($script:en['Tui.LanguageNotSaved'] -f 'Access to the path is denied.'))
            $second[-1] | Should -Be "ASK|$($script:en['Tui.Prompt'])"
            @($run.Log | Where-Object { $_ -like 'CHECK|*' }) | Should -Be @("CHECK|en|$(& $script:ids $null)")
        }
    }

    Context 'the end of the input' {
        It 'leaves the menu when Read-Host returns $null (closed input) instead of drawing it for ever' {
            $run = & $script:drive -Answers @($null)
            @($run.Log | Where-Object { $_ -eq 'CLEAR' }).Count | Should -Be 1
        }
    }
}

Describe 'Start-Chekap with the real Set-ChekapConfig' {
    BeforeEach {
        & $script:startMocks -RealConfig
        # The settings folder would have to be created below a file, so the real write fails the way a blocked or read-only %APPDATA% does.
        $script:blocker = Join-Path $TestDrive 'blocker'
        Set-Content -LiteralPath $script:blocker -Value 'not a folder'
        Mock Get-ChekapConfigPath { Join-Path $script:blocker 'Chekap/config.json' } -ModuleName Chekap
    }

    It 'survives a failed save, says so, and uses the new language for the next run' {
        $run = & $script:drive -Answers '6', '1', '', '0'
        # The error text comes from the system, so the line is matched around the {0} of the message.
        $parts = $script:en['Tui.LanguageNotSaved'] -split '\{0\}'
        $notSaved = '^' + [regex]::Escape("SAY|Yellow|$($parts[0])") + '.+' + [regex]::Escape($parts[1]) + '$'
        $second = & $script:screen $run.Log 1
        $second = $second[0..([array]::IndexOf($second, "ASK|$($script:en['Tui.Prompt'])"))]
        $second[-3] | Should -Be (& $script:say 'Green' $script:en['Tui.LanguageSet'])
        $second[-2] | Should -Match $notSaved
        $second[-1] | Should -Be "ASK|$($script:en['Tui.Prompt'])"
        @($run.Log | Where-Object { $_ -like 'CHECK|*' }) | Should -Be @("CHECK|en|$(& $script:ids $null)")
        $run.Log[-1] | Should -Be "ASK|$($script:en['Tui.Prompt'])"
        # It was the real command that ran and failed: it asked for its path, and wrote nothing.
        Should -Invoke Get-ChekapConfigPath -ModuleName Chekap -Times 1 -Exactly
        Test-Path -LiteralPath (Join-Path $script:blocker 'Chekap') | Should -BeFalse
    }
}

Describe 'Tui strings' {
    BeforeAll {
        $script:code = (Get-Content -LiteralPath (Join-Path $script:root 'Chekap/Public/Start-Chekap.ps1'), (Join-Path $script:root 'Chekap/Private/Show-ChekapResult.ps1') -Raw -Encoding UTF8) -join "`n"
    }

    It 'has the menu items 0 to 6 in both languages' {
        foreach ($table in $script:en, $script:uk) {
            foreach ($item in 0..6) { $table.ContainsKey("Tui.Menu.$item") | Should -BeTrue }
        }
    }

    It 'the NotAdmin line fits one 80-column console line in both languages' {
        $script:en['Tui.NotAdmin'].Length | Should -BeLessOrEqual 79
        $script:uk['Tui.NotAdmin'].Length | Should -BeLessOrEqual 79
    }

    It 'every Tui key the code asks for exists in both languages' {
        $used = [regex]::Matches($script:code, "'(Tui\.[A-Za-z]+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $used | Should -Not -BeNullOrEmpty
        $missing = foreach ($key in $used) {
            if (-not $script:en.ContainsKey($key)) { "$key missing in en-US" }
            if (-not $script:uk.ContainsKey($key)) { "$key missing in uk-UA" }
        }
        $missing | Should -BeNullOrEmpty
    }

    It 'every Tui key in the tables is used by the code' {
        $unused = $script:en.Keys | Where-Object { $_ -like 'Tui.*' -and $_ -notlike 'Tui.Menu.*' -and $script:code -notmatch [regex]::Escape("'$_'") }
        $unused | Should -BeNullOrEmpty
    }
}

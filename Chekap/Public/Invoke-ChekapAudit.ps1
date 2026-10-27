function Invoke-ChekapAudit {
    <#
    .SYNOPSIS
    Runs the Chekap checks on this PC and, with -OutputPath, saves an HTML and a JSON report.
    .DESCRIPTION
    Runs all checks, or the chosen categories or check IDs, and returns one Chekap.CheckResult object per finding.
    With -OutputPath it also writes the report files Chekap-<ComputerName>-<yyyyMMdd-HHmm>.html and .json.
    The HTML report is one file with no external resources: open it in any browser, print it or send it to a colleague.
    It lists the PC passport (system, model, memory, IP addresses), the findings sorted from the worst to the best
    and the data each finding is based on. The JSON file holds the same data for scripts. The checks only read data;
    a check that needs administrator rights is reported as Skipped when PowerShell is not elevated.
    Without -OutputPath no file is written.
    .PARAMETER Category
    Run only the checks of these categories: System, Network, Printing.
    .PARAMETER CheckId
    Run only these checks. Exact IDs or wildcards, for example NET-DNS-001 or PRN-*.
    .PARAMETER Language
    Language of the texts: uk or en. By default the saved setting or the system language.
    .PARAMETER OutputPath
    Folder for the report files. It is created if it does not exist; a relative path is relative to the current location.
    .PARAMETER Format
    File formats to write: Html, Json or both (the default).
    .PARAMETER Note
    A line of text for the top of the report, for example the complaint or the ticket number.
    .EXAMPLE
    Invoke-ChekapAudit -Language en -OutputPath C:\Reports -Note 'Ticket 4711: prints slowly'
    .EXAMPLE
    Invoke-ChekapAudit -Category Network, Printing -OutputPath .\reports -Format Html -Verbose
    #>
    [CmdletBinding()]
    [OutputType('Chekap.CheckResult')]
    param(
        [ValidateSet('System', 'Network', 'Printing')]
        [string[]]$Category,

        [string[]]$CheckId,

        [ValidateSet('uk', 'en')]
        [string]$Language,

        [string]$OutputPath,

        [ValidateSet('Html', 'Json')]
        [string[]]$Format = @('Html', 'Json'),

        [string]$Note
    )

    $lang = Resolve-ChekapLanguage -Language $Language
    $checks = @(Select-ChekapCheck -Category $Category -CheckId $CheckId -Language $lang)
    # An unknown ID has already been reported by a warning; there is nothing to run and no report to write.
    if ($checks.Count -eq 0) { return }
    $results = @(Invoke-ChekapCheck -Check $checks -Language $lang)

    if ($OutputPath) {
        $strings = Get-ChekapStringTable -Language $lang
        $files = Export-ChekapReport -Result $results -Language $lang -OutputPath $OutputPath -Format $Format -Note $Note -SystemInfo (Get-ChekapSystemInfo)
        foreach ($file in $files) {
            Write-Verbose (Get-ChekapText -Strings $strings -Key 'Core.Verbose.ReportWritten' -FormatArgs $file.FullName)
        }
    }
    $results
}

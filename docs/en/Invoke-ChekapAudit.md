---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Invoke-ChekapAudit

## SYNOPSIS
Runs the Chekap checks on this PC and, with -OutputPath, saves an HTML and a JSON report.

## SYNTAX

```
Invoke-ChekapAudit [[-Category] <String[]>] [[-CheckId] <String[]>] [[-Language] <String>]
 [[-OutputPath] <String>] [[-Format] <String[]>] [[-Note] <String>] [<CommonParameters>]
```

## DESCRIPTION
Runs all checks, or only the chosen categories or check IDs, and returns one Chekap.CheckResult object for each finding. The objects can be filtered in PowerShell, and with -OutputPath the result is also saved as a report.

With -OutputPath the command writes two files to that folder: Chekap-\<ComputerName\>-\<yyyyMMdd-HHmm\>.html and the same name ending in .json, for example Chekap-PC-042-20261029-1430.html. The folder is created before the checks start, so a wrong path fails at once. A report is never overwritten: if the files of this minute already exist, the new ones get the suffix -2, -3 and so on. The full paths of the files are printed only with -Verbose. Without -OutputPath no file is written.

The HTML report is one file with no external resources: it works without internet, opens in any browser, can be printed or sent to a colleague, and sends nothing anywhere. It starts with the PC passport (system, model, processor, memory, uptime, IPv4 addresses, domain or workgroup), then lists the findings from the worst to the best with filters by status and category, and shows the data each finding is based on. The JSON file holds the same data for scripts. The report contains the name of the PC, its IP addresses and printer names, so look through it before you send it outside your organization.

The checks only read data. None of them changes the PC, and none of the current checks needs administrator rights. A check that does need them is reported as Skipped when PowerShell is not elevated. Every result has a Status: OK, Warning, Critical, Error (the check itself could not finish) or Skipped (the check cannot run or does not apply, for example there is no battery). The Status values are always in English, so scripts work in any language; the HTML report shows them as words in the language of the report.

The findings and the report are in one language: the one from the Language parameter if you give it, otherwise the one saved with Set-ChekapConfig, otherwise the language of the Windows interface.

## EXAMPLES

### Example 1: Run all checks and save a report
```powershell
Invoke-ChekapAudit -OutputPath C:\Reports
```

Runs every check and saves an HTML and a JSON report to C:\Reports, for example Chekap-PC-042-20261029-1430.html. The findings are also written to the output.

### Example 2: A report in English with a note
```powershell
Invoke-ChekapAudit -Language en -OutputPath C:\Reports -Note 'PC-042: does not print'
```

Saves a report in English with the line "PC-042: does not print" at the top.

### Example 3: Only some categories, only HTML
```powershell
Invoke-ChekapAudit -Category Network, Printing -OutputPath .\reports -Format Html -Verbose
```

Runs only the Network and Printing checks and saves only the HTML report to the reports folder under the current location. With -Verbose the command prints the path of the file.

### Example 4: Count the findings without a report
```powershell
Invoke-ChekapAudit | Group-Object Status | Select-Object Name, Count
```

Runs every check, saves nothing and shows how many findings there are for each status.

## PARAMETERS

### -Category
Run only the checks of these categories: System, Network or Printing. You can give several. Combined with CheckId, a check must match both.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CheckId
Run only these checks. Exact IDs or wildcards, for example NET-DNS-001 or PRN-*. An ID that matches no check gives a warning. If no check is selected the command returns nothing and writes no report.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -Language
Language of the findings and the report: uk (Ukrainian) or en (English). Without it Chekap uses the language saved with Set-ChekapConfig, and without a saved language the language of the Windows interface.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputPath
Folder for the report files. It is created if it does not exist. A relative path is relative to the current location. A report is never overwritten: if the files of this minute already exist, the new ones get the suffix -2, -3 and so on. If the folder cannot be created or a file cannot be written, the command stops with an error.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Format
File formats to write: Html, Json or both. By default both.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: @('Html', 'Json')
Accept pipeline input: False
Accept wildcard characters: False
```

### -Note
A line of text for the top of the report, for example the complaint or the ticket number. It is shown in the HTML report and saved in the JSON file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
The command does not take objects from the pipeline.

## OUTPUTS

### Chekap.CheckResult
One object for each finding with the properties CheckId, Category, ComputerName, Status, Target, Title, Details, Recommendation, FixId, FixRiskLevel, Evidence, References and Timestamp. CheckId is a stable ID that is never translated. Evidence holds the raw data the finding is based on. FixId and FixRiskLevel are empty in this version.

## NOTES

## RELATED LINKS

[Test-ChekapHealth](Test-ChekapHealth.md)

[Test-ChekapNetwork](Test-ChekapNetwork.md)

[Test-ChekapPrinting](Test-ChekapPrinting.md)

[Get-ChekapCheck](Get-ChekapCheck.md)

[Start-Chekap](Start-Chekap.md)

---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Test-ChekapHealth

## SYNOPSIS
Checks the health of this PC: uptime, pending restart, free disk space, load, memory, crashes and battery.

## SYNTAX

```
Test-ChekapHealth [[-Language] <String>] [[-CheckId] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Runs the System checks and returns one Chekap.CheckResult object for each finding. A check can report more than one finding, for example one for each battery. The checks look at: uptime, a restart that is waiting, free space on the system drive, CPU and memory load, memory and the page file, blue screen crashes, unexpected shutdowns, application crashes, programs in startup and battery wear.

The checks only read data. They do not change settings and need no administrator rights, but some checks get less data without them: the folder of crash dumps can be read only by administrators. The battery check asks powercfg for a report in a temporary file in the %TEMP% folder and deletes the file at once.

Every result has a Status: OK, Warning, Critical, Error (the check itself could not finish) or Skipped (the check does not apply to this PC, for example there is no battery). The Status values are always in English, so scripts work in any language. Title, Details and Recommendation are in the language of the texts: the one from the Language parameter if you give it, otherwise the one saved with Set-ChekapConfig, otherwise the language of the Windows interface.

## EXAMPLES

### Example 1: Run all System checks
```powershell
Test-ChekapHealth
```

Runs every System check and shows the findings in a table: status, check ID, target and title.

### Example 2: Show only what needs attention
```powershell
Test-ChekapHealth -Language en | Where-Object Status -ne 'OK' | Format-List CheckId, Details, Recommendation
```

Shows the findings that are not OK in English, each with what was found and what to do.

### Example 3: Run two checks
```powershell
Test-ChekapHealth -CheckId SYS-DISK-001, SYS-MEMORY-001 | Format-List
```

Runs only the disk space and the memory checks and shows every property of their results.

## PARAMETERS

### -Language
Language of the texts: uk (Ukrainian) or en (English). Without it Chekap uses the language saved with Set-ChekapConfig, and without a saved language the language of the Windows interface.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CheckId
Run only these checks. Exact IDs or wildcards, for example SYS-DISK-001 or SYS-B*. Only System checks are considered here, so an ID of another category selects nothing. An ID that matches no check at all gives a warning. If no check is selected the command returns nothing.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
The command does not take objects from the pipeline.

## OUTPUTS

### Chekap.CheckResult
One object for each finding with the properties CheckId, Category, ComputerName, Status, Target, Title, Details, Recommendation, FixId, FixRiskLevel, Evidence, References and Timestamp. FixId and FixRiskLevel are empty in this version.

## NOTES

## RELATED LINKS

[Invoke-ChekapAudit](Invoke-ChekapAudit.md)

[Test-ChekapNetwork](Test-ChekapNetwork.md)

[Test-ChekapPrinting](Test-ChekapPrinting.md)

[Get-ChekapCheck](Get-ChekapCheck.md)

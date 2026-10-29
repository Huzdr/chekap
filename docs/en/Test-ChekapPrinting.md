---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Test-ChekapPrinting

## SYNOPSIS
Checks printing on this PC: the Print Spooler service, print queues, printer ports, the default printer, drivers, RPC protection of shared printers and scanners.

## SYNTAX

```
Test-ChekapPrinting [[-Language] <String>] [[-CheckId] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Runs the Printing checks and returns one Chekap.CheckResult object for each finding. The checks look at: the Print Spooler service, jobs stuck in print queues, whether network printers answer on their port, the default printer, printer drivers that no printer uses, the RPC protection of the Spooler and printers shared from a workstation (the cause of errors 0x0000011b and 0x00000709 after security updates), and imaging devices (scanner or camera) with the services they need.

The checks only read data. None of them changes the PC or needs administrator rights. For network printers and print servers they open a short TCP connection to the port of each printer, with a time limit for every printer and for all of them together. Virtual printers such as PDF are not checked. The names of documents and users in print queues are not collected. Unused printer drivers are only reported, never removed.

Every result has a Status: OK, Warning, Critical, Error (the check itself could not finish) or Skipped (the check cannot run or does not apply, for example there is no scanner or the Print Spooler is stopped). The Status values are always in English, so scripts work in any language. Title, Details and Recommendation are in the language of the texts: the one from the Language parameter if you give it, otherwise the one saved with Set-ChekapConfig, otherwise the language of the Windows interface.

## EXAMPLES

### Example 1: Run all Printing checks
```powershell
Test-ChekapPrinting
```

Runs every Printing check and shows the findings in a table: status, check ID, target and title.

### Example 2: Show only what needs attention
```powershell
Test-ChekapPrinting -Language en | Where-Object Status -in 'Warning', 'Critical' | Format-List CheckId, Target, Details, Recommendation
```

Shows the warnings and critical findings in English, each with what was found and what to do.

### Example 3: Check the Spooler and the printer ports
```powershell
Test-ChekapPrinting -CheckId PRN-SPOOLER-001, PRN-PORT-* | Format-List
```

Runs the Print Spooler check and the printer port check and shows every property of their results.

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
Run only these checks. Exact IDs or wildcards, for example PRN-QUEUE-001 or PRN-PORT-*. Only Printing checks are considered here, so an ID of another category selects nothing. An ID that matches no check at all gives a warning. If no check is selected the command returns nothing.

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

[Test-ChekapHealth](Test-ChekapHealth.md)

[Test-ChekapNetwork](Test-ChekapNetwork.md)

[Get-ChekapCheck](Get-ChekapCheck.md)

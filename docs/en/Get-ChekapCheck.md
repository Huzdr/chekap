---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Get-ChekapCheck

## SYNOPSIS
Lists the checks that Chekap knows.

## SYNTAX

```
Get-ChekapCheck [[-Category] <String[]>] [[-Language] <String>] [<CommonParameters>]
```

## DESCRIPTION
Returns one Chekap.CheckInfo object for each check: its ID, category, title, whether it needs administrator rights, the minimum Windows build and the links to the documentation it is based on.

No check is run and nothing is changed, so the command answers at once. Use it to see what Invoke-ChekapAudit would run and to find the IDs for the CheckId parameter of the other commands.

The titles are in the language you give with Language. Without it Chekap uses the language saved with Set-ChekapConfig, and without a saved language the language of the Windows interface: Ukrainian if that is Ukrainian, English otherwise.

## EXAMPLES

### Example 1: List all checks
```powershell
Get-ChekapCheck
```

Shows every check in a table: ID, category, whether it needs administrator rights and title.

### Example 2: Printing checks in Ukrainian
```powershell
Get-ChekapCheck -Category Printing -Language uk
```

Shows only the Printing checks, with titles in Ukrainian.

## PARAMETERS

### -Category
Only the checks of these categories: System, Network or Printing. You can give several. A name that matches no category returns nothing.

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

### -Language
Language of the titles: uk (Ukrainian) or en (English). Without it Chekap uses the language saved with Set-ChekapConfig, and without a saved language the language of the Windows interface.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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

### Chekap.CheckInfo
One object for each check with the properties Id, Category, Title, RequiresAdmin, MinBuild and References.

## NOTES

## RELATED LINKS

[Invoke-ChekapAudit](Invoke-ChekapAudit.md)

[Set-ChekapConfig](Set-ChekapConfig.md)

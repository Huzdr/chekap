---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Set-ChekapConfig

## SYNOPSIS
Saves the Chekap settings.

## SYNTAX

```
Set-ChekapConfig [-Language] <String> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Writes the settings file %APPDATA%\Chekap\config.json for the current user and creates its folder if needed. The only setting today is the language of the checks, the reports and the menu. The file is plain UTF-8 text. The command needs no administrator rights and changes nothing for other users of the PC.

A Language parameter given directly to a command always wins over the saved setting. Use Get-ChekapConfig to see what is saved.

Supports -WhatIf and -Confirm. With -Verbose the command prints the path of the file it wrote.

## EXAMPLES

### Example 1: Use Ukrainian from now on
```powershell
Set-ChekapConfig -Language uk
```

Saves Ukrainian. Every Chekap command and the menu now start in Ukrainian, unless a command is given its own Language.

### Example 2: See what would be written
```powershell
Set-ChekapConfig -Language en -WhatIf
```

Shows the file that would be written and writes nothing.

## PARAMETERS

### -Language
Language of the checks, reports and messages: uk (Ukrainian) or en (English). Without a saved language Chekap follows the language of the Windows interface.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
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

### None
The command returns nothing.

## NOTES

## RELATED LINKS

[Get-ChekapConfig](Get-ChekapConfig.md)

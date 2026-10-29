---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Get-ChekapConfig

## SYNOPSIS
Gets the Chekap settings.

## SYNTAX

```
Get-ChekapConfig [<CommonParameters>]
```

## DESCRIPTION
Reads the settings file %APPDATA%\Chekap\config.json of the current user and returns a Chekap.Config object with one property, Language. Language is uk or en, or empty if no language has been saved. In that case Chekap follows the language of the Windows interface: Ukrainian if that is Ukrainian, English otherwise.

The command only reads. A missing, unreadable or invalid file, or a language other than uk and en, gives the defaults, so the command never fails because of the settings file.

## EXAMPLES

### Example 1: Show the saved settings
```powershell
Get-ChekapConfig
```

Shows the settings. Language is empty if none has been saved.

### Example 2: Save a language only if none is saved
```powershell
if (-not (Get-ChekapConfig).Language) { Set-ChekapConfig -Language en }
```

Saves English when no language has been saved yet and leaves an existing choice alone.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
The command does not take objects from the pipeline.

## OUTPUTS

### Chekap.Config
An object with the property Language.

## NOTES

## RELATED LINKS

[Set-ChekapConfig](Set-ChekapConfig.md)

---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Start-Chekap

## SYNOPSIS
Opens a console menu for running the Chekap checks without typing commands.

## SYNTAX

```
Start-Chekap [<CommonParameters>]
```

## DESCRIPTION
Shows a numbered menu in the PowerShell window: 1 all checks, 2 System checks, 3 Network checks, 4 Printing checks, 5 all checks and a report file (HTML and JSON), 6 switch between Ukrainian and English, 0 exit. After a run the findings are printed from the worst to the best, each with its status in words, what was found and what to do. Press Enter to go back to the menu.

Item 5 saves the report to the Chekap folder inside your Documents folder, never overwriting an earlier report, and opens the HTML file in the default browser. Item 6 saves the chosen language with Set-ChekapConfig, so the next start uses it. At the start the menu uses the saved language or, without one, the language of the Windows interface.

The checks only read data. The menu writes only the report files (item 5) and the language setting (item 6). Today none of the checks needs administrator rights, but with them a few see more, for example the folder of crash dumps. A check that does need them is reported as Skipped when PowerShell is not elevated.

The offline package has the file Start-Chekap.cmd next to the Chekap folder. Double-click it to start the menu without installing anything. It asks for administrator rights (the Windows UAC prompt); if you decline, the menu still opens, without them. The window closes when you leave the menu.

The menu reads from the console, so it needs an interactive PowerShell window. If the input ends, the menu ends.

## EXAMPLES

### Example 1: Open the menu
```powershell
Start-Chekap
```

Opens the menu. Chekap must be installed or imported.

### Example 2: Start from an unpacked offline package
```powershell
Import-Module .\Chekap\Chekap.psd1; Start-Chekap
```

Loads the module from the Chekap folder in the current location and opens the menu, without installing anything. This is what Start-Chekap.cmd does.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
The command does not take objects from the pipeline.

## OUTPUTS

### None
The menu writes to the console and returns nothing.

## NOTES

## RELATED LINKS

[Invoke-ChekapAudit](Invoke-ChekapAudit.md)

[Set-ChekapConfig](Set-ChekapConfig.md)

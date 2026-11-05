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
Start-Chekap [-NoBanner] [<CommonParameters>]
```

## DESCRIPTION
Shows a numbered menu in the PowerShell window: 1 all checks, 2 System: PC health, 3 Network, 4 Printing, 5 all checks and a report file (HTML and JSON), 6 switch between Ukrainian and English, 0 exit. After a run the menu prints the number of findings for each status and then every finding that is not OK, the most serious first, with its status label, what was found and the recommendation. Press Enter to go back to the menu.

Item 5 saves the report to the Chekap folder inside your Documents folder, never overwriting an earlier report, and opens the HTML file in the default browser. Item 6 saves the chosen language with Set-ChekapConfig, so the next start uses it. At the start the menu uses the saved language or, without one, the language of the Windows interface.

The checks only read data. The menu writes only the report files (item 5) and the language setting (item 6). Today none of the checks needs administrator rights, but with them some checks get more data, for example from the folder of crash dumps. A check that does need them is reported as Skipped when PowerShell is not elevated.

The offline package has the file Start-Chekap.cmd next to the Chekap folder. Double-click it to start the menu without installing anything. The menu runs as the signed-in user and does not ask for administrator rights, so the checks see the printers, the proxy and the settings of that user. The folder of crash dumps cannot be read without them: if you need it, start PowerShell as administrator and run Import-Module .\Chekap\Chekap.psd1; Start-Chekap. The window closes when you leave the menu.

The menu reads from the console, so it needs an interactive PowerShell window. If the input ends, the menu ends.

At the start the author's banner is shown above the menu. It appears only in an interactive window, never in a remote session; -NoBanner leaves it out.

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

### Example 3: Open the menu without the banner
```powershell
Start-Chekap -NoBanner
```

Opens the menu straight away, without the banner above it.

## PARAMETERS

### -NoBanner
Opens the menu without the author's banner above it.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
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
The menu writes to the console and returns nothing.

## NOTES

## RELATED LINKS

[Invoke-ChekapAudit](Invoke-ChekapAudit.md)

[Set-ChekapConfig](Set-ChekapConfig.md)

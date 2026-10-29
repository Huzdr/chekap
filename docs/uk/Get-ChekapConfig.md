---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Get-ChekapConfig

## SYNOPSIS
Показує збережені налаштування Chekap.

## SYNTAX

```
Get-ChekapConfig [<CommonParameters>]
```

## DESCRIPTION
Читає файл налаштувань %APPDATA%\Chekap\config.json поточного користувача й повертає об'єкт Chekap.Config з однією властивістю — Language. Language має значення uk або en, а якщо мову не збережено, то порожнє. Тоді Chekap бере мову інтерфейсу Windows: українську, коли інтерфейс українською, і англійську в решті випадків.

Команда лише читає. Якщо файлу немає, його не вдається прочитати чи він пошкоджений, або в ньому вказано іншу мову, ніж uk чи en, команда повертає типові значення, тож ніколи не завершується помилкою через файл налаштувань.

## EXAMPLES

### Приклад 1: Показати збережені налаштування
```powershell
Get-ChekapConfig
```

Показує налаштування. Якщо мову не збережено, Language порожнє.

### Приклад 2: Зберегти мову, лише якщо її ще не збережено
```powershell
if (-not (Get-ChekapConfig).Language) { Set-ChekapConfig -Language en }
```

Зберігає англійську, коли мову ще не збережено, і не чіпає вже зроблений вибір.

## PARAMETERS

### CommonParameters
Команда підтримує загальні параметри: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction і -WarningVariable. Докладніше: [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
Команда не приймає об'єктів із конвеєра.

## OUTPUTS

### Chekap.Config
Об'єкт із властивістю Language.

## NOTES

## RELATED LINKS

[Set-ChekapConfig](Set-ChekapConfig.md)

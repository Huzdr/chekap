---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Set-ChekapConfig

## SYNOPSIS
Зберігає налаштування Chekap.

## SYNTAX

```
Set-ChekapConfig [-Language] <String> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Записує файл налаштувань %APPDATA%\Chekap\config.json для поточного користувача й за потреби створює його теку. Поки що єдине налаштування — мова перевірок, звітів і меню. Файл — звичайний текст UTF-8. Права адміністратора не потрібні, інших користувачів ПК команда не зачіпає.

Параметр Language, вказаний безпосередньо в команді, завжди має перевагу над збереженим налаштуванням. Що збережено, покаже Get-ChekapConfig.

Підтримує -WhatIf і -Confirm. З -Verbose команда виводить шлях до записаного файлу.

## EXAMPLES

### Приклад 1: Відтепер працювати українською
```powershell
Set-ChekapConfig -Language uk
```

Зберігає українську. Відтепер усі команди Chekap і меню працюють українською, якщо команді не вказати власний Language.

### Приклад 2: Подивитися, що буде записано
```powershell
Set-ChekapConfig -Language en -WhatIf
```

Показує, який файл було б записано, і нічого не записує.

## PARAMETERS

### -Language
Мова перевірок, звітів і повідомлень: uk (українська) або en (англійська). Без збереженої мови Chekap бере мову інтерфейсу Windows.

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
Показує, що відбулося б під час виконання команди.
Сама команда не виконується.

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
Перед виконанням команди просить підтвердження.

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
Команда підтримує загальні параметри: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction і -WarningVariable. Докладніше: [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
Команда не приймає об'єктів із конвеєра.

## OUTPUTS

### None
Команда нічого не повертає.

## NOTES

## RELATED LINKS

[Get-ChekapConfig](Get-ChekapConfig.md)

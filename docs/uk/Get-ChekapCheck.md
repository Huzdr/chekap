---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Get-ChekapCheck

## SYNOPSIS
Показує перелік перевірок, які знає Chekap.

## SYNTAX

```
Get-ChekapCheck [[-Category] <String[]>] [[-Language] <String>] [<CommonParameters>]
```

## DESCRIPTION
Повертає по одному об'єкту Chekap.CheckInfo для кожної перевірки: її ідентифікатор, категорію, назву, чи потрібні права адміністратора, мінімальну збірку Windows і посилання на документацію, на якій вона ґрунтується.

Жодна перевірка не виконується й нічого не змінюється, тож команда відповідає миттєво. Скористайтеся нею, щоб побачити, що запустить Invoke-ChekapAudit, і дізнатися ідентифікатори для параметра CheckId інших команд.

Назви показуються мовою, яку вказано в параметрі Language. Без нього Chekap бере мову, збережену командою Set-ChekapConfig, а якщо її немає, мову інтерфейсу Windows: українську, коли інтерфейс українською, і англійську в решті випадків.

## EXAMPLES

### Приклад 1: Усі перевірки
```powershell
Get-ChekapCheck
```

Показує всі перевірки в таблиці: ідентифікатор, категорію, чи потрібні права адміністратора й назву.

### Приклад 2: Перевірки друку українською
```powershell
Get-ChekapCheck -Category Printing -Language uk
```

Показує лише перевірки друку, назви подано українською.

## PARAMETERS

### -Category
Лише перевірки цих категорій: System (стан ПК), Network (мережа) або Printing (друк). Можна вказати кілька. Будь-яку іншу назву команда відхилить.

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
Мова назв: uk (українська) або en (англійська). Без цього параметра Chekap бере мову, збережену командою Set-ChekapConfig, а якщо її немає, мову інтерфейсу Windows.

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
Команда підтримує загальні параметри: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction і -WarningVariable. Докладніше: [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
Команда не приймає об'єктів із конвеєра.

## OUTPUTS

### Chekap.CheckInfo
По одному об'єкту на кожну перевірку з властивостями Id, Category, Title, RequiresAdmin, MinBuild і References.

## NOTES

## RELATED LINKS

[Invoke-ChekapAudit](Invoke-ChekapAudit.md)

[Set-ChekapConfig](Set-ChekapConfig.md)

---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Test-ChekapPrinting

## SYNOPSIS
Перевіряє друк на цьому ПК: службу Print Spooler, черги друку, порти принтерів, принтер за замовчуванням, драйвери, захист RPC спільних принтерів і сканери.

## SYNTAX

```
Test-ChekapPrinting [[-Language] <String>] [[-CheckId] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Виконує перевірки категорії Printing і повертає по одному об'єкту Chekap.CheckResult на кожну знахідку. Перевіряється таке: служба Print Spooler, завислі завдання в чергах друку, чи відповідають мережеві принтери на своєму порту, принтер за замовчуванням, драйвери принтерів, які не використовує жоден принтер, захист RPC служби Print Spooler і принтери, надані в спільний доступ з робочої станції (причина помилок 0x0000011b і 0x00000709 після оновлень безпеки), а також пристрої обробки зображень (сканер чи камера) і потрібні їм служби.

Перевірки лише читають дані. Жодна з них не змінює ПК і не потребує прав адміністратора. До мережевих принтерів і серверів друку вони відкривають коротке TCP-з'єднання з портом кожного принтера; на кожен принтер і на всі разом відведено обмежений час. Віртуальні принтери, як-от PDF, не перевіряються. Назви документів та імена користувачів із черг друку не збираються. Драйвери, які ніхто не використовує, лише показуються, але не видаляються.

Кожен результат має Status: OK, Warning, Critical, Error (перевірка не змогла завершитися) або Skipped (перевірка не може виконатися або не стосується цього ПК, наприклад, сканера немає або службу Print Spooler зупинено). Значення Status завжди англійською, щоб скрипти працювали за будь-якої мови. Title, Details і Recommendation подаються мовою текстів: мовою з параметра Language; якщо його не вказано — мовою, збереженою командою Set-ChekapConfig; якщо й її немає — мовою інтерфейсу Windows.

## EXAMPLES

### Приклад 1: Виконати всі перевірки друку
```powershell
Test-ChekapPrinting
```

Виконує всі перевірки категорії Printing і показує знахідки в таблиці: статус, ідентифікатор перевірки, об'єкт і назву.

### Приклад 2: Показати лише те, що потребує уваги
```powershell
Test-ChekapPrinting -Language en | Where-Object Status -in 'Warning', 'Critical' | Format-List CheckId, Target, Details, Recommendation
```

Показує англійською знахідки зі статусом Warning і Critical: що знайдено й що робити.

### Приклад 3: Перевірити службу Print Spooler і порти принтерів
```powershell
Test-ChekapPrinting -CheckId PRN-SPOOLER-001, PRN-PORT-* | Format-List
```

Виконує перевірку служби Print Spooler і перевірку портів принтерів та показує всі властивості їхніх результатів.

## PARAMETERS

### -Language
Мова текстів: uk (українська) або en (англійська). Без цього параметра Chekap бере мову, збережену командою Set-ChekapConfig, а якщо її немає, мову інтерфейсу Windows.

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
Виконати лише ці перевірки. Точні ідентифікатори або шаблони, наприклад PRN-QUEUE-001 чи PRN-PORT-*. Тут враховуються лише перевірки категорії Printing, тож ідентифікатор іншої категорії нічого не вибере. Якщо ідентифікатор не збігається з жодною перевіркою Chekap, команда видає попередження. Якщо жодної перевірки не вибрано, команда нічого не повертає.

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
Команда підтримує загальні параметри: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction і -WarningVariable. Докладніше: [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
Команда не приймає об'єктів із конвеєра.

## OUTPUTS

### Chekap.CheckResult
По одному об'єкту на кожну знахідку з властивостями CheckId, Category, ComputerName, Status, Target, Title, Details, Recommendation, FixId, FixRiskLevel, Evidence, References і Timestamp. FixId і FixRiskLevel у цій версії порожні.

## NOTES

## RELATED LINKS

[Invoke-ChekapAudit](Invoke-ChekapAudit.md)

[Test-ChekapHealth](Test-ChekapHealth.md)

[Test-ChekapNetwork](Test-ChekapNetwork.md)

[Get-ChekapCheck](Get-ChekapCheck.md)

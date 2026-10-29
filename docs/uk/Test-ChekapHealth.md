---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Test-ChekapHealth

## SYNOPSIS
Перевіряє стан цього ПК: час безперервної роботи, очікуване перезавантаження, вільне місце на диску, навантаження, пам'ять, аварії та батарею.

## SYNTAX

```
Test-ChekapHealth [[-Language] <String>] [[-CheckId] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Виконує перевірки категорії System і повертає по одному об'єкту Chekap.CheckResult на кожну знахідку. Одна перевірка може дати кілька знахідок, наприклад по одній на кожну батарею. Перевіряється таке: час безперервної роботи, очікуване перезавантаження, вільне місце на системному диску, навантаження процесора й пам'яті, пам'ять і файл підкачки, аварії із синім екраном, аварійні вимкнення, збої програм, програми в автозапуску та знос батареї.

Перевірки лише читають дані. Вони нічого не змінюють у налаштуваннях і не потребують прав адміністратора, але без них частина перевірок отримує менше даних: теку з дампами аварій можуть читати лише адміністратори. Перевірка батареї просить у powercfg звіт у тимчасовому файлі в теці %TEMP% і одразу видаляє цей файл.

Кожен результат має Status: OK, Warning, Critical, Error (перевірка не змогла завершитися) або Skipped (перевірка не стосується цього ПК, наприклад, немає батареї). Значення Status завжди англійською, щоб скрипти працювали за будь-якої мови. Title, Details і Recommendation подаються мовою текстів: мовою з параметра Language; якщо його не вказано — мовою, збереженою командою Set-ChekapConfig; якщо й її немає — мовою інтерфейсу Windows.

## EXAMPLES

### Приклад 1: Виконати всі перевірки стану ПК
```powershell
Test-ChekapHealth
```

Виконує всі перевірки категорії System і показує знахідки в таблиці: статус, ідентифікатор перевірки, об'єкт і назву.

### Приклад 2: Показати лише те, що потребує уваги
```powershell
Test-ChekapHealth -Language en | Where-Object Status -ne 'OK' | Format-List CheckId, Details, Recommendation
```

Показує англійською знахідки, які не мають статусу OK: що знайдено й що робити.

### Приклад 3: Виконати дві перевірки
```powershell
Test-ChekapHealth -CheckId SYS-DISK-001, SYS-MEMORY-001 | Format-List
```

Виконує лише перевірки вільного місця на диску та пам'яті й показує всі властивості їхніх результатів.

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
Виконати лише ці перевірки. Точні ідентифікатори або шаблони, наприклад SYS-DISK-001 чи SYS-B*. Тут враховуються лише перевірки категорії System, тож ідентифікатор іншої категорії нічого не вибере. Якщо ідентифікатор не збігається з жодною перевіркою Chekap, команда видає попередження. Якщо жодної перевірки не вибрано, команда нічого не повертає.

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

[Test-ChekapNetwork](Test-ChekapNetwork.md)

[Test-ChekapPrinting](Test-ChekapPrinting.md)

[Get-ChekapCheck](Get-ChekapCheck.md)

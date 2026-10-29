---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Invoke-ChekapAudit

## SYNOPSIS
Виконує перевірки Chekap на цьому ПК і з параметром -OutputPath зберігає звіт у форматах HTML і JSON.

## SYNTAX

```
Invoke-ChekapAudit [[-Category] <String[]>] [[-CheckId] <String[]>] [[-Language] <String>]
 [[-OutputPath] <String>] [[-Format] <String[]>] [[-Note] <String>] [<CommonParameters>]
```

## DESCRIPTION
Виконує всі перевірки або лише вибрані категорії чи ідентифікатори й повертає по одному об'єкту Chekap.CheckResult на кожну знахідку. Об'єкти можна фільтрувати в PowerShell, а з параметром -OutputPath результат ще й зберігається у звіті.

З -OutputPath команда записує в указану теку два файли: Chekap-\<ComputerName\>-\<yyyyMMdd-HHmm\>.html і файл з таким самим іменем та розширенням .json, наприклад Chekap-PC-042-20261029-1430.html. Теку буде створено ще до початку перевірок, тож хибний шлях викличе помилку одразу. Звіт ніколи не перезаписується: якщо файли цієї хвилини вже є, нові отримують суфікс -2, -3 і так далі. Повні шляхи до файлів виводяться лише з -Verbose. Без -OutputPath файли не створюються.

HTML-звіт — це один файл без зовнішніх ресурсів: він працює без інтернету, відкривається в будь-якому браузері, його можна роздрукувати чи надіслати колезі, і він нічого нікуди не надсилає. Звіт починається з паспорта ПК (система, модель, процесор, пам'ять, час безперервної роботи, адреси IPv4, домен або робоча група), далі йдуть знахідки від найгірших до найкращих з фільтрами за статусом і категорією, а до кожної знахідки додано дані, на яких вона ґрунтується. У JSON-файлі ті самі дані для скриптів. У звіті є ім'я ПК, його IP-адреси та назви принтерів, тож перегляньте його, перш ніж надсилати за межі організації.

Перевірки лише читають дані. Жодна з них не змінює ПК, і жодна з поточних перевірок не потребує прав адміністратора. Перевірка, якій вони потрібні, отримує статус Skipped, якщо PowerShell запущено без підвищення прав. Кожен результат має Status: OK, Warning, Critical, Error (перевірка не змогла завершитися) або Skipped (перевірка не може виконатися або не стосується цього ПК, наприклад, немає батареї). Значення Status завжди англійською, щоб скрипти працювали за будь-якої мови; в українському звіті їх показано словами Гаразд, Увага, Критично, Помилка, Пропущено.

Знахідки й звіт подаються однією мовою: за параметром Language, інакше мовою, збереженою командою Set-ChekapConfig, інакше мовою інтерфейсу Windows.

## EXAMPLES

### Приклад 1: Виконати всі перевірки й зберегти звіт
```powershell
Invoke-ChekapAudit -OutputPath C:\Reports
```

Виконує всі перевірки й зберігає звіти HTML і JSON у C:\Reports, наприклад Chekap-PC-042-20261029-1430.html. Знахідки також потрапляють у вивід команди.

### Приклад 2: Звіт українською з приміткою
```powershell
Invoke-ChekapAudit -Language uk -OutputPath C:\Reports -Note 'PC-042: не друкує'
```

Зберігає звіт українською з рядком «PC-042: не друкує» вгорі.

### Приклад 3: Лише деякі категорії, лише HTML
```powershell
Invoke-ChekapAudit -Category Network, Printing -OutputPath .\reports -Format Html -Verbose
```

Виконує лише перевірки категорій Network і Printing та зберігає лише HTML-звіт у теку reports у поточному розташуванні. З -Verbose команда виводить шлях до файлу.

### Приклад 4: Порахувати знахідки без звіту
```powershell
Invoke-ChekapAudit | Group-Object Status | Select-Object Name, Count
```

Виконує всі перевірки, нічого не зберігає й показує, скільки знахідок має кожен статус.

## PARAMETERS

### -Category
Виконати лише перевірки цих категорій: System (стан ПК), Network (мережа) або Printing (друк). Можна вказати кілька. Разом із CheckId перевірка має відповідати обом умовам.

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

### -CheckId
Виконати лише ці перевірки. Точні ідентифікатори або шаблони, наприклад NET-DNS-001 чи PRN-*. Якщо ідентифікатор не збігається з жодною перевіркою Chekap, команда видає попередження. Якщо жодної перевірки не вибрано, команда нічого не повертає й не створює звіт.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Language
Мова знахідок і звіту: uk (українська) або en (англійська). Без цього параметра Chekap бере мову, збережену командою Set-ChekapConfig, а якщо її немає, мову інтерфейсу Windows.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputPath
Тека для файлів звіту. Якщо її немає, вона створюється. Відносний шлях відраховується від поточного розташування. Звіт ніколи не перезаписується: якщо файли цієї хвилини вже є, нові отримують суфікс -2, -3 і так далі. Якщо теку не вдається створити або файл не вдається записати, команда зупиняється з помилкою.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Format
Формати файлів: Html, Json або обидва. Типово обидва.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: @('Html', 'Json')
Accept pipeline input: False
Accept wildcard characters: False
```

### -Note
Рядок тексту для верху звіту, наприклад скарга або номер заявки. Він показується в HTML-звіті й зберігається в JSON-файлі.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
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

### Chekap.CheckResult
По одному об'єкту на кожну знахідку з властивостями CheckId, Category, ComputerName, Status, Target, Title, Details, Recommendation, FixId, FixRiskLevel, Evidence, References і Timestamp. CheckId — стабільний ідентифікатор, який не перекладається. Evidence містить сирі дані, на яких ґрунтується знахідка. FixId і FixRiskLevel у цій версії порожні.

## NOTES

## RELATED LINKS

[Test-ChekapHealth](Test-ChekapHealth.md)

[Test-ChekapNetwork](Test-ChekapNetwork.md)

[Test-ChekapPrinting](Test-ChekapPrinting.md)

[Get-ChekapCheck](Get-ChekapCheck.md)

[Start-Chekap](Start-Chekap.md)

---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Test-ChekapNetwork

## SYNOPSIS
Перевіряє мережу цього ПК: адаптери, адреси, шлюз, DNS, доступ до інтернету, проксі-сервер, профіль мережі та годинник.

## SYNTAX

```
Test-ChekapNetwork [[-Language] <String>] [[-CheckId] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Виконує перевірки категорії Network і повертає по одному об'єкту Chekap.CheckResult на кожну знахідку. Перевіряється таке: мережевий адаптер і його швидкість, IP-адреса від DHCP (автоматична адреса 169.254.x.x означає, що жоден DHCP-сервер не відповів), DNS-сервери, перетворення імен, шлюз за замовчуванням, доступ до інтернету, налаштування проксі-сервера, профіль мережі (Public, Private чи Domain) і синхронізація часу (годинник, що сильно розходиться з еталонним, ламає Kerberos і TLS).

Перевірки нічого не змінюють і не потребують прав адміністратора. Вони звертаються до мережі: ping шлюзу за замовчуванням, DNS-запит до кожного з ваших DNS-серверів, з'єднання з проксі-сервером, якщо його вказано, один запит до вашого джерела точного часу, перетворення імені www.microsoft.com на адресу (а на ПК у домені ще й імені домену) та одне з'єднання з портом 443 www.microsoft.com для перевірки доступу до інтернету. Ping, DNS-запити й TCP-з'єднання обмежені коротким часом очікування, тож сервер, який не відповідає, не змусить перевірку зависнути. Запит часу виконує стандартна утиліта w32tm, яка має власний час очікування.

Кожен результат має Status: OK, Warning, Critical, Error (перевірка не змогла завершитися) або Skipped (перевірка не стосується цього ПК). Значення Status завжди англійською, щоб скрипти працювали за будь-якої мови. Title, Details і Recommendation подаються мовою текстів: мовою з параметра Language; якщо його не вказано — мовою, збереженою командою Set-ChekapConfig; якщо й її немає — мовою інтерфейсу Windows.

## EXAMPLES

### Приклад 1: Виконати всі перевірки мережі
```powershell
Test-ChekapNetwork
```

Виконує всі перевірки категорії Network і показує знахідки в таблиці: статус, ідентифікатор перевірки, об'єкт і назву.

### Приклад 2: Показати лише те, що потребує уваги
```powershell
Test-ChekapNetwork -Language en | Where-Object Status -in 'Warning', 'Critical' | Format-List CheckId, Target, Details, Recommendation
```

Показує англійською знахідки зі статусом Warning і Critical: що знайдено й що робити.

### Приклад 3: Виконати лише перевірки шлюзу й DNS
```powershell
Test-ChekapNetwork -CheckId NET-GATEWAY-001, NET-DNS-* | Format-List
```

Виконує перевірку шлюзу та всі перевірки DNS і показує всі властивості їхніх результатів.

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
Виконати лише ці перевірки. Точні ідентифікатори або шаблони, наприклад NET-DNS-001 чи NET-DNS-*. Тут враховуються лише перевірки категорії Network, тож ідентифікатор іншої категорії нічого не вибере. Якщо ідентифікатор не збігається з жодною перевіркою Chekap, команда видає попередження. Якщо жодної перевірки не вибрано, команда нічого не повертає.

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

[Test-ChekapPrinting](Test-ChekapPrinting.md)

[Get-ChekapCheck](Get-ChekapCheck.md)

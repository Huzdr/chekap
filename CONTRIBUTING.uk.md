# Участь у розробці Chekap

[English](CONTRIBUTING.md) | Українська

Дякуємо, що допомагаєте. Chekap створено для сисадмінів малих і середніх мереж на Windows, і більшість його перевірок виросла з проблем, на які хтось натрапив на роботі. Якщо ви натрапили на таку проблему, ви можете додати перевірку для неї, і це займе приблизно десять хвилин.

## Чим можна допомогти

- **Помилка або хибна знахідка.** Створіть issue за формою для помилки. Вона просить замінити справжні імена комп'ютерів, IP-адреси й імена користувачів, перш ніж вставляти будь-який вивід.
- **Ідея перевірки.** Опишіть проблему й те, як її розпізнати на ПК, у формі «ідея перевірки». Писати код не обов'язково.
- **Переклад або виправлення формулювання.** Скористайтеся формою для перекладу або створіть pull request зі змінами в таблицях рядків. Українські тексти мають читатися як проста, правильна українська мова, написана сисадміном. Див. [Формулювання та переклад](#формулювання-та-переклад).
- **Нова перевірка.** Дотримуйтеся інструкцій у розділах нижче.

## Підготовка

Потрібні Windows, Git і PowerShell. Клонуйте репозиторій і встановіть для свого користувача модулі для розробки (Pester 5, PSScriptAnalyzer, platyPS 0.14.2); для цього один раз потрібен інтернет:

```powershell
git clone https://github.com/Huzdr/chekap.git
cd chekap
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass   # лише якщо PowerShell блокує скрипти; діє тільки в цьому вікні
./build.ps1 -Task Bootstrap
```

Самому Chekap залежності під час роботи не потрібні. Ці модулі потрібні лише для розробки. Рядок `Set-ExecutionPolicy` потрібен, лише якщо PowerShell відмовляється запускати `build.ps1`: він змінює політику виконання тільки для цього вікна.

## Перевірка за 10 хвилин

Перевірка — це один файл. Ядро не чіпають. Файл повертає хеш-таблицю з двома блоками коду: `Collect` читає дані з ПК, а `Evaluate` перетворює ці дані на висновок (вердикт). Третя частина, тексти, лежить у таблицях рядків.

### 1. Виберіть Id і створіть файл

Файл називається `Chekap/Checks/<Category>/<Id>.ps1`. Id має вигляд `CAT-NAME-001`; його ніколи не перекладають і не використовують повторно. `Id` усередині файлу має збігатися з іменем файлу, а `Category` — з іменем папки (у версії 0.1 це `System`, `Network` або `Printing`); тести перевіряють і те, і те. Нова категорія потребує більше змін (рядок `Category.<Name>`, список `-Category` у `Invoke-ChekapAudit`, зазвичай нова команда `Test-Chekap<Name>`), тож спершу запитайте в issue.

Візьміть за основу цю справжню перевірку: скопіюйте її й змініть:

```powershell
@{
    Id            = 'SYS-UPTIME-001'
    Category      = 'System'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows/win32/cimwin32prov/win32-operatingsystem'
        'https://learn.microsoft.com/troubleshoot/windows-client/setup-upgrade-and-drivers/updates-not-install-with-fast-startup'
    )
    Settings      = @{ WarnDays = 14 }
    Collect       = {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $power = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -ErrorAction SilentlyContinue
        @{
            LastBoot    = [datetime]$os.LastBootUpTime
            Now         = Get-Date
            FastStartup = ($null -ne $power -and $power.HiberbootEnabled -eq 1)
        }
    }
    Evaluate      = {
        param($Data, $Settings)
        $totalDays = ($Data.Now - $Data.LastBoot).TotalDays
        $days = [int][math]::Floor($totalDays)
        if ($totalDays -lt $Settings.WarnDays) {
            @{ Status = 'OK'; Message = 'Ok'; Args = @($days) }
        }
        elseif ($Data.FastStartup) {
            @{ Status = 'Warning'; Message = 'LongFastStartup'; Args = @($days) }
        }
        else {
            @{ Status = 'Warning'; Message = 'Long'; Args = @($days) }
        }
    }
}
```

### 2. Правила, яких дотримується перевірка

- **`Collect` повертає лише прості дані:** рядки, числа, булеві значення, `[datetime]`, масиви й хеш-таблиці. Enum перетворюйте на `[string]`. CIM-об'єкти не повертайте ніколи.
- **`Collect` не розбирає локалізований вивід.** Читайте CIM, реєстр або `Get-WinEvent -FilterHashtable` (беріть `Properties[n]`, а не текст повідомлення). Вбудовані утиліти (`w32tm`, `powercfg`) викликайте лише за іменем, без шляху, щоб Pester міг їх підмінити, і читайте лише їхній числовий або XML-вивід.
- **До мережі звертайтеся лише через хелпери з таймаутом:** `Test-ChekapPing`, `Test-ChekapTcpPort`, `Test-ChekapDnsServer` у `Chekap/Private/Collect/`.
- **`Evaluate` — чиста функція:** жодних системних викликів. Можна використовувати лише `ForEach-Object`, `Where-Object`, `Sort-Object`, `Select-Object`, `Measure-Object` і `Group-Object`.
- **Кожен вердикт — це літерал хеш-таблиці** з літеральними `Status` (`OK`, `Warning`, `Critical` або `Skipped`) і `Message`. Необов'язкові ключі: `Args` (значення для `{0}`, `{1}` у тексті), `Target` (об'єкт, якого стосується знахідка, наприклад `D:` або назва принтера) і `Evidence` (дані для показу; без нього показується весь результат `Collect`). `Evaluate` може повернути кілька вердиктів, наприклад по одному на кожен принтер. `Error` — не вердикт: це те, що повідомляє ядро, коли блок завершується винятком.
- **Блок оголошує лише ті параметри, які використовує:** `param($Settings)` у `Collect`, `param($Data)` або `param($Data, $Settings)` в `Evaluate`.
- **Порогові значення — в `Settings`**, а не в коді `Evaluate`.
- **У `References` є щонайменше одне посилання `https://`** на документацію Microsoft або інше авторитетне джерело.
- **Лише синтаксис Windows PowerShell 5.1:** без `??`, `?:`, `?.`, `&&`, `||` і без `ForEach-Object -Parallel`. Без `Invoke-Expression`, без `Win32_Product`, без сторонніх модулів.
- **Перевірка лише читає.** Усьому, що змінює ПК, у версії 0.1 не місце.
- **Лише вигадані дані** — у коді, тестах і issue: `PC-042`, `contoso.local`, `192.0.2.x`, `PRN-2F-HP`.

### 3. Додайте тексти в обидві таблиці рядків

Текстів у коді немає ніколи, лише ключі. Додайте ключі до `Chekap/en-US/Chekap.strings.psd1` і до `Chekap/uk-UA/Chekap.strings.psd1` одразу, з однаковими заповнювачами `{n}` в обох:

| Ключ | Текст |
|---|---|
| `<Id>.Title` | Назва перевірки |
| `<Id>.<Message>.Details` | Що знайдено, для кожного `Message` перевірки |
| `<Id>.<Message>.Recommendation` | Що робити. Обов'язковий для кожного `Message`, який не `OK` |

Уривок з української таблиці для перевірки вище (у справжній таблиці є ще ключі для `Ok` і `LongFastStartup`):

```powershell
'SYS-UPTIME-001.Title' = 'Час безперервної роботи'
'SYS-UPTIME-001.Long.Details' = 'ПК не перезавантажували {0} дн.'
'SYS-UPTIME-001.Long.Recommendation' = 'Перезавантажте ПК, щоб застосувати оновлення та звільнити пам''ять, яку тримають програми, що працюють давно.'
```

Одинарну лапку всередині тексту подвоюють (`''`). Спершу опишіть проблему, потім скажіть, що робити, короткими реченнями.

### 4. Додайте тест

Тести табличні: по одному рядку на кожен `Message`, у `tests/Checks/<Category>.Tests.ps1`. У рядку задано вигадані дані `Collect` і очікуваний вердикт:

```powershell
@{ Id = 'SYS-UPTIME-001'; Name = 'long uptime is Long'; Data = @{ LastBoot = (& $daysAgo 20); Now = $now; FastStartup = $false }; Expect = @(@{ Status = 'Warning'; Message = 'Long'; Args = @(20) }) }
```

`Collect` отримує власний тест у тому самому файлі з підміненими системними викликами (`Mock Get-CimInstance ...`), бо тести ніколи не торкаються справжньої системи. Тест категорії ще й рахує її перевірки, тож оновіть це число.

### 5. Кодування

Усі файли `.ps1`, `.psm1` і `.psd1` — це UTF-8 **з BOM**; без нього Windows PowerShell 5.1 ламає кирилицю. Створивши файли, виконайте:

```powershell
./tools/Add-Bom.ps1
```

Файли Markdown і YAML — без BOM. `.editorconfig` задає UTF-8, закінчення рядків CRLF і чотири пробіли.

### 6. Запустіть збірку

Спершу спробуйте нову перевірку на своєму ПК (підставте свій Id замість `<Id>`; папку `out` Git ігнорує):

```powershell
Import-Module ./Chekap/Chekap.psd1 -Force
Invoke-ChekapAudit -CheckId <Id> -OutputPath out/try -Verbose
```

Потім запустіть збірку. У вікні PowerShell у папці репозиторію:

```powershell
./build.ps1                                          # Lint і Test, типово
./build.ps1 -Task Lint                               # лише PSScriptAnalyzer; має пройти без жодних зауважень
./build.ps1 -Task Test -TestPath tests/Checks/System.Tests.ps1
```

Запускайте одне завдання за раз, як це робить CI. З `powershell -File build.ps1` список через кому, як-от `-Task Lint,Test`, надходить одним рядком, тож для списку використовуйте `-Command`. Тести мають проходити у Windows PowerShell 5.1 і в PowerShell 7, тож запустіть обидва:

```powershell
powershell -NoProfile -File build.ps1
pwsh -NoProfile -File build.ps1
```

### 7. Оновіть таблицю й журнал змін

Таблицю перевірок в обох README згенеровано з самих перевірок. Згенеруйте її наново, інакше тест не пройде:

```powershell
./tools/Update-ReadmeChecks.ps1
```

Додайте один рядок під `## [Unreleased]` у [CHANGELOG.md](CHANGELOG.md), наприклад `- Check SYS-UPTIME-001 ...`.

## Зміни в команді або в її довідці

Довідка — це markdown у `docs/en/` і `docs/uk/` (формат platyPS); коментарів-довідки в коді немає. Змінивши параметри публічної команди, оновіть сторінку команди в обох папках. Спершу імпортуйте platyPS і модуль (`Import-Module platyPS -RequiredVersion 0.14.2; Import-Module ./Chekap/Chekap.psd1 -Force`); тоді `Update-MarkdownHelp -Path docs/en` виправить структуру. Далі відредагуйте англійські тексти, а українську сторінку напишіть вручну. Тести порівнюють описані параметри зі справжніми. Збірка релізу перетворює сторінки на довідку модуля.

## Формулювання та переклад

У [docs/glossary.md](docs/glossary.md) зібрано слова, які вживаються в обох мовах (перевірка, знахідка, «Що робити», Print Spooler, шлюз та інші). Користуйтеся ними, а запроваджуючи нове слово, додайте його туди. Українською: короткі прості речення, без дослівного перекладу з англійської, а назви вікон і кнопок Windows — такі, як в українській Windows. Тести перевіряють, що в обох таблицях рядків однакові ключі й однакові заповнювачі `{n}`; чи текст добрий, вони перевірити не можуть, тож прочитайте його вголос.

## Коміти та pull request

- Невеликі коміти з повідомленнями за [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `i18n:`, `test:`, `ci:`, `chore:`.
- Одна зміна в одному pull request. Заповніть контрольний список із шаблону.
- CI має бути зеленим у Windows PowerShell 5.1 і в PowerShell 7.
- Перш ніж надсилати, перегляньте свої зміни: чи немає в них справжніх імен комп'ютерів, IP-адрес і імен користувачів.

## Правила, які діють завжди

- **Безпечно за замовчуванням.** Перевірки лише читають. Зміни на ПК з'являться пізніше, з `-WhatIf`, резервною копією та відкатом.
- **Без залежностей під час роботи, без телеметрії, без коду з мережі.** Модуль має працювати в ізольованій мережі.
- **Жодного тексту для користувача в коді.** Лише ключі рядків.
- **Перевірка, яка не може виконатися, має статус `Skipped` з поясненням, а не помилку.** Наприклад, немає батареї або зупинено службу Print Spooler.

Роблячи внесок, ви погоджуєтеся, що він поширюється за [ліцензією MIT](LICENSE) і що ви дотримуєтеся [Кодексу поведінки](CODE_OF_CONDUCT.md).

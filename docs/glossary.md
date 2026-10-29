# Glossary / Глосарій

English | Українська

This page keeps the words of Chekap the same in both languages. Use these forms in the string tables (`Chekap/en-US` and `Chekap/uk-UA`), the help in `docs/en` and `docs/uk`, and the READMEs. Add a row when you introduce a new term.

Ця сторінка підтримує однакові слова Chekap у двох мовах. Користуйтеся цими формами в таблицях рядків (`Chekap/en-US` і `Chekap/uk-UA`), у довідці (`docs/en` і `docs/uk`) та в README. Запроваджуючи новий термін, додайте рядок.

## Terms / Терміни

The Ukrainian column is the form as it stands in the Ukrainian texts, so a noun may be in the plural or in the case of the title where it is used. The last column is where the term is used: a string key or a place in the help.

| English | Українська | Used in |
|---|---|---|
| check | перевірка | all checks, menu |
| finding | знахідка | help (`docs/uk`), reports |
| what to do (recommendation) | Що робити | `Report.Recommendation` |
| collected data (evidence) | Зібрані дані | `Report.Evidence` |
| object (target) | Об'єкт | `Report.Target` |
| learn more (references) | Докладніше | `Report.References` |
| report | звіт | `Report.Title`, `Invoke-ChekapAudit` |
| note | Примітка | `Report.Note` |
| PC passport | Паспорт ПК | `Report.System` |
| category | Категорія | `Report.Filter.Category` |
| status | Статус | `Report.Filter.Status` |
| OK (status) | Гаразд | `Status.OK` |
| Warning (status) | Увага | `Status.Warning` |
| Critical (status) | Критично | `Status.Critical` |
| Error (status) | Помилка | `Status.Error` |
| Skipped (status) | Пропущено | `Status.Skipped` |
| PC (computer) | ПК | everywhere in the texts |
| administrator rights | права адміністратора | `Core.Skipped.NotAdmin.*` |
| uptime | Час безперервної роботи | `SYS-UPTIME-001.Title` |
| pending restart | Очікуване перезавантаження | `SYS-REBOOT-001.Title` |
| Fast Startup | швидкий запуск | `SYS-UPTIME-001.LongFastStartup.*` |
| page file | файл підкачки | `SYS-MEMORY-001.Title` |
| application crashes | Збої програм | `SYS-APPCRASH-001.Title` |
| blue screen crashes | Аварії із синім екраном | `SYS-BSOD-001.Title` |
| unexpected shutdowns | Аварійні вимкнення | `SYS-SHUTDOWN-001.Title` |
| startup programs | Програми в автозапуску | `SYS-STARTUP-001.Title` |
| network adapter | Мережевий адаптер | `NET-ADAPTER-001.Title` |
| default gateway | Шлюз за замовчуванням | `NET-GATEWAY-001.Title` |
| DNS server | DNS-сервер | `NET-DNS-001.*` |
| name resolution | Перетворення імен | `NET-DNS-002.Title` |
| proxy server | Проксі-сервер | `NET-PROXY-001.Title` |
| network profile | Профіль мережі | `NET-PROFILE-001.Title` |
| time synchronization | Синхронізація часу | `NET-TIME-001.Title` |
| time source | джерело часу | `NET-TIME-001.*` |
| domain controller | контролер домену | `NET-TIME-001.*` |
| Print Spooler service (spooler) | Print Spooler | `PRN-SPOOLER-001.Title` |
| print queues | Черги друку | `PRN-QUEUE-001.Title` |
| stuck jobs | завислі завдання | `PRN-QUEUE-001.Stuck.*` |
| default printer | Принтер за замовчуванням | `PRN-DEFAULT-001.Title` |
| network printers | Мережеві принтери | `PRN-PORT-001.Title` |
| printer drivers | Драйвери принтерів | `PRN-DRIVER-001.Title` |
| imaging devices (scanner or camera) | Пристрої обробки зображень | `PRN-SCAN-001.Title` |
| shared folders | спільні папки | `NET-PROFILE-001.Public.*` |
| folders | папки | `SYS-DISK-001.*` |

## Not translated / Не перекладаються

- Names of commands, parameters and properties of the objects (`Invoke-ChekapAudit`, `-Language`, `Status`, `Evidence`).
- Check Ids (`SYS-UPTIME-001`) and the values of `Status` in the objects (`OK`, `Warning`, `Critical`, `Error`, `Skipped`). The report shows them as the Ukrainian words from the table above.
- Names of Windows services and tools (`Spooler`, `w32tm`, `ipconfig`), and technical terms that have no common Ukrainian form (Kerberos, WSD, APIPA, RPC).

Назви команд, параметрів і властивостей об'єктів, ідентифікатори перевірок і значення `Status` в об'єктах не перекладаються. Назви служб і засобів Windows та технічні терміни без усталеної української форми (Kerberos, WSD, APIPA, RPC) лишаються як є.

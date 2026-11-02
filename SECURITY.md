# Security Policy / Політика безпеки

## English

### Supported versions

Only the latest release of Chekap gets security fixes.

### Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately through GitHub Security Advisories: <https://github.com/Huzdr/chekap/security/advisories/new> (the **Security** tab of the repository, **Report a vulnerability**).

Please include:

- the version of Chekap (`(Get-Module Chekap).Version`), the version of PowerShell and of Windows;
- what you found and the steps to reproduce it;
- what an attacker could do with it.

Replace real computer names, IP addresses and user names in your report with invented ones (`PC-042`, `contoso.local`, `192.0.2.x`).

Chekap is maintained by one person, so I cannot promise a fixed time. I will try to answer within a week and to tell you when a fix is released.

### What counts

Chekap only reads data from the PC, writes only the report files, the language setting and a short-lived temporary file of the battery check, and sends nothing over the network except the probes of its checks. Problems that matter most:

- a way to make a report run script or load a resource when it is opened (for example through the name of a printer or a process);
- a way to make Chekap run code or write files that it should not, through data it reads or through a path it uses;
- a flaw in the release package or in the build that lets someone replace what is delivered.

Not a vulnerability: a problem that needs administrator rights on the PC already, or the known limitations listed in the [README](README.md#known-limitations).

## Українська

### Підтримувані версії

Виправлення безпеки отримує лише остання версія Chekap.

### Як повідомити про вразливість

Будь ласка, не створюйте публічний issue про проблему безпеки. Повідомте про неї приватно через GitHub Security Advisories: <https://github.com/Huzdr/chekap/security/advisories/new> (вкладка **Security** репозиторію, кнопка **Report a vulnerability**).

Будь ласка, вкажіть:

- версію Chekap (`(Get-Module Chekap).Version`), версію PowerShell і Windows;
- що ви знайшли та як це відтворити;
- що з цим може зробити зловмисник.

Замініть у повідомленні справжні імена комп'ютерів, IP-адреси й імена користувачів вигаданими (`PC-042`, `contoso.local`, `192.0.2.x`).

Chekap супроводжує одна людина, тож твердого терміну я обіцяти не можу. Спробую відповісти протягом тижня й повідомити вас, коли вийде виправлення.

### Що вважається вразливістю

Chekap лише читає дані з ПК, записує тільки файли звіту, налаштування мови та короткочасний файл перевірки батареї й нічого не надсилає мережею, крім звернень самих перевірок. Найважливіші проблеми:

- спосіб змусити звіт виконати скрипт або завантажити ресурс під час відкриття (наприклад, через назву принтера чи процесу);
- спосіб змусити Chekap виконати код або записати файли, яких він не повинен, через дані, які він читає, або через шлях, яким користується;
- вада в пакеті релізу чи в збірці, що дає змогу підмінити те, що постачається.

Не є вразливістю: проблема, для якої вже потрібні права адміністратора на ПК, а також відомі обмеження з [README](README.uk.md#відомі-обмеження).

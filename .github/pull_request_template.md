## What and why / Що і навіщо

<!-- One or two sentences. / Одне-два речення. -->

## Checklist / Чекліст

- [ ] `./build.ps1` passes on Windows PowerShell 5.1 and on PowerShell 7 / `./build.ps1` проходить у Windows PowerShell 5.1 і в PowerShell 7
- [ ] New or changed texts are in both `Chekap/en-US` and `Chekap/uk-UA`, with the same `{n}` placeholders / Нові чи змінені тексти є і в `Chekap/en-US`, і в `Chekap/uk-UA`, з однаковими заповнювачами `{n}`
- [ ] A new check has a test, `References` with `https://` links and a Recommendation for every non-OK message / Нова перевірка має тест, `References` з посиланнями `https://` і Recommendation для кожного повідомлення, яке не OK
- [ ] I ran `tools/Add-Bom.ps1` for new `.ps1`, `.psm1`, `.psd1` files / Я виконав(ла) `tools/Add-Bom.ps1` для нових файлів `.ps1`, `.psm1`, `.psd1`
- [ ] I ran `tools/Update-ReadmeChecks.ps1` if the list of checks changed / Я виконав(ла) `tools/Update-ReadmeChecks.ps1`, якщо список перевірок змінився
- [ ] The help in `docs/en` and `docs/uk` and the `CHANGELOG.md` (`## [Unreleased]`) are updated if needed / Довідку в `docs/en` і `docs/uk` та `CHANGELOG.md` (`## [Unreleased]`) оновлено, якщо треба
- [ ] There are no real computer names, IP addresses or user names in the code, tests or text (use `PC-042`, `contoso.local`, `192.0.2.x`) / У коді, тестах і тексті немає справжніх імен комп'ютерів, IP-адрес чи імен користувачів (використовуйте `PC-042`, `contoso.local`, `192.0.2.x`)

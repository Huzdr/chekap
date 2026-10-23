# Ukrainian UI strings. Every key must also exist in en-US, with the same {n} placeholders.
@{
    'Status.OK'                            = 'Гаразд'
    'Status.Warning'                       = 'Увага'
    'Status.Critical'                      = 'Критично'
    'Status.Error'                         = 'Помилка'
    'Status.Skipped'                       = 'Пропущено'

    'Category.System'                      = 'Система'
    'Category.Network'                     = 'Мережа'
    'Category.Printing'                    = 'Друк'

    'Core.ConstrainedLanguage'             = 'Chekap не може працювати в режимі обмеженої мови PowerShell (Constrained Language Mode), наприклад під AppLocker чи WDAC. Запустіть його в сесії з режимом FullLanguage.'
    'Core.InvalidCheckFile'                = 'Файл перевірки {0} некоректний: {1}'
    'Core.UnknownCheckId'                  = 'Перевірки з ідентифікатором "{0}" не існує.'
    'Core.Skipped.NotAdmin.Details'        = 'Для цієї перевірки потрібні права адміністратора.'
    'Core.Skipped.NotAdmin.Recommendation' = 'Запустіть PowerShell від імені адміністратора й повторіть перевірку.'
    'Core.Skipped.OldBuild.Details'        = 'Ця перевірка потребує Windows зі збіркою {0} або новішою. На цьому ПК збірка {1}.'
    'Core.Skipped.OldBuild.Recommendation' = 'Виправляти нічого не потрібно: перевірка не стосується цієї версії Windows.'
    'Core.Error.Collect.Details'           = 'Не вдалося зібрати дані: {0}'
    'Core.Error.Evaluate.Details'          = 'Не вдалося обробити зібрані дані: {0}'
    'Core.Error.Recommendation'            = 'Повторіть перевірку з параметром -Verbose. Якщо помилка повторюється, повідомте про неї в репозиторії Chekap.'
    'Core.Verbose.Running'                 = 'Виконується перевірка {0}'
    'Core.Verbose.ReportWritten'           = 'Звіт збережено: {0}'

    'Config.Saved'                         = 'Налаштування збережено: {0}'
}

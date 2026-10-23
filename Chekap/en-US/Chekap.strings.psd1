# English UI strings. Every key must also exist in uk-UA, with the same {n} placeholders.
@{
    'Status.OK'                            = 'OK'
    'Status.Warning'                       = 'Warning'
    'Status.Critical'                      = 'Critical'
    'Status.Error'                         = 'Error'
    'Status.Skipped'                       = 'Skipped'

    'Category.System'                      = 'System'
    'Category.Network'                     = 'Network'
    'Category.Printing'                    = 'Printing'

    'Core.ConstrainedLanguage'             = 'Chekap cannot run in Constrained Language Mode (for example under AppLocker or WDAC). Start it in a session that uses FullLanguage mode.'
    'Core.InvalidCheckFile'                = 'Check file {0} is not valid: {1}'
    'Core.InvalidCheckFile.NotHashtable'   = 'The file must return exactly one hashtable.'
    'Core.InvalidCheckFile.BadKey'         = 'The key {0} is missing or has the wrong type.'
    'Core.UnknownCheckId'                  = 'There is no check with the ID "{0}".'
    'Core.Skipped.NotAdmin.Details'        = 'This check needs administrator rights.'
    'Core.Skipped.NotAdmin.Recommendation' = 'Start PowerShell as administrator and run the check again.'
    'Core.Skipped.OldBuild.Details'        = 'This check needs Windows build {0} or newer. This PC runs build {1}.'
    'Core.Skipped.OldBuild.Recommendation' = 'Nothing to fix: this check does not apply to this version of Windows.'
    'Core.Error.Collect.Details'           = 'Could not collect the data: {0}'
    'Core.Error.Evaluate.Details'          = 'Could not evaluate the collected data: {0}'
    'Core.Error.Recommendation'            = 'Run the check again with -Verbose. If the error repeats, report it in the Chekap repository.'
    'Core.Verbose.Running'                 = 'Running check {0}'
    'Core.Verbose.ReportWritten'           = 'Report written to {0}'

    'Config.Saved'                         = 'Settings saved to {0}'
}

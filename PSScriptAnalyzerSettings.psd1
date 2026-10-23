@{
    Severity = @('Error', 'Warning', 'ParseError')
    Rules    = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }
    }
}

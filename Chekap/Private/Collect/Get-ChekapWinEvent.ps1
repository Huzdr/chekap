function Get-ChekapWinEvent {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FilterHashtable,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxEvents
    )

    $query = @{ FilterHashtable = $FilterHashtable; ErrorAction = 'Stop' }
    if ($PSBoundParameters.ContainsKey('MaxEvents')) { $query.MaxEvents = $MaxEvents }
    try {
        Get-WinEvent @query
    }
    catch {
        # The error ID is not localized; the message is. "No events" is a normal answer, anything else is a real failure.
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { return @() }
        throw
    }
}

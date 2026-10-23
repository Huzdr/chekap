function Get-ChekapFolderSize {
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $null }
    try {
        # Lists the top level with errors on, so a folder we may not open gives $null, not a wrong 0.
        $null = Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop
    }
    catch {
        return $null
    }
    # shortcut: sub-folders we may not open are skipped, so the total can be low; Windows PowerShell 5.1 also follows junctions.
    $total = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    [long]$total.Sum
}

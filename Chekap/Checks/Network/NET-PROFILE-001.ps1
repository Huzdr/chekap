@{
    Id            = 'NET-PROFILE-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/powershell/module/netconnection/get-netconnectionprofile'
        'https://learn.microsoft.com/windows/security/threat-protection/security-policy-settings/network-list-manager-policies'
    )
    Settings      = @{}
    Collect       = {
        # Only the connected interfaces are judged: WSL and the Hyper-V Default Switch are Public by design.
        $connected = @(Get-ChekapConnectedInterface | ForEach-Object { $_.Index })
        # When the Network List Service does not run the cmdlet writes an error; "no profile" is the answer then.
        $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -in $connected } | ForEach-Object {
                @{
                    Alias    = [string]$_.InterfaceAlias
                    Name     = [string]$_.Name
                    Category = [string]$_.NetworkCategory
                }
            })
        @{ Profiles = $profiles }
    }
    Evaluate      = {
        param($Data)
        $profiles = @($Data.Profiles)
        if ($profiles.Count -eq 0) {
            @{ Status = 'Skipped'; Message = 'NoProfile' }
        }
        else {
            foreach ($networkProfile in $profiles) {
                if ($networkProfile.Category -eq 'Public') {
                    @{ Status = 'Warning'; Message = 'Public'; Target = $networkProfile.Alias; Args = @($networkProfile.Name); Evidence = $networkProfile }
                }
                elseif ($networkProfile.Category -eq 'Private') {
                    @{ Status = 'OK'; Message = 'OkPrivate'; Target = $networkProfile.Alias; Evidence = $networkProfile }
                }
                elseif ($networkProfile.Category -eq 'DomainAuthenticated') {
                    @{ Status = 'OK'; Message = 'OkDomain'; Target = $networkProfile.Alias; Evidence = $networkProfile }
                }
                else {
                    # A category that Windows adds later is shown by its name.
                    @{ Status = 'OK'; Message = 'Ok'; Target = $networkProfile.Alias; Args = @($networkProfile.Category); Evidence = $networkProfile }
                }
            }
        }
    }
}

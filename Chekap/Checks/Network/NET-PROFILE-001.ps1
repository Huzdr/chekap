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
        # When the Network List Service does not run the cmdlet writes an error; "no profile" is the answer then.
        $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | ForEach-Object {
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
                else {
                    @{ Status = 'OK'; Message = 'Ok'; Target = $networkProfile.Alias; Args = @($networkProfile.Category); Evidence = $networkProfile }
                }
            }
        }
    }
}

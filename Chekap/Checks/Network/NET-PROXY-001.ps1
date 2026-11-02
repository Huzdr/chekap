@{
    Id            = 'NET-PROXY-001'
    Category      = 'Network'
    RequiresAdmin = $false
    MinBuild      = 0
    References    = @(
        'https://learn.microsoft.com/windows-server/administration/windows-commands/netsh-winhttp'
        'https://learn.microsoft.com/windows/win32/winhttp/about-winhttp'
    )
    Settings      = @{ TimeoutMs = 1000 }
    Collect       = {
        param($Settings)
        $user = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
        $userEnabled = $null -ne $user -and $user.ProxyEnable -eq 1
        $userServer = $null
        if ($null -ne $user -and $user.ProxyServer) { $userServer = [string]$user.ProxyServer }
        $autoConfigUrl = $null
        if ($null -ne $user -and $user.AutoConfigURL) { $autoConfigUrl = [string]$user.AutoConfigURL }

        # WinHttpSettings is a blob: byte 8 holds flags (bit 2 = a proxy is set), the Int32 at 12 is the length N of the proxy text, the text is ASCII at 16..16+N.
        $winHttp = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections' -Name 'WinHttpSettings' -ErrorAction SilentlyContinue
        $winHttpProxy = $null
        $bytes = $null
        if ($null -ne $winHttp) { $bytes = $winHttp.WinHttpSettings }
        if ($bytes -is [byte[]] -and $bytes.Length -ge 16 -and ($bytes[8] -band 2) -ne 0) {
            $length = [BitConverter]::ToInt32($bytes, 12)
            if ($length -gt 0 -and 16 + $length -le $bytes.Length) { $winHttpProxy = [System.Text.Encoding]::ASCII.GetString($bytes, 16, $length) }
        }

        # shortcut: only the first proxy of a per-protocol list is tested (host:port, or a host alone on port 80), and a PAC script is not downloaded; follow the script if that matters.
        $reachable = @{}
        $inUse = @($winHttpProxy)
        if ($userEnabled) { $inUse = @($userServer) + $inUse }
        foreach ($text in $inUse) {
            if ($text -match '([^=;\s/]+):(\d{1,5})') {
                $hostName = $Matches[1]
                $port = [int]$Matches[2]
            }
            elseif ($text -match '^\s*(?:[A-Za-z]+=)?(?:[A-Za-z][A-Za-z0-9+.-]*://)?([^=;:\s/]+)') {
                # No port written: a proxy without one is on the default port 80.
                $hostName = $Matches[1]
                $port = 80
            }
            else { continue }
            $proxy = '{0}:{1}' -f $hostName, $port
            if ($port -lt 1 -or $port -gt 65535 -or $reachable.ContainsKey($proxy)) { continue }
            $reachable[$proxy] = [bool](Test-ChekapTcpPort -ComputerName $hostName -Port $port -TimeoutMs $Settings.TimeoutMs)
        }
        @{
            UserEnabled   = $userEnabled
            UserServer    = $userServer
            AutoConfigUrl = $autoConfigUrl
            WinHttpProxy  = $winHttpProxy
            Reachable     = $reachable
        }
    }
    Evaluate      = {
        param($Data)
        $proxies = @($Data.Reachable.Keys | Sort-Object)
        if ($Data.AutoConfigUrl) {
            @{ Status = 'OK'; Message = 'Pac'; Args = @($Data.AutoConfigUrl) }
        }
        foreach ($proxy in $proxies) {
            if ($Data.Reachable[$proxy]) {
                @{ Status = 'OK'; Message = 'Proxy'; Target = $proxy; Args = @($proxy) }
            }
            else {
                @{ Status = 'Warning'; Message = 'ProxyDown'; Target = $proxy; Args = @($proxy) }
            }
        }
        if (-not $Data.AutoConfigUrl -and $proxies.Count -eq 0) {
            @{ Status = 'OK'; Message = 'Direct' }
        }
    }
}

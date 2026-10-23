BeforeDiscovery {
    $dash = [string][char]0x2014
    $adapter = { param($name, $mediaType, $mbps) @{ Name = $name; Description = 'Contoso Network Adapter'; MediaType = $mediaType; SpeedBps = [long]$mbps * 1000000 } }
    $address = { param($alias, $ip) @{ Alias = $alias; IP = $ip; PrefixOrigin = 'Dhcp' } }
    $route = { param($alias, $gateway) @{ Alias = $alias; NextHop = $gateway } }
    $reply = { param($ms) @{ Success = $true; RoundtripMs = $ms } }
    $silence = @{ Success = $false; RoundtripMs = $null }
    $up = @{ Responds = $true; Ms = 3 }
    $down = @{ Responds = $false; Ms = 7000 }
    $publicResolvers = @('8.8.8.8', '8.8.4.4', '1.1.1.1', '1.0.0.1', '9.9.9.9', '149.112.112.112', '208.67.222.222', '208.67.220.220')
    $proxy = { param($enabled, $server, $pac, $winHttp, $reachable) @{ UserEnabled = $enabled; UserServer = $server; AutoConfigUrl = $pac; WinHttpProxy = $winHttp; Reachable = $reachable } }
    $netProfile = { param($alias, $name, $category) @{ Alias = $alias; Name = $name; Category = $category } }
    $time = { param($offset, $source) @{ Type = 'NTP'; NtpServer = 'ntp.contoso.local,0x9'; Source = $source; Output = @(); OffsetSeconds = $offset; ServiceStatus = 'Running' } }

    # One row per Message of every check. Expect lists the verdicts in order; Args is compared as a joined string.
    $script:evaluateCases = @(
        @{ Id = 'NET-ADAPTER-001'; Name = 'no connected adapter is NoConnection'; Data = @{ Adapters = @() }; Expect = @(@{ Status = 'Critical'; Message = 'NoConnection' }) }
        @{ Id = 'NET-ADAPTER-001'; Name = 'gigabit Ethernet is OK'; Data = @{ Adapters = @(& $adapter 'Ethernet' '802.3' 1000) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'Ethernet'; Args = @('Ethernet', 1000) }) }
        @{ Id = 'NET-ADAPTER-001'; Name = 'just above SlowMbps is OK'; Data = @{ Adapters = @(& $adapter 'Ethernet' '802.3' 101) }; Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'NET-ADAPTER-001'; Name = 'exactly SlowMbps is SlowLink'; Data = @{ Adapters = @(& $adapter 'Ethernet' '802.3' 100) }; Expect = @(@{ Status = 'Warning'; Message = 'SlowLink'; Target = 'Ethernet'; Args = @('Ethernet', 100) }) }
        @{ Id = 'NET-ADAPTER-001'; Name = '10 Mbps Ethernet is SlowLink'; Data = @{ Adapters = @(& $adapter 'Ethernet 2' '802.3' 10) }; Expect = @(@{ Status = 'Warning'; Message = 'SlowLink'; Target = 'Ethernet 2'; Args = @('Ethernet 2', 10) }) }
        @{ Id = 'NET-ADAPTER-001'; Name = 'a slow Wi-Fi link is not judged'; Data = @{ Adapters = @(& $adapter 'Wi-Fi' 'Native 802.11' 54) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'Wi-Fi'; Args = @('Wi-Fi', 54) }) }
        @{ Id = 'NET-ADAPTER-001'; Name = 'every adapter gets its own verdict'; Data = @{ Adapters = @((& $adapter 'Ethernet' '802.3' 1000), (& $adapter 'Ethernet 2' '802.3' 100)) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'Ethernet' }, @{ Status = 'Warning'; Message = 'SlowLink'; Target = 'Ethernet 2' }) }

        @{ Id = 'NET-DHCP-001'; Name = 'no addresses is OK with a zero count'; Data = @{ Addresses = @() }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(0) }) }
        @{ Id = 'NET-DHCP-001'; Name = 'ordinary addresses are one OK with the count'; Data = @{ Addresses = @((& $address 'Ethernet' '192.0.2.25'), (& $address 'Wi-Fi' '198.51.100.7')) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(2) }) }
        @{ Id = 'NET-DHCP-001'; Name = 'a 169.254 address is Apipa for its adapter'; Data = @{ Addresses = @(& $address 'Ethernet' '169.254.12.34') }; Expect = @(@{ Status = 'Critical'; Message = 'Apipa'; Target = 'Ethernet'; Args = @('Ethernet', '169.254.12.34') }) }
        @{ Id = 'NET-DHCP-001'; Name = 'Apipa replaces the OK verdict'; Data = @{ Addresses = @((& $address 'Ethernet' '192.0.2.25'), (& $address 'Wi-Fi' '169.254.1.2')) }; Expect = @(@{ Status = 'Critical'; Message = 'Apipa'; Target = 'Wi-Fi' }) }
        @{ Id = 'NET-DHCP-001'; Name = 'every Apipa adapter gets a verdict'; Data = @{ Addresses = @((& $address 'Ethernet' '169.254.1.2'), (& $address 'Wi-Fi' '169.254.3.4')) }; Expect = @(@{ Status = 'Critical'; Message = 'Apipa'; Target = 'Ethernet' }, @{ Status = 'Critical'; Message = 'Apipa'; Target = 'Wi-Fi' }) }
        @{ Id = 'NET-DHCP-001'; Name = '169.254 elsewhere in the address is not Apipa'; Data = @{ Addresses = @((& $address 'Ethernet' '10.169.254.1'), (& $address 'Wi-Fi' '169.253.1.1')) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(2) }) }

        @{ Id = 'NET-GATEWAY-001'; Name = 'no routes is NoGateway'; Data = @{ Routes = @(); Ping = @{} }; Expect = @(@{ Status = 'Critical'; Message = 'NoGateway' }) }
        @{ Id = 'NET-GATEWAY-001'; Name = 'a gateway that answers is OK with the time'; Data = @{ Routes = @(& $route 'Ethernet' '192.0.2.1'); Ping = @{ '192.0.2.1' = (& $reply 3) } }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = '192.0.2.1'; Args = @('192.0.2.1', 3) }) }
        @{ Id = 'NET-GATEWAY-001'; Name = 'a gateway that is silent is NoReply'; Data = @{ Routes = @(& $route 'Ethernet' '192.0.2.1'); Ping = @{ '192.0.2.1' = $silence } }; Expect = @(@{ Status = 'Warning'; Message = 'NoReply'; Target = '192.0.2.1'; Args = @('192.0.2.1') }) }
        @{ Id = 'NET-GATEWAY-001'; Name = 'a gateway without a ping entry is NoReply'; Data = @{ Routes = @(& $route 'Ethernet' '192.0.2.1'); Ping = @{} }; Expect = @(@{ Status = 'Warning'; Message = 'NoReply'; Target = '192.0.2.1' }) }
        @{ Id = 'NET-GATEWAY-001'; Name = 'the same gateway on two adapters is one verdict'; Data = @{ Routes = @((& $route 'Ethernet' '192.0.2.1'), (& $route 'Wi-Fi' '192.0.2.1')); Ping = @{ '192.0.2.1' = (& $reply 1) } }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = '192.0.2.1' }) }
        @{ Id = 'NET-GATEWAY-001'; Name = 'different gateways on two adapters are Multiple, then one verdict each'; Data = @{ Routes = @((& $route 'Wi-Fi' '192.0.2.2'), (& $route 'Ethernet' '192.0.2.1')); Ping = @{ '192.0.2.1' = (& $reply 1); '192.0.2.2' = $silence } }; Expect = @(@{ Status = 'Warning'; Message = 'Multiple'; Args = @('Ethernet: 192.0.2.1; Wi-Fi: 192.0.2.2') }, @{ Status = 'OK'; Message = 'Ok'; Target = '192.0.2.1' }, @{ Status = 'Warning'; Message = 'NoReply'; Target = '192.0.2.2' }) }
        @{ Id = 'NET-GATEWAY-001'; Name = 'two gateways on one adapter are not Multiple'; Data = @{ Routes = @((& $route 'Ethernet' '192.0.2.1'), (& $route 'Ethernet' '192.0.2.2')); Ping = @{ '192.0.2.1' = (& $reply 1); '192.0.2.2' = (& $reply 2) } }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = '192.0.2.1' }, @{ Status = 'OK'; Message = 'Ok'; Target = '192.0.2.2' }) }

        @{ Id = 'NET-DNS-001'; Name = 'no servers is NoServers'; Data = @{ Servers = @(); Probe = @{}; PartOfDomain = $false }; Expect = @(@{ Status = 'Critical'; Message = 'NoServers' }) }
        @{ Id = 'NET-DNS-001'; Name = 'servers that answer are OK with the list'; Data = @{ Servers = @('192.0.2.53', '192.0.2.54'); Probe = @{ '192.0.2.53' = $up; '192.0.2.54' = $up }; PartOfDomain = $false }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @('192.0.2.53, 192.0.2.54') }) }
        @{ Id = 'NET-DNS-001'; Name = 'no server answering is one NoneRespond'; Data = @{ Servers = @('192.0.2.53', '192.0.2.54'); Probe = @{ '192.0.2.53' = $down; '192.0.2.54' = $down }; PartOfDomain = $false }; Expect = @(@{ Status = 'Critical'; Message = 'NoneRespond'; Args = @('192.0.2.53, 192.0.2.54') }) }
        @{ Id = 'NET-DNS-001'; Name = 'one dead server among live ones is ServerDown for it'; Data = @{ Servers = @('192.0.2.53', '192.0.2.54'); Probe = @{ '192.0.2.53' = $up; '192.0.2.54' = $down }; PartOfDomain = $false }; Expect = @(@{ Status = 'Warning'; Message = 'ServerDown'; Target = '192.0.2.54'; Args = @('192.0.2.54') }) }
        @{ Id = 'NET-DNS-001'; Name = 'a public resolver on a workgroup PC is OK'; Data = @{ Servers = @('8.8.8.8'); Probe = @{ '8.8.8.8' = $up }; PartOfDomain = $false }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @('8.8.8.8') }) }
        @{ Id = 'NET-DNS-001'; Name = 'a public resolver on a domain PC is PublicOnDomain'; Data = @{ Servers = @('8.8.8.8'); Probe = @{ '8.8.8.8' = $up }; PartOfDomain = $true }; Expect = @(@{ Status = 'Warning'; Message = 'PublicOnDomain'; Target = '8.8.8.8'; Args = @('8.8.8.8') }) }
        @{ Id = 'NET-DNS-001'; Name = 'every public resolver in the list is recognised'; Data = @{ Servers = @('149.112.112.112', '208.67.220.220'); Probe = @{ '149.112.112.112' = $up; '208.67.220.220' = $up }; PartOfDomain = $true }; Expect = @(@{ Status = 'Warning'; Message = 'PublicOnDomain'; Target = '149.112.112.112' }, @{ Status = 'Warning'; Message = 'PublicOnDomain'; Target = '208.67.220.220' }) }
        @{ Id = 'NET-DNS-001'; Name = 'internal servers on a domain PC are OK'; Data = @{ Servers = @('192.0.2.10', '192.0.2.11'); Probe = @{ '192.0.2.10' = $up; '192.0.2.11' = $up }; PartOfDomain = $true }; Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'NET-DNS-001'; Name = 'an internal server plus a public one flags only the public one'; Data = @{ Servers = @('192.0.2.10', '1.1.1.1'); Probe = @{ '192.0.2.10' = $up; '1.1.1.1' = $up }; PartOfDomain = $true }; Expect = @(@{ Status = 'Warning'; Message = 'PublicOnDomain'; Target = '1.1.1.1' }) }
        @{ Id = 'NET-DNS-001'; Name = 'a dead public server on a domain PC gets both verdicts'; Data = @{ Servers = @('192.0.2.10', '8.8.8.8'); Probe = @{ '192.0.2.10' = $up; '8.8.8.8' = $down }; PartOfDomain = $true }; Expect = @(@{ Status = 'Warning'; Message = 'ServerDown'; Target = '8.8.8.8' }, @{ Status = 'Warning'; Message = 'PublicOnDomain'; Target = '8.8.8.8' }) }

        @{ Id = 'NET-DNS-002'; Name = 'both names resolving on a workgroup PC is OK with the external name'; Data = @{ Domain = 'WORKGROUP'; PartOfDomain = $false; DomainResolves = $null; ExternalResolves = $true }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @('www.microsoft.com') }) }
        @{ Id = 'NET-DNS-002'; Name = 'both names resolving in a domain is OK with both names'; Data = @{ Domain = 'contoso.local'; PartOfDomain = $true; DomainResolves = $true; ExternalResolves = $true }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @('contoso.local, www.microsoft.com') }) }
        @{ Id = 'NET-DNS-002'; Name = 'the domain not resolving is DomainFail'; Data = @{ Domain = 'contoso.local'; PartOfDomain = $true; DomainResolves = $false; ExternalResolves = $true }; Expect = @(@{ Status = 'Critical'; Message = 'DomainFail'; Target = 'contoso.local'; Args = @('contoso.local') }) }
        @{ Id = 'NET-DNS-002'; Name = 'the external name not resolving is ExternalFail'; Data = @{ Domain = 'contoso.local'; PartOfDomain = $true; DomainResolves = $true; ExternalResolves = $false }; Expect = @(@{ Status = 'Warning'; Message = 'ExternalFail'; Args = @('www.microsoft.com') }) }
        @{ Id = 'NET-DNS-002'; Name = 'both failing gives both verdicts'; Data = @{ Domain = 'contoso.local'; PartOfDomain = $true; DomainResolves = $false; ExternalResolves = $false }; Expect = @(@{ Status = 'Critical'; Message = 'DomainFail' }, @{ Status = 'Warning'; Message = 'ExternalFail' }) }
        @{ Id = 'NET-DNS-002'; Name = 'a workgroup PC is never DomainFail'; Data = @{ Domain = 'WORKGROUP'; PartOfDomain = $false; DomainResolves = $null; ExternalResolves = $false }; Expect = @(@{ Status = 'Warning'; Message = 'ExternalFail' }) }

        @{ Id = 'NET-INTERNET-001'; Name = 'a reachable host is OK with host and port'; Data = @{ Reachable = $true }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @('www.microsoft.com', 443) }) }
        @{ Id = 'NET-INTERNET-001'; Name = 'an unreachable host is NoInternet'; Data = @{ Reachable = $false }; Expect = @(@{ Status = 'Warning'; Message = 'NoInternet'; Args = @('www.microsoft.com', 443) }) }

        @{ Id = 'NET-PROXY-001'; Name = 'no proxy and no script is Direct'; Data = (& $proxy $false $null $null $null @{}); Expect = @(@{ Status = 'OK'; Message = 'Direct' }) }
        @{ Id = 'NET-PROXY-001'; Name = 'a proxy that is switched off is Direct'; Data = (& $proxy $false 'proxy.contoso.local:3128' $null $null @{}); Expect = @(@{ Status = 'OK'; Message = 'Direct' }) }
        @{ Id = 'NET-PROXY-001'; Name = 'a configuration script is Pac with its URL'; Data = (& $proxy $false $null 'http://wpad.contoso.local/proxy.pac' $null @{}); Expect = @(@{ Status = 'OK'; Message = 'Pac'; Args = @('http://wpad.contoso.local/proxy.pac') }) }
        @{ Id = 'NET-PROXY-001'; Name = 'a proxy that answers is Proxy'; Data = (& $proxy $true 'proxy.contoso.local:3128' $null $null @{ 'proxy.contoso.local:3128' = $true }); Expect = @(@{ Status = 'OK'; Message = 'Proxy'; Target = 'proxy.contoso.local:3128'; Args = @('proxy.contoso.local:3128') }) }
        @{ Id = 'NET-PROXY-001'; Name = 'a proxy that is silent is ProxyDown'; Data = (& $proxy $true 'proxy.contoso.local:3128' $null $null @{ 'proxy.contoso.local:3128' = $false }); Expect = @(@{ Status = 'Warning'; Message = 'ProxyDown'; Target = 'proxy.contoso.local:3128'; Args = @('proxy.contoso.local:3128') }) }
        @{ Id = 'NET-PROXY-001'; Name = 'a WinHTTP-only proxy is judged like a user proxy'; Data = (& $proxy $false $null $null 'proxy.contoso.local:3128' @{ 'proxy.contoso.local:3128' = $false }); Expect = @(@{ Status = 'Warning'; Message = 'ProxyDown'; Target = 'proxy.contoso.local:3128' }) }
        @{ Id = 'NET-PROXY-001'; Name = 'two proxies get one verdict each, sorted by name'; Data = (& $proxy $true 'b.contoso.local:8080' $null 'a.contoso.local:3128' @{ 'b.contoso.local:8080' = $false; 'a.contoso.local:3128' = $true }); Expect = @(@{ Status = 'OK'; Message = 'Proxy'; Target = 'a.contoso.local:3128' }, @{ Status = 'Warning'; Message = 'ProxyDown'; Target = 'b.contoso.local:8080' }) }
        @{ Id = 'NET-PROXY-001'; Name = 'a script and a proxy give Pac then the proxy verdict'; Data = (& $proxy $true 'proxy.contoso.local:3128' 'http://wpad.contoso.local/proxy.pac' $null @{ 'proxy.contoso.local:3128' = $true }); Expect = @(@{ Status = 'OK'; Message = 'Pac' }, @{ Status = 'OK'; Message = 'Proxy'; Target = 'proxy.contoso.local:3128' }) }

        @{ Id = 'NET-PROFILE-001'; Name = 'no profiles is Skipped'; Data = @{ Profiles = @() }; Expect = @(@{ Status = 'Skipped'; Message = 'NoProfile' }) }
        @{ Id = 'NET-PROFILE-001'; Name = 'a Private network is OK with its category'; Data = @{ Profiles = @(& $netProfile 'Ethernet' 'contoso.local' 'Private') }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'Ethernet'; Args = @('Private') }) }
        @{ Id = 'NET-PROFILE-001'; Name = 'a domain network is OK'; Data = @{ Profiles = @(& $netProfile 'Ethernet' 'contoso.local' 'DomainAuthenticated') }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'Ethernet'; Args = @('DomainAuthenticated') }) }
        @{ Id = 'NET-PROFILE-001'; Name = 'a Public network is Public with the network name'; Data = @{ Profiles = @(& $netProfile 'Wi-Fi' 'Guest Network' 'Public') }; Expect = @(@{ Status = 'Warning'; Message = 'Public'; Target = 'Wi-Fi'; Args = @('Guest Network') }) }
        @{ Id = 'NET-PROFILE-001'; Name = 'every profile gets its own verdict'; Data = @{ Profiles = @((& $netProfile 'Ethernet' 'contoso.local' 'Private'), (& $netProfile 'Wi-Fi' 'Guest Network' 'Public')) }; Expect = @(@{ Status = 'OK'; Message = 'Ok'; Target = 'Ethernet' }, @{ Status = 'Warning'; Message = 'Public'; Target = 'Wi-Fi' }) }

        @{ Id = 'NET-TIME-001'; Name = 'no offset is NoSource with the source'; Data = (& $time $null 'ntp.contoso.local'); Expect = @(@{ Status = 'Warning'; Message = 'NoSource'; Args = @('ntp.contoso.local') }) }
        @{ Id = 'NET-TIME-001'; Name = 'no source at all is NoSource with a dash'; Data = (& $time $null $null); Expect = @(@{ Status = 'Warning'; Message = 'NoSource'; Args = @($dash) }) }
        @{ Id = 'NET-TIME-001'; Name = 'a small offset is OK with the offset and the source'; Data = (& $time 0.0123456 'ntp.contoso.local'); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(0.0123456, 'ntp.contoso.local') }) }
        @{ Id = 'NET-TIME-001'; Name = 'a negative offset is judged by its size'; Data = (& $time -0.5 'ntp.contoso.local'); Expect = @(@{ Status = 'OK'; Message = 'Ok'; Args = @(0.5, 'ntp.contoso.local') }) }
        @{ Id = 'NET-TIME-001'; Name = 'zero offset is OK'; Data = (& $time 0 'ntp.contoso.local'); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'NET-TIME-001'; Name = 'just under WarnSeconds is OK'; Data = (& $time 59.9 'ntp.contoso.local'); Expect = @(@{ Status = 'OK'; Message = 'Ok' }) }
        @{ Id = 'NET-TIME-001'; Name = 'exactly WarnSeconds is Drift'; Data = (& $time 60 'ntp.contoso.local'); Expect = @(@{ Status = 'Warning'; Message = 'Drift'; Args = @(60) }) }
        @{ Id = 'NET-TIME-001'; Name = 'a negative offset past WarnSeconds is Drift with the absolute value'; Data = (& $time -75.5 'ntp.contoso.local'); Expect = @(@{ Status = 'Warning'; Message = 'Drift'; Args = @(75.5) }) }
        @{ Id = 'NET-TIME-001'; Name = 'just under CriticalSeconds is Drift'; Data = (& $time 299.9 'ntp.contoso.local'); Expect = @(@{ Status = 'Warning'; Message = 'Drift' }) }
        @{ Id = 'NET-TIME-001'; Name = 'exactly CriticalSeconds is DriftKerberos'; Data = (& $time 300 'ntp.contoso.local'); Expect = @(@{ Status = 'Critical'; Message = 'DriftKerberos'; Args = @(300) }) }
        @{ Id = 'NET-TIME-001'; Name = 'a negative offset past CriticalSeconds is DriftKerberos with the absolute value'; Data = (& $time -400 'ntp.contoso.local'); Expect = @(@{ Status = 'Critical'; Message = 'DriftKerberos'; Args = @(400) }) }
    )

    # Defaults named in the task brief; admin rights are not needed by any Network check.
    $script:settingsCases = @(
        @{ Id = 'NET-ADAPTER-001'; Settings = @{ SlowMbps = 100 } }
        @{ Id = 'NET-DHCP-001'; Settings = @{} }
        @{ Id = 'NET-GATEWAY-001'; Settings = @{ TimeoutMs = 1000 } }
        @{ Id = 'NET-DNS-001'; Settings = @{ ProbeName = 'localhost'; PublicResolvers = $publicResolvers } }
        @{ Id = 'NET-DNS-002'; Settings = @{ ExternalName = 'www.microsoft.com' } }
        @{ Id = 'NET-INTERNET-001'; Settings = @{ Host = 'www.microsoft.com'; Port = 443; TimeoutMs = 3000 } }
        @{ Id = 'NET-PROXY-001'; Settings = @{ TimeoutMs = 1000 } }
        @{ Id = 'NET-PROFILE-001'; Settings = @{} }
        @{ Id = 'NET-TIME-001'; Settings = @{ WarnSeconds = 60; CriticalSeconds = 300 } }
    )

    # A DNS server answers with an error code: the DNS response codes (rcode) are native errors 9001-9999.
    $script:rcodeCases = @(
        @{ Code = 9003; Responds = $true; Meaning = 'NXDOMAIN' }
        @{ Code = 9001; Responds = $true; Meaning = 'lowest rcode' }
        @{ Code = 9002; Responds = $true; Meaning = 'SERVFAIL' }
        @{ Code = 9999; Responds = $true; Meaning = 'highest rcode' }
        @{ Code = 1460; Responds = $false; Meaning = 'timeout' }
        @{ Code = 9000; Responds = $false; Meaning = 'below the rcode range' }
        @{ Code = 10000; Responds = $false; Meaning = 'above the rcode range' }
    )
}

BeforeAll {
    Import-Module (Join-Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) 'Chekap/Chekap.psd1') -Force
    $script:byId = @{}
    foreach ($registered in (InModuleScope Chekap { $script:ChekapChecks })) { $script:byId[$registered.Id] = $registered }
    $root = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:tables = @{
        'en-US' = Import-PowerShellDataFile -Path (Join-Path $root 'Chekap/en-US/Chekap.strings.psd1')
        'uk-UA' = Import-PowerShellDataFile -Path (Join-Path $root 'Chekap/uk-UA/Chekap.strings.psd1')
    }
    # The WinHttpSettings value: a 12-byte header (flags at byte 8), the proxy length at 12, the proxy text, then the bypass list.
    $script:winHttpBlob = {
        param($flags, $proxy)
        $bypass = '<local>'
        # Like the registry value, a real byte[] (adding arrays gives object[]; the comma keeps the pipeline from unrolling it).
        , [byte[]]([byte[]](0x28, 0, 0, 0, 0, 0, 0, 0, $flags, 0, 0, 0) + [BitConverter]::GetBytes([int]$proxy.Length) + [Text.Encoding]::ASCII.GetBytes($proxy) +
            [BitConverter]::GetBytes([int]$bypass.Length) + [Text.Encoding]::ASCII.GetBytes($bypass))
    }
    if (-not ('ChekapTestNetworkCategory' -as [type])) { Add-Type -TypeDefinition 'public enum ChekapTestNetworkCategory { Public, Private, DomainAuthenticated }' }
}

AfterAll {
    Remove-Module Chekap -ErrorAction SilentlyContinue
}

Describe 'Network checks: registration' {
    It 'registers all 9 checks in the Network category' {
        @($script:byId.Values | Where-Object { $_.Category -eq 'Network' }).Count | Should -Be 9
    }

    It '<Id> has the Settings from the brief and needs no admin rights' -ForEach $script:settingsCases {
        $check = $script:byId[$Id]
        $check | Should -Not -BeNullOrEmpty
        $check.RequiresAdmin | Should -BeFalse
        $check.Settings.Count | Should -Be $Settings.Count
        foreach ($key in $Settings.Keys) { (@($check.Settings[$key]) -join ',') | Should -Be (@($Settings[$key]) -join ',') }
    }
}

Describe 'Network checks: Evaluate' {
    It '<Id>: <Name>' -ForEach $script:evaluateCases {
        $check = $script:byId[$Id]
        $verdicts = @(& $check.Evaluate $Data $check.Settings)
        $verdicts.Count | Should -Be $Expect.Count
        for ($i = 0; $i -lt $Expect.Count; $i++) {
            $verdicts[$i].Status | Should -Be $Expect[$i].Status
            $verdicts[$i].Message | Should -Be $Expect[$i].Message
            if ($Expect[$i].ContainsKey('Target')) { $verdicts[$i].Target | Should -Be $Expect[$i].Target }
            if ($Expect[$i].ContainsKey('Args')) { (@($verdicts[$i].Args) -join '|') | Should -Be (@($Expect[$i].Args) -join '|') }
        }
    }

    # The runner formats a text only when Args is not empty; a placeholder left over or too few Args would show up in a report.
    It '<Id>: <Name> - the texts format in both languages' -ForEach $script:evaluateCases {
        $check = $script:byId[$Id]
        foreach ($verdict in @(& $check.Evaluate $Data $check.Settings)) {
            $verdictArgs = @()
            if ($null -ne $verdict.Args) { $verdictArgs = @($verdict.Args) }
            foreach ($table in $script:tables.Values) {
                foreach ($part in 'Details', 'Recommendation') {
                    $key = "$Id.$($verdict.Message).$part"
                    if (-not $table.ContainsKey($key)) { continue }
                    $text = [string]$table[$key]
                    if ($verdictArgs.Count -gt 0) { $text = $text -f $verdictArgs }
                    $text | Should -Not -Match '\{\d'
                }
            }
        }
    }
}

Describe 'Network checks: Collect' {
    Context 'NET-ADAPTER-001' {
        It 'keeps only connected physical adapters and maps their fields' {
            Mock Get-NetAdapter {
                @(
                    [pscustomobject]@{ Name = 'Ethernet'; InterfaceDescription = 'Contoso Gigabit'; MediaType = '802.3'; Speed = [uint64]1000000000; Status = 'Up' }
                    [pscustomobject]@{ Name = 'Ethernet 2'; InterfaceDescription = 'Contoso Spare'; MediaType = '802.3'; Speed = [uint64]0; Status = 'Disconnected' }
                    [pscustomobject]@{ Name = 'Wi-Fi'; InterfaceDescription = 'Contoso Wireless'; MediaType = 'Native 802.11'; Speed = [uint64]144000000; Status = 'Up' }
                )
            } -ModuleName Chekap
            $check = $script:byId['NET-ADAPTER-001']
            $data = & $check.Collect $check.Settings
            Should -Invoke Get-NetAdapter -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Physical }
            @($data.Adapters).Count | Should -Be 2
            $data.Adapters[0].Name | Should -Be 'Ethernet'
            $data.Adapters[0].Description | Should -Be 'Contoso Gigabit'
            $data.Adapters[0].MediaType | Should -Be '802.3'
            $data.Adapters[0].SpeedBps | Should -BeOfType [long]
            $data.Adapters[0].SpeedBps | Should -Be 1000000000
            $data.Adapters[1].Name | Should -Be 'Wi-Fi'
            $data.Adapters[1].SpeedBps | Should -Be 144000000
        }

        It 'does not throw on an unknown speed (the maximum UInt64)' {
            Mock Get-NetAdapter { [pscustomobject]@{ Name = 'Ethernet'; InterfaceDescription = 'Contoso'; MediaType = '802.3'; Speed = [uint64]::MaxValue; Status = 'Up' } } -ModuleName Chekap
            $check = $script:byId['NET-ADAPTER-001']
            { & $check.Collect $check.Settings } | Should -Not -Throw
            (& $check.Collect $check.Settings).Adapters[0].SpeedBps | Should -BeGreaterThan 0
        }

        It 'returns an empty list when nothing is connected' {
            Mock Get-NetAdapter { } -ModuleName Chekap
            $check = $script:byId['NET-ADAPTER-001']
            $data = & $check.Collect $check.Settings
            @($data.Adapters).Count | Should -Be 0
        }
    }

    Context 'NET-DHCP-001' {
        BeforeEach {
            Mock Get-NetAdapter {
                @(
                    [pscustomobject]@{ Name = 'Ethernet'; InterfaceIndex = 3; Status = 'Up' }
                    [pscustomobject]@{ Name = 'Ethernet 2'; InterfaceIndex = 4; Status = 'Disconnected' }
                )
            } -ModuleName Chekap
        }

        It 'returns the IPv4 addresses of connected adapters only' {
            Mock Get-NetIPAddress {
                @(
                    [pscustomobject]@{ InterfaceIndex = 3; InterfaceAlias = 'Ethernet'; IPAddress = '192.0.2.25'; PrefixOrigin = 'Dhcp' }
                    [pscustomobject]@{ InterfaceIndex = 3; InterfaceAlias = 'Ethernet'; IPAddress = '169.254.7.8'; PrefixOrigin = 'WellKnown' }
                    [pscustomobject]@{ InterfaceIndex = 4; InterfaceAlias = 'Ethernet 2'; IPAddress = '198.51.100.9'; PrefixOrigin = 'Manual' }
                )
            } -ModuleName Chekap
            $check = $script:byId['NET-DHCP-001']
            $data = & $check.Collect $check.Settings
            Should -Invoke Get-NetIPAddress -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $AddressFamily -eq 'IPv4' }
            @($data.Addresses).Count | Should -Be 2
            $data.Addresses[0].Alias | Should -Be 'Ethernet'
            $data.Addresses[0].IP | Should -Be '192.0.2.25'
            $data.Addresses[0].PrefixOrigin | Should -Be 'Dhcp'
            $data.Addresses[1].IP | Should -Be '169.254.7.8'
        }

        It 'turns the PrefixOrigin enum into a string' {
            Mock Get-NetIPAddress {
                [pscustomobject]@{ InterfaceIndex = 3; InterfaceAlias = 'Ethernet'; IPAddress = '192.0.2.25'; PrefixOrigin = [System.Net.NetworkInformation.PrefixOrigin]::Dhcp }
            } -ModuleName Chekap
            $check = $script:byId['NET-DHCP-001']
            $origin = (& $check.Collect $check.Settings).Addresses[0].PrefixOrigin
            $origin | Should -BeOfType [string]
            $origin | Should -Be 'Dhcp'
        }

        It 'returns an empty list when Windows finds no IPv4 address, and silences the cmdlet error' {
            Mock Get-NetIPAddress { } -ModuleName Chekap
            $check = $script:byId['NET-DHCP-001']
            @((& $check.Collect $check.Settings).Addresses).Count | Should -Be 0
            # The real cmdlet writes an error when nothing matches; the mock cannot, so the switch is checked instead.
            Should -Invoke Get-NetIPAddress -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'SilentlyContinue' }
        }
    }

    Context 'NET-GATEWAY-001' {
        It 'pings every distinct gateway once with the configured timeout and skips on-link routes' {
            Mock Get-NetRoute {
                @(
                    [pscustomobject]@{ InterfaceAlias = 'Ethernet'; NextHop = '192.0.2.1' }
                    [pscustomobject]@{ InterfaceAlias = 'Wi-Fi'; NextHop = '192.0.2.1' }
                    [pscustomobject]@{ InterfaceAlias = 'VPN'; NextHop = '0.0.0.0' }
                )
            } -ModuleName Chekap
            Mock Test-ChekapPing { @{ Success = $true; RoundtripMs = 2 } } -ModuleName Chekap
            $check = $script:byId['NET-GATEWAY-001']
            $data = & $check.Collect $check.Settings
            Should -Invoke Get-NetRoute -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $DestinationPrefix -eq '0.0.0.0/0' }
            @($data.Routes).Count | Should -Be 2
            $data.Routes[0].Alias | Should -Be 'Ethernet'
            $data.Routes[0].NextHop | Should -Be '192.0.2.1'
            (@($data.Ping.Keys) -join ',') | Should -Be '192.0.2.1'
            $data.Ping['192.0.2.1'].Success | Should -BeTrue
            $data.Ping['192.0.2.1'].RoundtripMs | Should -Be 2
            Should -Invoke Test-ChekapPing -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '192.0.2.1' -and $TimeoutMs -eq 1000 }
        }

        It 'keeps a silent gateway as a failed ping' {
            Mock Get-NetRoute { [pscustomobject]@{ InterfaceAlias = 'Ethernet'; NextHop = '192.0.2.1' } } -ModuleName Chekap
            Mock Test-ChekapPing { @{ Success = $false; RoundtripMs = $null } } -ModuleName Chekap
            $check = $script:byId['NET-GATEWAY-001']
            (& $check.Collect $check.Settings).Ping['192.0.2.1'].Success | Should -BeFalse
        }

        It 'returns no routes and pings nothing when there is no default route, and silences the cmdlet error' {
            Mock Get-NetRoute { } -ModuleName Chekap
            Mock Test-ChekapPing { } -ModuleName Chekap
            $check = $script:byId['NET-GATEWAY-001']
            $data = & $check.Collect $check.Settings
            @($data.Routes).Count | Should -Be 0
            $data.Ping.Count | Should -Be 0
            Should -Invoke Test-ChekapPing -ModuleName Chekap -Times 0 -Exactly
            # The real cmdlet writes an error when there is no such route; the mock cannot, so the switch is checked instead.
            Should -Invoke Get-NetRoute -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'SilentlyContinue' }
        }
    }

    Context 'NET-DNS-001' {
        BeforeEach {
            Mock Get-NetAdapter {
                @(
                    [pscustomobject]@{ Name = 'Ethernet'; InterfaceIndex = 3; Status = 'Up' }
                    [pscustomobject]@{ Name = 'Wi-Fi'; InterfaceIndex = 5; Status = 'Up' }
                    [pscustomobject]@{ Name = 'Ethernet 2'; InterfaceIndex = 4; Status = 'Disconnected' }
                )
            } -ModuleName Chekap
            Mock Get-DnsClientServerAddress {
                @(
                    [pscustomobject]@{ InterfaceIndex = 3; ServerAddresses = @('192.0.2.53', '192.0.2.54') }
                    [pscustomobject]@{ InterfaceIndex = 5; ServerAddresses = @('192.0.2.53') }
                    [pscustomobject]@{ InterfaceIndex = 4; ServerAddresses = @('192.0.2.99') }
                    [pscustomobject]@{ InterfaceIndex = 3; ServerAddresses = @() }
                )
            } -ModuleName Chekap
            Mock Resolve-DnsName { [pscustomobject]@{ Name = 'localhost'; IPAddress = '127.0.0.1' } } -ModuleName Chekap
            Mock Get-CimInstance { [pscustomobject]@{ PartOfDomain = $false; Domain = 'WORKGROUP' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
        }

        It 'lists each server of the connected adapters once, in order, and asks it for ProbeName' {
            $check = $script:byId['NET-DNS-001']
            $data = & $check.Collect $check.Settings
            Should -Invoke Get-DnsClientServerAddress -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $AddressFamily -eq 'IPv4' }
            (@($data.Servers) -join ',') | Should -Be '192.0.2.53,192.0.2.54'
            @($data.Probe.Keys).Count | Should -Be 2
            Should -Invoke Resolve-DnsName -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'localhost' -and $Server -eq '192.0.2.53' -and $DnsOnly -and $QuickTimeout }
            Should -Invoke Resolve-DnsName -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'localhost' -and $Server -eq '192.0.2.54' -and $DnsOnly -and $QuickTimeout }
            foreach ($ip in '192.0.2.53', '192.0.2.54') {
                $data.Probe[$ip].Responds | Should -BeTrue
                $data.Probe[$ip].Responds | Should -BeOfType [bool]
                $data.Probe[$ip].Ms | Should -BeOfType [int]
                $data.Probe[$ip].Ms | Should -BeGreaterOrEqual 0
            }
            $data.PartOfDomain | Should -BeFalse
        }

        It 'treats DNS rcode error <Code> (<Meaning>) as Responds=<Responds>' -ForEach $script:rcodeCases {
            Mock Resolve-DnsName { throw (New-Object System.ComponentModel.Win32Exception $Code) }.GetNewClosure() -ModuleName Chekap
            $check = $script:byId['NET-DNS-001']
            $data = & $check.Collect $check.Settings
            $data.Probe['192.0.2.53'].Responds | Should -Be $Responds
            $data.Probe['192.0.2.54'].Responds | Should -Be $Responds
        }

        It 'treats a failure without a native error code as no answer' {
            Mock Resolve-DnsName { throw 'something else broke' } -ModuleName Chekap
            $check = $script:byId['NET-DNS-001']
            { & $check.Collect $check.Settings } | Should -Not -Throw
            (& $check.Collect $check.Settings).Probe['192.0.2.53'].Responds | Should -BeFalse
        }

        It 'judges every server by its own answer' {
            Mock Resolve-DnsName { throw (New-Object System.ComponentModel.Win32Exception 1460) } -ModuleName Chekap -ParameterFilter { $Server -eq '192.0.2.54' }
            $check = $script:byId['NET-DNS-001']
            $data = & $check.Collect $check.Settings
            $data.Probe['192.0.2.53'].Responds | Should -BeTrue
            $data.Probe['192.0.2.54'].Responds | Should -BeFalse
        }

        It 'reports PartOfDomain' {
            Mock Get-CimInstance { [pscustomobject]@{ PartOfDomain = $true; Domain = 'contoso.local' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            $check = $script:byId['NET-DNS-001']
            $data = & $check.Collect $check.Settings
            $data.PartOfDomain | Should -BeOfType [bool]
            $data.PartOfDomain | Should -BeTrue
        }

        It 'returns no servers and probes nothing when the adapters have none, and silences the cmdlet error' {
            Mock Get-DnsClientServerAddress { } -ModuleName Chekap
            $check = $script:byId['NET-DNS-001']
            $data = & $check.Collect $check.Settings
            @($data.Servers).Count | Should -Be 0
            $data.Probe.Count | Should -Be 0
            Should -Invoke Resolve-DnsName -ModuleName Chekap -Times 0 -Exactly
            # The real cmdlet writes an error when nothing matches; the mock cannot, so the switch is checked instead.
            Should -Invoke Get-DnsClientServerAddress -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'SilentlyContinue' }
        }
    }

    Context 'NET-DNS-002' {
        It 'resolves the domain and the external name with the system resolver, type A' {
            Mock Get-CimInstance { [pscustomobject]@{ PartOfDomain = $true; Domain = 'contoso.local' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            Mock Resolve-DnsName { [pscustomobject]@{ IPAddress = '192.0.2.10' } } -ModuleName Chekap
            $check = $script:byId['NET-DNS-002']
            $data = & $check.Collect $check.Settings
            Should -Invoke Resolve-DnsName -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'contoso.local' -and $Type -eq 'A' -and $DnsOnly -and $QuickTimeout -and -not $Server }
            Should -Invoke Resolve-DnsName -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'www.microsoft.com' -and $Type -eq 'A' -and $DnsOnly -and $QuickTimeout -and -not $Server }
            $data.Domain | Should -Be 'contoso.local'
            $data.PartOfDomain | Should -BeTrue
            $data.DomainResolves | Should -BeTrue
            $data.DomainResolves | Should -BeOfType [bool]
            $data.ExternalResolves | Should -BeTrue
        }

        It 'reports a failing lookup as false' {
            Mock Get-CimInstance { [pscustomobject]@{ PartOfDomain = $true; Domain = 'contoso.local' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            Mock Resolve-DnsName { [pscustomobject]@{ IPAddress = '192.0.2.10' } } -ModuleName Chekap
            Mock Resolve-DnsName { throw (New-Object System.ComponentModel.Win32Exception 9003) } -ModuleName Chekap -ParameterFilter { $Name -eq 'www.microsoft.com' }
            $check = $script:byId['NET-DNS-002']
            $data = & $check.Collect $check.Settings
            $data.DomainResolves | Should -BeTrue
            $data.ExternalResolves | Should -BeFalse
            $data.ExternalResolves | Should -BeOfType [bool]
        }

        It 'does not look up the domain name outside a domain' {
            Mock Get-CimInstance { [pscustomobject]@{ PartOfDomain = $false; Domain = 'WORKGROUP' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            Mock Resolve-DnsName { [pscustomobject]@{ IPAddress = '192.0.2.10' } } -ModuleName Chekap
            $check = $script:byId['NET-DNS-002']
            $data = & $check.Collect $check.Settings
            $data.PartOfDomain | Should -BeFalse
            $data.DomainResolves | Should -BeNullOrEmpty
            $data.ExternalResolves | Should -BeTrue
            Should -Invoke Resolve-DnsName -ModuleName Chekap -Times 1 -Exactly
            Should -Invoke Resolve-DnsName -ModuleName Chekap -Times 0 -Exactly -ParameterFilter { $Name -eq 'WORKGROUP' }
        }
    }

    Context 'NET-INTERNET-001' {
        It 'tests the configured host, port and timeout' {
            Mock Test-ChekapTcpPort { $true } -ModuleName Chekap
            $check = $script:byId['NET-INTERNET-001']
            $data = & $check.Collect $check.Settings
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'www.microsoft.com' -and $Port -eq 443 -and $TimeoutMs -eq 3000 }
            $data.Reachable | Should -BeOfType [bool]
            $data.Reachable | Should -BeTrue
        }

        It 'reports a refused or silent host as not reachable' {
            Mock Test-ChekapTcpPort { $false } -ModuleName Chekap
            $check = $script:byId['NET-INTERNET-001']
            (& $check.Collect $check.Settings).Reachable | Should -BeFalse
        }
    }

    Context 'NET-PROXY-001' {
        BeforeEach {
            Mock Get-ItemProperty { $null } -ModuleName Chekap
            Mock Test-ChekapTcpPort { $true } -ModuleName Chekap
        }

        It 'reads the user proxy and tests it' {
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyEnable = 1; ProxyServer = 'proxy.contoso.local:3128' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Internet Settings' }
            $check = $script:byId['NET-PROXY-001']
            $data = & $check.Collect $check.Settings
            $data.UserEnabled | Should -BeTrue
            $data.UserEnabled | Should -BeOfType [bool]
            $data.UserServer | Should -Be 'proxy.contoso.local:3128'
            $data.WinHttpProxy | Should -BeNullOrEmpty
            $data.Reachable['proxy.contoso.local:3128'] | Should -BeTrue
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'proxy.contoso.local' -and $Port -eq 3128 -and $TimeoutMs -eq 1000 }
        }

        It 'reports a proxy that does not accept connections' {
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyEnable = 1; ProxyServer = 'proxy.contoso.local:3128' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Internet Settings' }
            Mock Test-ChekapTcpPort { $false } -ModuleName Chekap
            $check = $script:byId['NET-PROXY-001']
            (& $check.Collect $check.Settings).Reachable['proxy.contoso.local:3128'] | Should -BeFalse
        }

        It 'is direct when nothing is configured' {
            $check = $script:byId['NET-PROXY-001']
            $data = & $check.Collect $check.Settings
            $data.UserEnabled | Should -BeFalse
            $data.UserServer | Should -BeNullOrEmpty
            $data.AutoConfigUrl | Should -BeNullOrEmpty
            $data.WinHttpProxy | Should -BeNullOrEmpty
            $data.Reachable.Count | Should -Be 0
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 0 -Exactly
        }

        It 'ignores a user proxy that is switched off' {
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyEnable = 0; ProxyServer = 'proxy.contoso.local:3128' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Internet Settings' }
            $check = $script:byId['NET-PROXY-001']
            $data = & $check.Collect $check.Settings
            $data.UserEnabled | Should -BeFalse
            $data.Reachable.Count | Should -Be 0
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 0 -Exactly
        }

        It 'reads the configuration script URL, and an empty one is none' {
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyEnable = 0; AutoConfigURL = 'http://wpad.contoso.local/proxy.pac' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Internet Settings' }
            $check = $script:byId['NET-PROXY-001']
            (& $check.Collect $check.Settings).AutoConfigUrl | Should -Be 'http://wpad.contoso.local/proxy.pac'
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyEnable = 0; AutoConfigURL = '' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Internet Settings' }
            (& $check.Collect $check.Settings).AutoConfigUrl | Should -BeNullOrEmpty
        }

        It 'decodes WinHttpSettings bytes' {
            $blob = & $script:winHttpBlob 3 'proxy.contoso.local:3128'
            Mock Get-ItemProperty { [pscustomobject]@{ WinHttpSettings = $blob } }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*Internet Settings\Connections' }
            $check = $script:byId['NET-PROXY-001']
            $data = & $check.Collect $check.Settings
            $data.WinHttpProxy | Should -Be 'proxy.contoso.local:3128'
            $data.Reachable['proxy.contoso.local:3128'] | Should -BeTrue
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'proxy.contoso.local' -and $Port -eq 3128 }
        }

        It 'WinHttpProxy is null when the WinHttpSettings value is missing' {
            Mock Get-ItemProperty { [pscustomobject]@{ DefaultConnectionSettings = [byte[]](1, 2, 3) } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*Internet Settings\Connections' }
            $check = $script:byId['NET-PROXY-001']
            (& $check.Collect $check.Settings).WinHttpProxy | Should -BeNullOrEmpty
        }

        It 'WinHttpProxy is null when WinHTTP goes direct (flags 1, no proxy text)' {
            $blob = & $script:winHttpBlob 1 ''
            Mock Get-ItemProperty { [pscustomobject]@{ WinHttpSettings = $blob } }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*Internet Settings\Connections' }
            $check = $script:byId['NET-PROXY-001']
            $data = & $check.Collect $check.Settings
            $data.WinHttpProxy | Should -BeNullOrEmpty
            $data.Reachable.Count | Should -Be 0
        }

        It 'WinHttpProxy follows the proxy bit of the flags: flags <Flags> gives <Expected>' -ForEach @(
            @{ Flags = 1; Expected = '$null' }
            @{ Flags = 5; Expected = '$null' }
            @{ Flags = 3; Expected = 'the proxy' }
            @{ Flags = 11; Expected = 'the proxy' }
        ) {
            $blob = & $script:winHttpBlob $Flags 'proxy.contoso.local:3128'
            Mock Get-ItemProperty { [pscustomobject]@{ WinHttpSettings = $blob } }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*Internet Settings\Connections' }
            $check = $script:byId['NET-PROXY-001']
            $proxy = (& $check.Collect $check.Settings).WinHttpProxy
            if ($Expected -eq 'the proxy') { $proxy | Should -Be 'proxy.contoso.local:3128' } else { $proxy | Should -BeNullOrEmpty }
        }

        It 'WinHttpProxy is null when the stored length runs past the data' {
            $blob = [byte[]](0x28, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 200, 0, 0, 0, 0x61, 0x62)
            Mock Get-ItemProperty { [pscustomobject]@{ WinHttpSettings = $blob } }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*Internet Settings\Connections' }
            $check = $script:byId['NET-PROXY-001']
            { & $check.Collect $check.Settings } | Should -Not -Throw
            (& $check.Collect $check.Settings).WinHttpProxy | Should -BeNullOrEmpty
        }

        It 'tests the first host:port of a per-protocol list, once for both sources' {
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyEnable = 1; ProxyServer = 'http=proxy.contoso.local:3128;https=other.contoso.local:3129' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Internet Settings' }
            $blob = & $script:winHttpBlob 3 'proxy.contoso.local:3128'
            Mock Get-ItemProperty { [pscustomobject]@{ WinHttpSettings = $blob } }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*Internet Settings\Connections' }
            $check = $script:byId['NET-PROXY-001']
            $data = & $check.Collect $check.Settings
            $data.Reachable.Count | Should -Be 1
            $data.Reachable.ContainsKey('proxy.contoso.local:3128') | Should -BeTrue
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly
        }

        It 'leaves a URL scheme out of the host' {
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyEnable = 1; ProxyServer = 'http://proxy.contoso.local:3128' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Internet Settings' }
            $check = $script:byId['NET-PROXY-001']
            $data = & $check.Collect $check.Settings
            $data.Reachable.ContainsKey('proxy.contoso.local:3128') | Should -BeTrue
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'proxy.contoso.local' -and $Port -eq 3128 }
        }

        It 'does not test a proxy written without a valid port' -ForEach @(@{ Server = 'proxy.contoso.local' }, @{ Server = 'proxy.contoso.local:99999' }, @{ Server = 'proxy.contoso.local:0' }) {
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyEnable = 1; ProxyServer = $Server } }.GetNewClosure() -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKCU:*Internet Settings' }
            $check = $script:byId['NET-PROXY-001']
            { & $check.Collect $check.Settings } | Should -Not -Throw
            (& $check.Collect $check.Settings).Reachable.Count | Should -Be 0
            Should -Invoke Test-ChekapTcpPort -ModuleName Chekap -Times 0 -Exactly
        }
    }

    Context 'NET-PROFILE-001' {
        It 'maps profiles and turns the category enum into a string' {
            Mock Get-NetConnectionProfile {
                @(
                    [pscustomobject]@{ InterfaceAlias = 'Ethernet'; Name = 'contoso.local'; NetworkCategory = [ChekapTestNetworkCategory]::DomainAuthenticated }
                    [pscustomobject]@{ InterfaceAlias = 'Wi-Fi'; Name = 'Guest Network'; NetworkCategory = [ChekapTestNetworkCategory]::Public }
                )
            } -ModuleName Chekap
            $check = $script:byId['NET-PROFILE-001']
            $data = & $check.Collect $check.Settings
            @($data.Profiles).Count | Should -Be 2
            $data.Profiles[0].Alias | Should -Be 'Ethernet'
            $data.Profiles[0].Name | Should -Be 'contoso.local'
            $data.Profiles[0].Category | Should -BeOfType [string]
            $data.Profiles[0].Category | Should -Be 'DomainAuthenticated'
            $data.Profiles[1].Category | Should -Be 'Public'
        }

        It 'returns an empty list when Windows reports no profile, and silences the cmdlet error' {
            Mock Get-NetConnectionProfile { } -ModuleName Chekap
            $check = $script:byId['NET-PROFILE-001']
            @((& $check.Collect $check.Settings).Profiles).Count | Should -Be 0
            # The real cmdlet writes an error when the Network List Service does not run; the mock cannot, so the switch is checked instead.
            Should -Invoke Get-NetConnectionProfile -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'SilentlyContinue' }
        }
    }

    Context 'NET-TIME-001' {
        BeforeEach {
            Mock Get-ItemProperty { [pscustomobject]@{ Type = 'NTP'; NtpServer = 'ntp.contoso.local,0x9' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*W32Time*Parameters' }
            Mock Get-CimInstance { [pscustomobject]@{ PartOfDomain = $false; Domain = 'WORKGROUP' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            Mock Get-Service { [pscustomobject]@{ Status = 'Running' } } -ModuleName Chekap
            Mock w32tm { 'Tracking ntp.contoso.local [192.0.2.10:123].', 'Collecting 1 samples.', '12:00:01, +00.0123456s' } -ModuleName Chekap
        }

        It 'parses comma decimal' {
            Mock w32tm { 'Відстеження contoso.local [192.0.2.10:123].', '12:00:01, +00,0123456s' } -ModuleName Chekap
            $check = $script:byId['NET-TIME-001']
            $data = & $check.Collect $check.Settings
            $data.OffsetSeconds | Should -BeOfType [double]
            $data.OffsetSeconds | Should -BeGreaterThan 0.0123455
            $data.OffsetSeconds | Should -BeLessThan 0.0123457
        }

        It 'parses a negative offset with a decimal point' {
            Mock w32tm { '12:00:01, -01.5000000s' } -ModuleName Chekap
            $check = $script:byId['NET-TIME-001']
            (& $check.Collect $check.Settings).OffsetSeconds | Should -Be (-1.5)
        }

        It 'returns null offset on error output' {
            Mock w32tm { 'Tracking ntp.contoso.local [192.0.2.10:123].', '12:00:01, error: 0x800705B4' } -ModuleName Chekap
            $check = $script:byId['NET-TIME-001']
            $data = & $check.Collect $check.Settings
            $data.OffsetSeconds | Should -BeNullOrEmpty
            @($data.Output).Count | Should -Be 2
        }

        It 'returns null offset when w32tm prints no data line' {
            Mock w32tm { 'The following error occurred: No such host is known. (0x80072AF9)' } -ModuleName Chekap
            $check = $script:byId['NET-TIME-001']
            (& $check.Collect $check.Settings).OffsetSeconds | Should -BeNullOrEmpty
        }

        It 'takes the last line that matches' {
            Mock w32tm { '12:00:01, +00,5000000s', '12:00:03, -00,2500000s' } -ModuleName Chekap
            $check = $script:byId['NET-TIME-001']
            (& $check.Collect $check.Settings).OffsetSeconds | Should -Be (-0.25)
        }

        It 'does not depend on the current culture' {
            $original = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('uk-UA')
                $check = $script:byId['NET-TIME-001']
                (& $check.Collect $check.Settings).OffsetSeconds | Should -BeGreaterThan 0.0123455
                (& $check.Collect $check.Settings).OffsetSeconds | Should -BeLessThan 0.0123457
            }
            finally {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $original
            }
        }

        It 'asks the first NtpServer entry for one data-only sample, without its flags' {
            $check = $script:byId['NET-TIME-001']
            $data = & $check.Collect $check.Settings
            $data.Type | Should -Be 'NTP'
            $data.NtpServer | Should -Be 'ntp.contoso.local,0x9'
            $data.Source | Should -Be 'ntp.contoso.local'
            Should -Invoke w32tm -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $args -contains '/stripchart' -and $args -contains '/computer:ntp.contoso.local' -and $args -contains '/samples:1' -and $args -contains '/dataonly' }
            $data.OffsetSeconds | Should -BeGreaterThan 0.0123455
        }

        It 'takes only the first of several NtpServer entries' {
            Mock Get-ItemProperty { [pscustomobject]@{ Type = 'NTP'; NtpServer = ' ntp.contoso.local,0x8 pool.contoso.local,0x9' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*W32Time*Parameters' }
            $check = $script:byId['NET-TIME-001']
            (& $check.Collect $check.Settings).Source | Should -Be 'ntp.contoso.local'
        }

        It 'takes an NtpServer entry that has no flags as it is' {
            Mock Get-ItemProperty { [pscustomobject]@{ Type = 'NTP'; NtpServer = '192.0.2.123' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*W32Time*Parameters' }
            $check = $script:byId['NET-TIME-001']
            (& $check.Collect $check.Settings).Source | Should -Be '192.0.2.123'
        }

        It 'asks the domain when the PC is in a domain and gets time from it (NT5DS)' {
            Mock Get-ItemProperty { [pscustomobject]@{ Type = 'NT5DS'; NtpServer = 'time.contoso.local,0x9' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*W32Time*Parameters' }
            Mock Get-CimInstance { [pscustomobject]@{ PartOfDomain = $true; Domain = 'contoso.local' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            $check = $script:byId['NET-TIME-001']
            $data = & $check.Collect $check.Settings
            $data.Source | Should -Be 'contoso.local'
            Should -Invoke w32tm -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $args -contains '/computer:contoso.local' }
        }

        It 'NT5DS outside a domain falls back to the NtpServer entry' {
            Mock Get-ItemProperty { [pscustomobject]@{ Type = 'NT5DS'; NtpServer = 'time.contoso.local,0x9' } } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*W32Time*Parameters' }
            $check = $script:byId['NET-TIME-001']
            (& $check.Collect $check.Settings).Source | Should -Be 'time.contoso.local'
        }

        It 'a domain PC that uses NTP asks the NtpServer entry' {
            Mock Get-CimInstance { [pscustomobject]@{ PartOfDomain = $true; Domain = 'contoso.local' } } -ModuleName Chekap -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            $check = $script:byId['NET-TIME-001']
            (& $check.Collect $check.Settings).Source | Should -Be 'ntp.contoso.local'
        }

        It 'has no source, no offset and no w32tm call when nothing is configured' {
            Mock Get-ItemProperty { $null } -ModuleName Chekap -ParameterFilter { $LiteralPath -like 'HKLM:*W32Time*Parameters' }
            $check = $script:byId['NET-TIME-001']
            $data = & $check.Collect $check.Settings
            $data.Source | Should -BeNullOrEmpty
            $data.OffsetSeconds | Should -BeNullOrEmpty
            Should -Invoke w32tm -ModuleName Chekap -Times 0 -Exactly
        }

        It 'reports the state of the Windows Time service as a string' {
            $check = $script:byId['NET-TIME-001']
            $status = (& $check.Collect $check.Settings).ServiceStatus
            $status | Should -BeOfType [string]
            $status | Should -Be 'Running'
        }

        It 'has a null service state when the service is missing, and silences the cmdlet error' {
            Mock Get-Service { } -ModuleName Chekap
            $check = $script:byId['NET-TIME-001']
            (& $check.Collect $check.Settings).ServiceStatus | Should -BeNullOrEmpty
            # The real cmdlet writes an error for an unknown service; the mock cannot, so the switch is checked instead.
            Should -Invoke Get-Service -ModuleName Chekap -Times 1 -Exactly -ParameterFilter { $Name -eq 'W32Time' -and $ErrorAction -eq 'SilentlyContinue' }
        }
    }
}

Describe 'Test-ChekapNetwork' {
    BeforeEach {
        Mock Invoke-ChekapCheck { } -ModuleName Chekap
    }

    It 'runs all Network checks in the requested language' {
        Test-ChekapNetwork -Language en
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $Language -eq 'en' -and @($Check).Count -eq 9 -and @($Check | Where-Object { $_.Category -ne 'Network' }).Count -eq 0
        }
    }

    It 'selects checks by -CheckId, wildcards allowed' {
        Test-ChekapNetwork -Language uk -CheckId 'NET-DNS-*', 'NET-TIME-001'
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 1 -Exactly -ParameterFilter {
            $Language -eq 'uk' -and (@($Check | ForEach-Object { $_.Id }) -join ',') -eq 'NET-DNS-001,NET-DNS-002,NET-TIME-001'
        }
    }

    It 'does not return a System check even when its ID is asked for' {
        $result = @(Test-ChekapNetwork -Language en -CheckId 'SYS-DISK-001' -WarningAction SilentlyContinue)
        $result.Count | Should -Be 0
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 0 -Exactly
    }

    It 'warns about an unknown ID and returns nothing' {
        $result = @(Test-ChekapNetwork -Language en -CheckId 'NET-NOPE-999' -WarningVariable warnings -WarningAction SilentlyContinue)
        $result.Count | Should -Be 0
        @($warnings).Count | Should -Be 1
        Should -Invoke Invoke-ChekapCheck -ModuleName Chekap -Times 0 -Exactly
    }
}

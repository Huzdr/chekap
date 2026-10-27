function Get-ChekapSystemInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # The passport is context for the report. A query that fails leaves its fields $null instead of failing the audit.
    $os = try { Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop } catch { $null }
    $system = try { Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop } catch { $null }
    $processor = try { Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch { $null }
    $version = try { Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'DisplayVersion' -ErrorAction Stop } catch { $null }
    # An assignment inside try keeps an empty list an array; "$x = try {...}" would unroll it to $null.
    $addresses = @()
    try {
        $indexes = @(Get-ChekapConnectedInterface | ForEach-Object { $_.Index })
        $addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.InterfaceIndex -in $indexes } |
                Sort-Object -Property InterfaceIndex, IPAddress | ForEach-Object { [string]$_.IPAddress })
    }
    catch {
        $addresses = @()
    }

    @{
        ComputerName     = $env:COMPUTERNAME
        OsCaption        = if ($os) { [string]$os.Caption } else { $null }
        OsBuild          = if ($os) { [int]$os.BuildNumber } else { $null }
        OsDisplayVersion = if ($version -and $version.DisplayVersion) { [string]$version.DisplayVersion } else { $null }
        Manufacturer     = if ($system) { [string]$system.Manufacturer } else { $null }
        Model            = if ($system) { [string]$system.Model } else { $null }
        Cpu              = if ($processor) { ([string]$processor.Name).Trim() } else { $null }
        RamGB            = if ($system) { [int][math]::Round($system.TotalPhysicalMemory / 1GB) } else { $null }
        LastBoot         = if ($os) { [datetime]$os.LastBootUpTime } else { $null }
        IPv4             = [string[]]$addresses
        Domain           = if ($system) { [string]$system.Domain } else { $null }
        PartOfDomain     = if ($system) { [bool]$system.PartOfDomain } else { $null }
    }
}

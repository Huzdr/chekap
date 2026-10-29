---
external help file: Chekap-help.xml
Module Name: Chekap
online version:
schema: 2.0.0
---

# Test-ChekapNetwork

## SYNOPSIS
Checks the network of this PC: adapters, addresses, gateway, DNS, internet access, proxy, network profile and clock.

## SYNTAX

```
Test-ChekapNetwork [[-Language] <String>] [[-CheckId] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Runs the Network checks and returns one Chekap.CheckResult object for each finding. The checks look at: the network adapter and its speed, the IP address from DHCP (an automatic address 169.254.x.x means that no DHCP server answered), the DNS servers, name resolution, the default gateway, internet access, the proxy settings, the network profile (Public, Private or Domain) and time synchronization (a clock that is far off breaks Kerberos and TLS).

The checks do not change anything and need no administrator rights. They do talk to the network: a ping to the default gateway, a DNS query to each of your DNS servers, a connection to the proxy server if one is set, one time query to your time source, a name lookup of www.microsoft.com (and of the domain name on a domain PC), and one connection to port 443 of www.microsoft.com for the internet check. The ping, the DNS queries and the TCP connections have a short time limit, so a server that does not answer cannot make the check hang. The time query is made by the standard w32tm tool, which has its own time limit.

Every result has a Status: OK, Warning, Critical, Error (the check itself could not finish) or Skipped (the check does not apply). The Status values are always in English, so scripts work in any language. Title, Details and Recommendation are in the language of the texts: the one from the Language parameter if you give it, otherwise the one saved with Set-ChekapConfig, otherwise the language of the Windows interface.

## EXAMPLES

### Example 1: Run all Network checks
```powershell
Test-ChekapNetwork
```

Runs every Network check and shows the findings in a table: status, check ID, target and title.

### Example 2: Show only what needs attention
```powershell
Test-ChekapNetwork -Language en | Where-Object Status -in 'Warning', 'Critical' | Format-List CheckId, Target, Details, Recommendation
```

Shows the warnings and critical findings in English, each with what was found and what to do.

### Example 3: Run only the gateway and DNS checks
```powershell
Test-ChekapNetwork -CheckId NET-GATEWAY-001, NET-DNS-* | Format-List
```

Runs the gateway check and all the DNS checks and shows every property of their results.

## PARAMETERS

### -Language
Language of the texts: uk (Ukrainian) or en (English). Without it Chekap uses the language saved with Set-ChekapConfig, and without a saved language the language of the Windows interface.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CheckId
Run only these checks. Exact IDs or wildcards, for example NET-DNS-001 or NET-DNS-*. Only Network checks are considered here, so an ID of another category selects nothing. An ID that matches no check at all gives a warning. If no check is selected the command returns nothing.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
The command does not take objects from the pipeline.

## OUTPUTS

### Chekap.CheckResult
One object for each finding with the properties CheckId, Category, ComputerName, Status, Target, Title, Details, Recommendation, FixId, FixRiskLevel, Evidence, References and Timestamp. FixId and FixRiskLevel are empty in this version.

## NOTES

## RELATED LINKS

[Invoke-ChekapAudit](Invoke-ChekapAudit.md)

[Test-ChekapHealth](Test-ChekapHealth.md)

[Test-ChekapPrinting](Test-ChekapPrinting.md)

[Get-ChekapCheck](Get-ChekapCheck.md)

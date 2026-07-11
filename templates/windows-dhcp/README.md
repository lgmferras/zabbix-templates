# Windows DHCP Server by Zabbix agent active

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-2.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_active-339933?style=flat-square)
![OS](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

Zabbix template for monitoring the DHCP service on Windows Server via active Zabbix Agent 2.

**Version:** 2.0
**Zabbix:** 7.4
**Agent:** Zabbix Agent 2 (active mode) + PowerShell
**Operating system:** Windows Server 2016+ (DHCP Server role)

---

## Files

| File | Destination on Windows | Description |
|---|---|---|
| `dhcp_zbx.ps1` | `C:\Program Files\Zabbix Agent 2\` | Main PowerShell collection script |
| `userparameter_dhcp.conf` | `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` | Agent UserParameters |
| `template.json` | Import into Zabbix | Zabbix template |

---

## Installation

### 1. Copy files to the Windows Server

```powershell
# Copy the script
Copy-Item dhcp_zbx.ps1 "C:\Program Files\Zabbix Agent 2\"

# Copy the userparameters
Copy-Item userparameter_dhcp.conf "C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\"
```

### 2. Configure Zabbix Agent 2

The main agent config file (`C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf`) must have:

```ini
ServerActive=<ZABBIX-SERVER-IP>   # Zabbix Server IP
Hostname=<HOST-NAME-IN-ZABBIX>    # Exact host name in Zabbix
UnsafeUserParameters=1            # Required to pass arguments to the script
Include=C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\
```

> The `Include` directive automatically loads `userparameter_dhcp.conf`.

### 3. Restart the agent

```powershell
Restart-Service "Zabbix Agent 2"
```

### 4. Test locally

```powershell
# Test that the script works (requires the DhcpServer module)
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4ScopesCount
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4LeasesTotal
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4Utilization
```

### 5. Import the template and apply it to the host

1. In the Zabbix Web UI: **Data collection → Templates → Import**
2. Import `template.json`
3. Apply the template to the Windows Server host running DHCP

---

## Monitored items

| Key | Type | Description |
|---|---|---|
| `service.info[DHCPServer,state]` | uint | DHCP service state (0 = running) |
| `dhcp.v4.scopes.count` | uint | Number of configured IPv4 scopes |
| `dhcp.v4.leases.total` | uint | Total addresses across all scopes |
| `dhcp.v4.leases.used` | uint | Addresses in use (global) |
| `dhcp.v4.utilization` | float | Global scope pool utilization (%) |

---

## Per-scope items (LLD, v2.0+)

The `dhcp.v4.scope.discovery` discovery rule automatically creates the items below for each discovered IPv4 scope (macros `{#SCOPEID}`, `{#SCOPENAME}`):

| Key | Type | Description |
|---|---|---|
| `dhcp.v4.scope.details[{#SCOPEID}]` | TEXT (master) | Raw JSON — not used directly, feeds the dependent items below |
| `dhcp.v4.scope.name[{#SCOPEID}]` | CHAR | Scope name configured in DHCP |
| `dhcp.v4.scope.leases.total[{#SCOPEID}]` | uint | Total addresses in the scope |
| `dhcp.v4.scope.leases.used[{#SCOPEID}]` | uint | Addresses in use in the scope |
| `dhcp.v4.scope.utilization[{#SCOPEID}]` | float, % | Scope utilization |
| `dhcp.v4.scope.gateway[{#SCOPEID}]` | CHAR | Gateway (option 003) |
| `dhcp.v4.scope.dns[{#SCOPEID}]` | TEXT | DNS servers (option 006), JSON array |
| `dhcp.v4.scope.domain[{#SCOPEID}]` | CHAR | Domain (option 015) |
| `dhcp.v4.scope.reservations.count[{#SCOPEID}]` | uint | Number of reservations |
| `dhcp.v4.scope.reservations.json[{#SCOPEID}]` | TEXT | List of reservations (IP+MAC+name), JSON array |
| `dhcp.v4.scope.exclusions.count[{#SCOPEID}]` | uint | Number of exclusion ranges |
| `dhcp.v4.scope.exclusions.json[{#SCOPEID}]` | TEXT | List of exclusion ranges, JSON array |

**Trigger:** *"Scope {#SCOPENAME}: no gateway/DNS configured"* (WARNING) — fires when `gateway` or `dns` come back empty.

> The discovery rule uses the `dhcp.v4.scope.discovery` key, already present in `userparameter_dhcp.conf` since v1.0 (documented as "manual use"). Hosts already running the v1.0 script **need no change** for the LLD itself — only the `dhcp.v4.scope.details[{#SCOPEID}]` item (and its dependents) requires the v2.0 script/conf update.

### Additional UserParameters (available for manual use)

| Key | Description |
|---|---|
| `dhcp.ipv4.enabled` | DHCP IPv4 enabled/disabled |
| `dhcp.ipv6.enabled` | DHCP IPv6 enabled/disabled |
| `dhcp.db.path` | Path to the DHCP database |
| `dhcp.backup.path` | Path to the database backup |
| `dhcp.v4.scope.discovery` | LLD — scope discovery |
| `dhcp.v4.scope.stats[{scopeid}]` | Per-scope stats JSON |
| `dhcp.v4.scope.get[{scopeid}]` | Per-scope details JSON |
| `dhcp.v4.scope.reservations.count[{scopeid}]` | Reservations per scope |
| `dhcp.v4.scope.options.count[{scopeid}]` | Options per scope |

---

## Requirements

- Windows Server with the **DHCP Server** role installed
- PowerShell `DhcpServer` module available (`Import-Module DhcpServer`)
- Zabbix Agent 2 installed at `C:\Program Files\Zabbix Agent 2\`
- `UnsafeUserParameters=1` on the agent (required to pass arguments to the script)

---

## Troubleshooting

**"Unknown metric dhcp.v4.leases.total"**
`userparameter_dhcp.conf` is not being loaded. Check:
- That the file is in `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\`
- That `Include=C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` is set in the main conf
- Restart the service after any change

**"Value of type string is not suitable for value type Numeric"**
UTF-8 BOM issue in the PowerShell output. The script already includes the fix:
```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
```
If the error persists, verify the `.ps1` file was saved without a BOM (use VS Code with "UTF-8" without BOM).

**Script returns "0" with no error**
The `DhcpServer` module is not available. Check:
```powershell
Get-Module -ListAvailable DhcpServer
```
The module is installed automatically with the Windows DHCP Server role.

---

## Changelog

| Version | Changes |
|---|---|
| 2.0 | Added the `dhcp.v4.scope.discovery` discovery rule (per-scope LLD) with 11 item prototypes (name, leases, utilization, gateway, DNS, domain, reservations and exclusions) and the "no gateway/DNS configured" trigger prototype; fixed `V4ScopeDiscovery` single-scope JSON array collapse; fixed `V4ScopeStats`/`V4ScopeDetails` totals to use `InUse + Free` instead of `AddressesTotal` |
| 1.0 | Initial release — service state, IPv4 leases total/active and pool utilization trigger |

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

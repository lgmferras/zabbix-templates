# Sophos Firewall by SNMP

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-SNMP_v2c-7F13EC?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

| | |
|---|---|
| **Category** | Network Devices / Security |
| **Collection method** | SNMP v2c (`XG-FIREWALL-MIB`) |
| **Items** | 15 |
| **Zabbix version** | 7.4+ |

## Description

Monitors Sophos XG/XGS appliances (SFOS) over SNMP v2c using the vendor's proprietary `XG-FIREWALL-MIB` (enterprise OID `1.3.6.1.4.1.21067`). Covers CPU, memory and disk utilization, active portal users, WAN gateway failover state, and inbound/outbound throughput on the WAN1, WAN2 and LAN interfaces.

The template's centerpiece is its **WAN failover trigger**: it fires when the Sophos itself reports the backup gateway (WAN2) as active, which means the firewall has already detected the primary link (WAN1) as down and rerouted traffic. This is the most reliable way to detect a failover event — even if SNMP polling is briefly interrupted during the outage, the state is captured as soon as the appliance reconnects and history is backfilled.

Tested on a Sophos XG105 running SFOS 17.5.x. Expected to work on any XG/XGS appliance running SFOS 17.x–20.x, since the MIB has been stable across those releases.

Designed to be paired with the [Dual WAN Primary Link](../dual-wan-primary/) and [Dual WAN Backup Link](../dual-wan-backup/) templates in a 3-host architecture: the WAN1/WAN2 hosts use Simple Checks against each public IP independently (so they stay reachable even if the firewall's own SNMP interface goes down during a failover), while this template polls the firewall itself for internal health and gateway status.

> **Note:** the Sophos XG does not expose the standard `HOST-RESOURCES-MIB` (no `hrProcessorLoad`, `hrStorageSize`, etc.), so all system health metrics are collected through the vendor-specific MIB instead.

## Macros

| Macro | Default | Description |
|---|---|---|
| `{$SOPHOS.CPU.UTIL.WARN}` | `80` | CPU usage (%) that raises a WARNING trigger |
| `{$SOPHOS.CPU.UTIL.HIGH}` | `90` | CPU usage (%) that raises a HIGH trigger |
| `{$SOPHOS.MEM.UTIL.WARN}` | `80` | Memory usage (%) that raises a WARNING trigger |
| `{$SOPHOS.MEM.UTIL.HIGH}` | `90` | Memory usage (%) that raises a HIGH trigger |
| `{$SOPHOS.DISK.UTIL.WARN}` | `80` | Disk usage (%) that raises a WARNING trigger |
| `{$SOPHOS.DISK.UTIL.HIGH}` | `90` | Disk usage (%) that raises a HIGH trigger |
| `{$SOPHOS.IF.WAN1.NAME}` | `Port1` | WAN1 interface name as reported by `ifDescr` |
| `{$SOPHOS.IF.WAN1.INDEX}` | `5` | SNMP `ifIndex` of the WAN1 interface |
| `{$SOPHOS.IF.WAN2.NAME}` | `Port2` | WAN2/backup interface name as reported by `ifDescr` |
| `{$SOPHOS.IF.WAN2.INDEX}` | `6` | SNMP `ifIndex` of the WAN2 interface |
| `{$SOPHOS.IF.LAN.NAME}` | `Port4` | LAN interface name as reported by `ifDescr` |
| `{$SOPHOS.IF.LAN.INDEX}` | `8` | SNMP `ifIndex` of the LAN interface |
| `{$HOST.WAN1.NAME}` | *(empty)* | Name of the corresponding WAN1 host in Zabbix — referenced in the failover trigger description so the on-call engineer knows where to look |

All four `{$SOPHOS.IF.*}` interface macros default to the values from the appliance this template was built against; override them per host if your port layout or SNMP indexes differ (see [Interface index discovery](#interface-index-discovery) below).

## Items

| Key | Name | OID | Units |
|---|---|---|---|
| `system.uptime` | Uptime | `1.3.6.1.2.1.1.3.0` | uptime |
| `sfos.model` | Appliance model | `1.3.6.1.4.1.21067.2.1.1.2.0` | — |
| `sfos.firmware.version` | Firmware version | `1.3.6.1.4.1.21067.2.1.1.3.0` | — |
| `sfos.cpu.util` | CPU utilization | `1.3.6.1.4.1.21067.2.1.2.2.1.0` | % |
| `sfos.memory.util` | Memory utilization | `1.3.6.1.4.1.21067.2.1.2.3.2.0` | % |
| `sfos.disk.util` | Disk utilization | `1.3.6.1.4.1.21067.2.1.2.4.2.0` | % |
| `sfos.users.live` | Active portal users | `1.3.6.1.4.1.21067.2.1.2.5.0` | — |
| `sfos.gateway.status[1]` | WAN1 gateway status | `1.3.6.1.4.1.21067.2.1.3.1.1.0` | 1=Active, 2=Inactive |
| `sfos.gateway.status[2]` | WAN2 (backup) gateway status | `1.3.6.1.4.1.21067.2.1.3.2.1.0` | 1=Active, 2=Inactive |
| `net.if.in[{$SOPHOS.IF.WAN1.NAME},bits]` | WAN1 — bits received | `ifInOctets.{$SOPHOS.IF.WAN1.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.WAN1.NAME},bits]` | WAN1 — bits sent | `ifOutOctets.{$SOPHOS.IF.WAN1.INDEX}` | bps |
| `net.if.in[{$SOPHOS.IF.WAN2.NAME},bits]` | WAN2 — bits received | `ifInOctets.{$SOPHOS.IF.WAN2.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.WAN2.NAME},bits]` | WAN2 — bits sent | `ifOutOctets.{$SOPHOS.IF.WAN2.INDEX}` | bps |
| `net.if.in[{$SOPHOS.IF.LAN.NAME},bits]` | LAN — bits received | `ifInOctets.{$SOPHOS.IF.LAN.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.LAN.NAME},bits]` | LAN — bits sent | `ifOutOctets.{$SOPHOS.IF.LAN.INDEX}` | bps |

Throughput items apply `CHANGE_PER_SECOND` + a `×8` multiplier to the raw SNMP counters (`ifInOctets`/`ifOutOctets`) to produce bits-per-second. CPU, memory, disk, uptime and gateway-status items use `DISCARD_UNCHANGED_HEARTBEAT` to avoid storing redundant unchanged values.

## Triggers

| Name | Severity | Condition |
|---|---|---|
| CPU high | WARNING | `avg(sfos.cpu.util,5m) > {$SOPHOS.CPU.UTIL.WARN}` |
| CPU critical | HIGH | `avg(sfos.cpu.util,5m) > {$SOPHOS.CPU.UTIL.HIGH}` |
| Memory high | WARNING | `avg(sfos.memory.util,5m) > {$SOPHOS.MEM.UTIL.WARN}` |
| Memory critical | HIGH | `avg(sfos.memory.util,5m) > {$SOPHOS.MEM.UTIL.HIGH}` |
| Disk high | WARNING | `last(sfos.disk.util) > {$SOPHOS.DISK.UTIL.WARN}` |
| Disk critical | HIGH | `last(sfos.disk.util) > {$SOPHOS.DISK.UTIL.HIGH}` |
| **WAN2 backup link active — check WAN1** | WARNING | `last(sfos.gateway.status[2]) = 1` |
| Firmware version changed | INFO | `change(sfos.firmware.version) = 1` |

CPU, memory and disk each have a WARNING trigger that depends on (and is suppressed by) their matching HIGH trigger, so only the more severe alert fires during an escalation. All triggers except the informational firmware-change one require manual close, and all use recovery expressions rather than fixed-duration flapping windows.

## Installation

### 1. Enable SNMP on the Sophos appliance

`Administration → SNMP → Enable SNMP`
- Version: **SNMPv2c**
- Community string: choose a value and note it down
- Allowed hosts: restrict to the Zabbix Server's IP

### 2. Discover the interface indexes

<a id="interface-index-discovery"></a>

The `{$SOPHOS.IF.*.INDEX}` macros must match your appliance's actual `ifIndex` values, which can differ from the defaults depending on port layout and firmware version:

```bash
snmpwalk -v2c -c <community> <firewall-ip> 1.3.6.1.2.1.2.2.1.2
# Example output:
# ifDescr.5 = Port1  → WAN1 → {$SOPHOS.IF.WAN1.INDEX} = 5
# ifDescr.6 = Port2  → WAN2 → {$SOPHOS.IF.WAN2.INDEX} = 6
# ifDescr.8 = Port4  → LAN  → {$SOPHOS.IF.LAN.INDEX}  = 8
```

### 3. Create the host in Zabbix

- Interface type: **SNMP v2c**, port 161, pointed at the firewall's WAN1 IP
- Import `template.json` (**Data collection → Templates → Import**) and link it to the host
- Override the `{$SOPHOS.IF.*}` macros at the host level if your indexes differ from the defaults
- Optionally set `{$HOST.WAN1.NAME}` to the name of the corresponding WAN1-link host in Zabbix, so the failover trigger's description points directly at it

### 4. Verify

Check **Latest data** for the host — `sfos.cpu.util`, `sfos.memory.util` and `sfos.model` should populate within one polling interval. If the interface throughput items (`net.if.in`/`net.if.out`) stay at zero, double-check the `{$SOPHOS.IF.*.INDEX}` macros against the `snmpwalk` output above.

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

# Sophos Firewall by SNMP

| | |
|---|---|
| **Category** | Network Devices / Security |
| **Collection method** | SNMP v2c (XG-FIREWALL-MIB) |
| **Items** | 16 |
| **Zabbix version** | 7.4 |

Monitors Sophos XG/XGS appliances using the proprietary `XG-FIREWALL-MIB` (enterprise OID `1.3.6.1.4.1.21067`). Covers CPU, RAM, disk, active sessions, WAN gateway failover state, and throughput on WAN1/WAN2/LAN interfaces.

Tested on Sophos XG105 / SFOS 17.5.x. Compatible with XG/XGS series running SFOS 17.x–20.x.

Typically used alongside [Dual WAN Primary Link](../dual-wan-primary/) and [Dual WAN Backup Link](../dual-wan-backup/) templates in a 3-host monitoring architecture.

## Requirements

- SNMP v2c enabled on the Sophos appliance (`Administration → SNMP`)
- Zabbix Server IP allowed in the SNMP permitted hosts list
- SNMP community string configured as a host macro

## Import

1. Go to **Configuration → Templates → Import**
2. Select `template.json`
3. Create a Zabbix host with SNMP v2c interface pointing to the firewall's WAN1 IP
4. Apply this template and configure the macros below

## Items

| Key | Description | OID |
|---|---|---|
| `system.uptime` | Uptime | `1.3.6.1.2.1.1.3.0` |
| `sfos.model` | Appliance model | `1.3.6.1.4.1.21067.2.1.1.2.0` |
| `sfos.firmware.version` | Firmware version | `1.3.6.1.4.1.21067.2.1.1.3.0` |
| `sfos.cpu.util` | CPU utilization (%) | `1.3.6.1.4.1.21067.2.1.2.2.1.0` |
| `sfos.memory.util` | Memory utilization (%) | `1.3.6.1.4.1.21067.2.1.2.3.2.0` |
| `sfos.disk.util` | Disk utilization (%) | `1.3.6.1.4.1.21067.2.1.2.4.2.0` |
| `sfos.users.live` | Active users (portal) | `1.3.6.1.4.1.21067.2.1.2.5.0` |
| `sfos.gateway.status[1]` | WAN1 gateway state | `1.3.6.1.4.1.21067.2.1.3.1.1.0` |
| `sfos.gateway.status[2]` | WAN2 (backup) gateway state | `1.3.6.1.4.1.21067.2.1.3.2.1.0` |
| `net.if.in/out[Port1,bits]` | WAN1 throughput (bps) | `ifIn/OutOctets.{$SOPHOS.IF.WAN1.INDEX}` |
| `net.if.in/out[Port2,bits]` | WAN2 throughput (bps) | `ifIn/OutOctets.{$SOPHOS.IF.WAN2.INDEX}` |
| `net.if.in/out[Port4,bits]` | LAN throughput (bps) | `ifIn/OutOctets.{$SOPHOS.IF.LAN.INDEX}` |

## Macros

Configure these macros on the host or template:

| Macro | Default | Description |
|---|---|---|
| `{$SOPHOS.CPU.UTIL.WARN}` | `80` | CPU % for WARNING trigger |
| `{$SOPHOS.CPU.UTIL.HIGH}` | `90` | CPU % for HIGH trigger |
| `{$SOPHOS.MEM.UTIL.WARN}` | `80` | Memory % for WARNING trigger |
| `{$SOPHOS.MEM.UTIL.HIGH}` | `90` | Memory % for HIGH trigger |
| `{$SOPHOS.DISK.UTIL.WARN}` | `80` | Disk % for WARNING trigger |
| `{$SOPHOS.DISK.UTIL.HIGH}` | `90` | Disk % for HIGH trigger |
| `{$SOPHOS.IF.WAN1.INDEX}` | `5` | SNMP ifIndex for WAN1 interface |
| `{$SOPHOS.IF.WAN2.INDEX}` | `6` | SNMP ifIndex for WAN2 interface |
| `{$SOPHOS.IF.LAN.INDEX}` | `8` | SNMP ifIndex for LAN interface |

To find the correct interface indexes for your appliance:
```bash
snmpwalk -v2c -c <community> <firewall-ip> 1.3.6.1.2.1.2.2.1.2
```

## Triggers

| Name | Severity | Condition |
|---|---|---|
| CPU critical | HIGH | `avg(sfos.cpu.util,5m) > {$SOPHOS.CPU.UTIL.HIGH}` |
| CPU high | WARNING | `avg(sfos.cpu.util,5m) > {$SOPHOS.CPU.UTIL.WARN}` |
| Memory critical | HIGH | `avg(sfos.memory.util,5m) > {$SOPHOS.MEM.UTIL.HIGH}` |
| Memory high | WARNING | `avg(sfos.memory.util,5m) > {$SOPHOS.MEM.UTIL.WARN}` |
| Disk critical | HIGH | `last(sfos.disk.util) > {$SOPHOS.DISK.UTIL.HIGH}` |
| Disk high | WARNING | `last(sfos.disk.util) > {$SOPHOS.DISK.UTIL.WARN}` |
| WAN2 backup gateway active | WARNING | `last(sfos.gateway.status[2]) = 1` |
| Firmware version changed | INFO | `change(sfos.firmware.version) = 1` |

The WAN2 backup gateway trigger fires when Sophos activates failover to the secondary link — the most reliable failover signal, even if SNMP was briefly unavailable during the failure.

# UniFi AP Legacy by SNMP

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-SNMP_v2c-7F13EC?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

| | |
|---|---|
| **Category** | Network Devices |
| **Collection method** | SNMP v1/v2c |
| **Items** | 10 static + 3 per discovered VAP (SSID) |
| **Zabbix version** | 7.4+ |

## Description

Monitors legacy Ubiquiti UniFi access points — first-generation UAP, UAP-LR, UAP-Pro, and any other UniFi AP still running end-of-life firmware 4.3.x — over SNMP v2c, using the vendor's proprietary MIB (enterprise OID `1.3.6.1.4.1.41112`). Covers system uptime, hostname, firmware version, hardware model and wired Ethernet (RX/TX) throughput, complemented by ICMP simple checks for reachability, packet loss and round-trip latency.

A low-level discovery rule walks the `ubntVapTable` to enumerate each AP's wireless SSIDs (VAPs) and creates per-SSID item prototypes for connected client count, TX power and RX traffic.

> **Note:** APs running modern firmware and managed by a current UniFi Controller should use the official "Ubiquiti UniFi by HTTP" template instead. This template exists specifically for older hardware stuck on EOL firmware, since the modern UniFi Controller no longer provisions SNMP on those devices.

## Macros

| Macro | Default | Description |
|---|---|---|
| `{$SNMP_COMMUNITY}` | `public` | SNMP community string. Override with your own value — never reuse the default in production. |
| `{$UNIFI.VAP.FILTER}` | `^element-` | Regex of SSIDs excluded from the VAP discovery rule (matches the AP's internal management interface, not a real Wi-Fi network) |

## Triggers

| Name | Severity | Condition |
|---|---|---|
| AP UniFi: Sem resposta ICMP (offline) | HIGH | `nodata(/UniFi AP Legacy by SNMP/icmpping,5m)=1` |
| AP UniFi: SNMP indisponivel | AVERAGE | `last(/UniFi AP Legacy by SNMP/zabbix[host,snmp,available])=2` |
| VAP {#SSID}: Sem dados de clientes | AVERAGE | `nodata(/UniFi AP Legacy by SNMP/unifi.vap.clients[{#SNMPINDEX}],5m)=1` (per discovered VAP) |

Both static triggers use `manual_close`, so they stay open until acknowledged even after the underlying condition clears.

## Items

| Key | Name | OID | Units |
|---|---|---|---|
| `icmpping` | ICMP ping | simple check | — |
| `icmppingloss` | ICMP loss | simple check | % |
| `icmppingsec` | ICMP response time | simple check | s |
| `system.name[sysName.0]` | AP hostname | `1.3.6.1.2.1.1.5.0` | — |
| `system.uptime[sysUpTime.0]` | System uptime | `1.3.6.1.2.1.1.3.0` | uptime |
| `unifi.firmware` | Firmware version | `1.3.6.1.4.1.41112.1.6.3.6.0` | — |
| `unifi.model` | Hardware model | `1.3.6.1.4.1.41112.1.6.3.3.0` | — |
| `net.if.in[eth0]` | ETH RX | `1.3.6.1.4.1.41112.1.6.2.1.1.6.1` | bps |
| `net.if.out[eth0]` | ETH TX | `1.3.6.1.4.1.41112.1.6.2.1.1.12.1` | bps |
| `zabbix[host,snmp,available]` | SNMP agent availability | internal | — |

ETH RX/TX apply `CHANGE_PER_SECOND` + a `×8` multiplier to the raw SNMP counters to produce bits-per-second. `system.name`, `unifi.firmware` and `unifi.model` are right-trimmed and polled hourly, since they rarely change.

### VAP discovery (per SSID)

Discovers each AP's SSIDs via LLD against the `ubntVapTable` (`1.3.6.1.4.1.41112.1.6.1.2`), skipping any SSID matching `{$UNIFI.VAP.FILTER}`.

| Key | Name | OID | Units |
|---|---|---|---|
| `unifi.vap.clients[{#SNMPINDEX}]` | VAP {#SSID} ({#VAP_IFACE}): Clientes conectados | `1.3.6.1.4.1.41112.1.6.1.2.1.8.{#SNMPINDEX}` | — |
| `unifi.vap.rx[{#SNMPINDEX}]` | VAP {#SSID} ({#VAP_IFACE}): Trafego RX | `1.3.6.1.4.1.41112.1.6.1.2.1.10.{#SNMPINDEX}` | bps |
| `unifi.vap.txpower[{#SNMPINDEX}]` | VAP {#SSID} ({#VAP_IFACE}): Potencia TX | `1.3.6.1.4.1.41112.1.6.1.2.1.21.{#SNMPINDEX}` | dBm |

## Installation

### 1. Enable SNMP on the AP (legacy firmware)

The modern UniFi Controller does not provision SNMP on APs running EOL firmware — it must be enabled manually over SSH:

```bash
ssh ubnt@<AP_IP>  # default password: ubnt

# Edit the configuration file
vi /tmp/system.cfg
# Append:
# snmp.community=public
# snmp.contact=admin
# snmp.enable=true
# snmp.location=local

# Persist and reboot
cfgmtd -w -p /etc/
reboot
```

After the reboot, confirm SNMP is responding:

```bash
snmpwalk -v2c -c public <AP_IP> 1.3.6.1.4.1.41112.1.6
```

Replace `public` with your own community string in both the AP configuration and the `{$SNMP_COMMUNITY}` macro — never reuse the example value in production.

### 2. Create the host in Zabbix

- Interface type: **SNMP v1/v2c**, port 161, pointed at the AP's management IP
- Import `template.json` (**Data collection → Templates → Import**) and link it to the host
- Set `{$SNMP_COMMUNITY}` to match the community string configured on the AP

### 3. Verify

Check **Latest data** for the host — `system.uptime`, `unifi.model` and `icmpping` should populate within one polling interval. Per-VAP items appear after the discovery rule's first run (default interval: 1h).

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

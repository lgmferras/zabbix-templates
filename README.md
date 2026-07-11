# Zabbix 7.4 Custom Template Library

A collection of 18 enterprise-grade Zabbix templates developed for MSP environments, covering network devices, cloud platforms, Windows servers, IoT gateways and business applications.

All templates target **Zabbix 7.4** and follow consistent conventions: macro-driven thresholds, tagged items, recovery expressions on all triggers and `DISCARD_UNCHANGED_HEARTBEAT` to reduce noise.

---

## Templates

| Template | Category | Method | Items | UserParameters |
|---|---|---|---|---|
| [ATHOS PDV](templates/athos-pdv/) | Windows / Applications | Zabbix Agent 2 (active) | 45 | `user_parameters_athos.conf` |
| [D-Link DGS-3100-24 Switch](templates/dlink-dgs-3100-24/) | Network Devices | SNMP v2c | 16 | — |
| [Dragino IoT Gateway](templates/dragino-iot/) | IoT / LoRaWAN | SSH + Dependent | 57 | — |
| [Dual WAN Backup Link](templates/dual-wan-backup/) | Network / Availability | Simple checks | 4 | — |
| [Dual WAN Primary Link](templates/dual-wan-primary/) | Network / Availability | Simple checks | 4 + 1 web scenario | — |
| [Kairos](templates/kairos/) | Windows / Applications | Zabbix Agent 2 (active) | 1 | `user_parameters_kairos.conf` |
| [MSPClouds Backup Monitor](templates/mspclouds-backup/) | Applications / Cloud | HTTP Agent + Dependent/LLD | 11 + LLD | — |
| [NETHOTEL](templates/nethotel/) | Applications | Zabbix Agent 2 (active) | 15 | `user_parameters_nethotel.conf` |
| [NFe SEFAZ Monitor](templates/nfe-sefaz-monitor/) | Applications | Zabbix Agent 2 (passive) + Python | 1 + 8/authorizer (LLD) | `nfe.conf` |
| [Oracle Cloud Billing](templates/oracle-cloud-billing/) | Cloud / Cost | SCRIPT (OCI Usage Reports API) | 2 | — |
| [Oracle Cloud Egress](templates/oracle-cloud-egress/) | Cloud / Cost | SCRIPT (OCI Monitoring API) | 4 | — |
| [Ricoh SP 3710SF Printer](templates/ricoh-sp3710sf/) | Applications / Devices | HTTP (embedded web UI) | 49 | — |
| [Sophos Firewall](templates/sophos-firewall/) | Network Devices / Security | SNMP v2c | 15 | — |
| [TrueNAS](templates/truenas/) | Applications / Storage | HTTP Agent + Dependent | 87 | — |
| [UniFi AP Legacy](templates/unifi-ap-legacy/) | Network Devices | SNMP v1/v2c | 10 + 3/VAP | — |
| [Windows Backup](templates/windows-backup/) | Windows / Backup | Zabbix Agent 2 (active) | 5 | `user_parameters_windows_backup.conf` |
| [Windows DHCP Server](templates/windows-dhcp/) | Windows / Network | Zabbix Agent 2 (active) + PowerShell | 5 + 12 (LLD) | `userparameter_dhcp.conf` + `dhcp_zbx.ps1` |
| [WireGuard Tunnel](templates/wireguard-tunnel/) | Network / VPN | Zabbix Agent (active) | 7 | `user_parameters_wireguard_linux.conf` / `_windows.conf` |

---

## Design Principles

- **Macro-driven thresholds** — all alert levels configurable per host without editing the template
- **Recovery expressions** on every trigger — no manual close required for transient issues
- **Tagged items** — `application`, `component` and `scope` tags for dashboard filtering
- **`DISCARD_UNCHANGED_HEARTBEAT`** — reduces storage load without losing visibility
- **Dependencies** between triggers — prevents alert storms from cascading failures

## Import

1. Go to **Configuration → Templates → Import**
2. Select the `template.json` from any subdirectory
3. Configure host macros as documented in each template's README

## UserParameters

Templates that use Zabbix Agent active items with custom keys require a UserParameter file installed on the monitored host. The file is included in each template's directory alongside `template.json`.

**Linux hosts** — copy to `/etc/zabbix/zabbix_agent2.d/` and run `systemctl restart zabbix-agent2`.

**Windows hosts** — copy to `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` and run `Restart-Service "Zabbix Agent 2"`.

For **Windows DHCP Server**, also copy `dhcp_zbx.ps1` to `C:\Program Files\Zabbix Agent 2\` (the `.conf` references it from there).

**NFe SEFAZ Monitor** is the exception: it requires a custom Zabbix Agent 2 image with Python 3 (`requests` + `beautifulsoup4`) and a passive-mode interface rather than a plain UserParameter drop-in. See its [README](templates/nfe-sefaz-monitor/) for the full setup.

## Environment

These templates were developed and tested in a production MSP environment running:
- Zabbix Server 7.4 on Docker (Linux)
- 30+ monitored hosts across multiple clients
- Mix of Windows Server, Linux, network devices and cloud platforms

## Author

**Luis Gustavo Ferras** — Infrastructure Specialist at [Systrix Tecnologia](https://systrix.com.br/)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-lgmferras-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/lgmferras)
[![GitHub](https://img.shields.io/badge/GitHub-lgmferras-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/lgmferras)

20+ years in enterprise IT infrastructure — Docker · Linux · Zabbix · Oracle Cloud · LoRaWAN

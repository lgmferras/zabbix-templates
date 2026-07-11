# TrueNAS by API

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-HTTP_Agent_(REST_v2.0)-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)
![Note](https://img.shields.io/badge/Note-API_deprecated_in_SCALE_26.04-orange?style=flat-square)

Zabbix template for monitoring **TrueNAS** appliances via the REST API v2.0.

**Zabbix version:** 7.4
**Collection type:** HTTP Agent (master items) + DEPENDENT (derived items)
**Items:** 87
**Supported devices:** TrueNAS SCALE 24.x / 25.x, TrueNAS CORE 13.x (API v2.0 compatible)

> **Note:** The REST API v2.0 is deprecated as of TrueNAS SCALE 26.04. Future SCALE versions will require migrating to the WebSocket JSON-RPC API.

---

## Prerequisites

### Create an API Key on TrueNAS

1. Go to **TrueNAS Web UI → Credentials → API Keys**
2. Click **Add**
3. Name: `zabbix-monitor`
4. Save the generated token

### Configure the host macros in Zabbix

| Macro | Value | Description |
|---|---|---|
| `{$TRUENAS.API.URL}` | `https://<your-truenas-host>` | Base URL, no trailing slash |
| `{$TRUENAS.API.KEY}` | `<token>` | API key generated on TrueNAS (Secret macro) |

---

## Collected Items

### Master items (HTTP Agent)

| Item | Endpoint | Interval |
|---|---|---|
| System Info | `/api/v2.0/system/info` | 2m |
| Pool | `/api/v2.0/pool` | 2m |
| Pool Dataset | `/api/v2.0/pool/dataset` | 5m |
| Network Interface | `/api/v2.0/interface` | 2m |
| Network Config | `/api/v2.0/network/configuration` | 1h |
| Alert list | `/api/v2.0/alert/list` | 2m |
| Certificate | `/api/v2.0/certificate` | 1h |
| App | `/api/v2.0/app` | 5m |
| Catalog | `/api/v2.0/catalog` | 1h |
| Disk | `/api/v2.0/disk` | 5m |
| Sharing SMB | `/api/v2.0/sharing/smb` | 1h |
| Sharing NFS | `/api/v2.0/sharing/nfs` | 1h |
| iSCSI Targets | `/api/v2.0/iscsi/target` | 1h |
| Cloud Sync | `/api/v2.0/cloudsync` | 5m |
| Cloud Backup | `/api/v2.0/cloud_backup` | 5m |
| Replication | `/api/v2.0/replication` | 5m |
| Rsync Task | `/api/v2.0/rsynctask` | 5m |
| Cron Job | `/api/v2.0/cronjob` | 1h |
| VM | `/api/v2.0/vm` | 5m |
| User | `/api/v2.0/user` | 1h |
| Group | `/api/v2.0/group` | 1h |
| FTP | `/api/v2.0/ftp` | 1h |
| Pool Disk | `/api/v2.0/pool/disk` | 5m |
| Pool Replication | `/api/v2.0/replication` | 5m |

### Dependent items (main ones)

| Item | Source | Type |
|---|---|---|
| Pool status | pool | String (value map) |
| Pool healthy | pool | Uint (0=Unhealthy, 1=Healthy) |
| Pool allocated | pool | Float (bytes) |
| Pool free | pool | Float (bytes) |
| Pool utilization % | calculated | Float (%) |
| Pool fragmentation | pool | Float (%) |
| Pool scan state | pool | String (value map) |
| Pool scan errors | pool | Uint |
| Interface link state | interface | String (value map) |
| Interface IP | interface | Text |
| Interface speed | interface | Uint (bps) |
| Active alerts count | alert.list | Uint |
| Critical alerts count | alert.list | Uint |
| Warning alerts count | alert.list | Uint |
| Certificate name | certificate | Text |
| Certificate issuer | certificate | Text |
| Certificate expiry | certificate | Uint (unixtime) |
| Apps count | app | Uint |
| Apps running | app | Uint |
| Apps with upgrades | app | Uint |
| Memory total | system.info | Uint (bytes) |
| Memory utilization % | system.info | Float (%) |
| SMB shares count | sharing.smb | Uint |
| Disks count | disk | Uint |
| Disk[1-3] name/model/type/size | disk | Text/Uint |
| Hostname | system.info | Text |
| Version | system.info | Text |
| CPU model | system.info | Text |
| Load avg 1m/5m/15m | system.info | Float |
| Uptime | system.info | Uint (s) |

---

## Value Maps

| Name | Values |
|---|---|
| TrueNAS pool status | ONLINE, DEGRADED, FAULTED, OFFLINE, UNAVAIL, REMOVED |
| TrueNAS pool health | 0=Unhealthy, 1=Healthy |
| TrueNAS link state | LINK_STATE_UP, LINK_STATE_DOWN, LINK_STATE_UNKNOWN |
| TrueNAS app state | running, stopped, deploying, etc. |
| TrueNAS scrub state | SCANNING, FINISHED, CANCELED, NONE |

---

## Triggers

| Name | Severity | Condition |
|---|---|---|
| Pool degraded | Warning | `pool.status = "DEGRADED"` |
| Pool critical | High | `pool.status != ONLINE and != DEGRADED` |
| Pool not healthy | High | `pool.healthy = 0` |
| Pool utilization high | Warning | `pool.allocated.pct > {$TRUENAS.POOL.UTIL.WARN}` (80%) |
| Pool utilization critical | High | `pool.allocated.pct > {$TRUENAS.POOL.UTIL.HIGH}` (90%) |
| Pool scan errors | High | `pool.scan.errors > 0` |
| Critical alerts active | High | `alert.critical.count > 0` |
| Warning alerts active | Warning | `alert.warning.count > 0` |
| Certificate expires < 30 days | Warning | `cert.until - now() < 30d` |
| Certificate expires < 7 days | High | `cert.until - now() < 7d` |
| Interface link down | High | `net.link_state = "LINK_STATE_DOWN"` |
| High CPU load | Warning | `avg(load1,5m) > {$TRUENAS.CPU.LOAD.WARN}` (4) |
| Critical CPU load | High | `avg(load1,5m) > {$TRUENAS.CPU.LOAD.HIGH}` (6) |
| High memory utilization | Warning | `avg(memory.pct,5m) > {$TRUENAS.MEM.UTIL.WARN}` (85%) |
| Critical memory utilization | High | `avg(memory.pct,5m) > {$TRUENAS.MEM.UTIL.HIGH}` (95%) |
| System restarted | Info | `uptime < 600` |
| API not responding | High | `nodata(system.info, 10m)` |

---

## Template Macros

| Macro | Default | Description |
|---|---|---|
| `{$TRUENAS.API.URL}` | `https://truenas.example.com` | API base URL |
| `{$TRUENAS.API.KEY}` | *(empty)* | API key (Secret) |
| `{$TRUENAS.POOL.UTIL.WARN}` | `80` | Pool usage warning threshold (%) |
| `{$TRUENAS.POOL.UTIL.HIGH}` | `90` | Pool usage critical threshold (%) |
| `{$TRUENAS.CPU.LOAD.WARN}` | `4` | CPU load warning threshold |
| `{$TRUENAS.CPU.LOAD.HIGH}` | `6` | CPU load critical threshold |
| `{$TRUENAS.MEM.UTIL.WARN}` | `85` | Memory usage warning threshold (%) |
| `{$TRUENAS.MEM.UTIL.HIGH}` | `95` | Memory usage critical threshold (%) |

---

## Graphs

- TrueNAS: CPU load average (Load 1m / 5m / 15m)
- TrueNAS: Memory utilization (%)
- TrueNAS: Pool storage (allocated / free in bytes)
- TrueNAS: Pool utilization % (allocated %)

## Suggested Dashboard

A **TrueNAS Overview** dashboard with:
- Status row: Hostname, Version, Uptime, Pool Status, Pool Utilization, Critical Alerts
- Active problems panel
- Graphs: CPU load, Memory, Pool storage, Pool utilization

---

## Installation

### 1. Import the template into Zabbix

1. **Configuration → Templates → Import**
2. Select `template.json`
3. Check: Create new + Update existing
4. Click **Import**

### 2. Configure the host

1. Create a host: **Configuration → Hosts → Create host**
2. Link the template: **TrueNAS by API**
3. No interface is required (HTTP Agent items don't use one)
4. Set the host-level macros:
   - `{$TRUENAS.API.URL}` = your TrueNAS URL
   - `{$TRUENAS.API.KEY}` = the generated API key

---

## Known Limitations

- The REST API v2.0 is deprecated in TrueNAS SCALE 26.04+; the template will need to migrate to WebSocket eventually.
- LLD (automatic discovery of pools, disks, interfaces) is not implemented — disk items are fixed (disk.1, disk.2, disk.3).
- For more than 3 disks or pools, add extra items manually.

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

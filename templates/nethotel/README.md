# NETHOTEL by Zabbix agent active

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-2.1-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_active-339933?style=flat-square)
![OS](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

Zabbix template for complete monitoring of the **NETHOTEL** (hotel management) system on Windows Server.

**Version:** 2.1
**Zabbix:** 7.4
**Agent:** Zabbix Agent 2 (active mode)
**Operating system:** Windows Server

---

## What Is Monitored

| Category | Qty | Description |
|---|---|---|
| Backup (gbak/Firebird) | 8 | Age, size, filename, execution, count, current-day backup |
| Services (Windows processes) | 7 | Backup, Daily, NFE, NFCE, NFSE, Reservations, B2B |
| **Total** | **15** | |

---

## Macros

Adjustable per host in **Configuration → Hosts → [host] → Macros**.

| Macro | Default | Description |
|---|---|---|
| `{$NETHOTEL.BACKUP.AGE.DISASTER}` | `48` | Hours without backup before DISASTER |
| `{$NETHOTEL.BACKUP.AGE.WARN}` | `24` | Hours without backup before WARNING |
| `{$NETHOTEL.BACKUP.EXPECTED_FILES}` | `7` | Expected `.GBK` files (1 per weekday) |
| `{$NETHOTEL.BACKUP.MAX_RUNTIME}` | `1h` | Maximum gbak runtime before considering it stuck |
| `{$NETHOTEL.BACKUP.MIN_SIZE}` | `524288000` | Minimum acceptable backup size (500 MB) |
| `{$NETHOTEL.BACKUP.SIZE_DROP}` | `104857600` | Size drop that triggers an alert (100 MB) |
| `{$NETHOTEL.BACKUP.STALE_HOURS}` | `30h` | Period without size change before alerting |
| `{$NETHOTEL.SERVICE.CHECK_INTERVAL}` | `3m` | Check interval for services |

---

## Triggers

### DISASTER

| Name | Condition |
|---|---|
| Critical backup | `age_hours > {$NETHOTEL.BACKUP.AGE.DISASTER}` |
| No backup file found | `age_hours = -1` |

### HIGH

| Name | Condition | Component |
|---|---|---|
| Backup process is stopped | `nethotel.becape = 0` | backup |
| Daily process is stopped | `nethotel.diaria = 0` | billing |
| NFE process is stopped | `nethotel.netnfe = 0` | fiscal |
| NFCE process is stopped | `nethotel.netnfce = 0` | fiscal |
| NFSE process is stopped | `nethotel.netnfse = 0` | fiscal |
| Reservations process is stopped | `nethotel.reshotel = 0` | reservations |
| B2B Reservations process is stopped | `nethotel.servicob2b = 0` | integration |

### WARNING

| Name | Condition | Depends on |
|---|---|---|
| Outdated backup | `age_hours > AGE.WARN` | Critical backup |
| Today's backup was not performed | `today_ok=0 after 06:00` | No backup file + Backup process stopped |
| Backup may be stuck | `min(running, MAX_RUNTIME)=1` | gbak running |
| Suspicious backup size | `size < MIN_SIZE and not running` | gbak running + No backup file |
| Backup finished with suspicious size | `running went back to 0 and size < MIN_SIZE` | gbak running |
| Backup size unchanged | `size stagnant for STALE_HOURS` | gbak running + No backup file |
| Backup size decreased | `change(size) < -SIZE_DROP` | gbak running |

### INFO / NOTICE

| Name | Condition |
|---|---|
| gbak.exe running | `running = 1` (recovery: `= 0`) |
| Missing backup files | `file_count < EXPECTED_FILES` |

---

## Items — Backup

| Item Key | Type | Interval | Preprocessing | Description |
|---|---|---|---|---|
| `nethotel.backup.age_hours` | FLOAT (h) | `1m;10m/1-7,00:00-06:00` | DISCARD 3h | Hours since the last `.GBK` file |
| `nethotel.backup.file_count` | INT | 1h | DISCARD 6h | Number of valid `.GBK` files |
| `nethotel.backup.latest_file` | TEXT | 10m | DISCARD 3h | Name of the most recent `.GBK` file |
| `nethotel.backup.latest_time` | TEXT | `1m;10m/1-7,00:00-06:00` | DISCARD 3h | Timestamp of the last backup |
| `nethotel.backup.running` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | Is gbak.exe running? |
| `nethotel.backup.size` | BYTES | 15m | DISCARD 3h | Size of the most recent backup |
| `nethotel.backup.today_ok` | 0/1 | 1h | DISCARD 6h | Does today's backup exist and is it current? |
| `nethotel.backup.total_size` | BYTES | 1h | DISCARD 6h | Sum of all `.GBK` files |

**Directory:** `C:\NETHOTEL\`
**File pattern:** `*.GBK` (e.g. `SEGEMA.GBK`, `TEREMA.GBK`)

> Items of type `0/1` carry the `no_metrics=true` tag so they don't generate unnecessary graphs.

## Items — Services

| Item Key | Type | Interval | Preprocessing | Component |
|---|---|---|---|---|
| `nethotel.becape` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | backup |
| `nethotel.diaria` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | billing |
| `nethotel.netnfe` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | fiscal |
| `nethotel.netnfce` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | fiscal |
| `nethotel.netnfse` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | fiscal |
| `nethotel.reshotel` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | reservations |
| `nethotel.servicob2b` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | integration |

---

## Value Maps

| Value Map | 0 | 1 |
|---|---|---|
| NETHOTEL Backup Status | Pending - Today's backup not performed | OK - Today's backup performed |
| NETHOTEL Service State | Stopped | Running |

---

## Installation

### 1. Configure Zabbix Agent 2 on Windows

Copy the **`user_parameters_nethotel.conf`** file to:

```
C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\
```

**Essential settings in `zabbix_agent2.conf`:**
```ini
ServerActive=<ZABBIX-SERVER-IP>
Hostname=<HOST-NAME-IN-ZABBIX>
UnsafeUserParameters=1
Timeout=30
```

### 2. Restart the agent service

```powershell
Restart-Service "Zabbix Agent 2"
```

### 3. Import and apply the template

1. **Configuration → Templates → Import** → `NETHOTEL_by_Zabbix_agent_active.json`
2. Apply to the host: **Configuration → Hosts → [host] → Templates**
3. Adjust macros per host if needed

---

## Design Reference

This template served as the **reference and model** for the development of the ATHOS template. The adopted patterns:

- `recovery_mode: RECOVERY_EXPRESSION` on all triggers
- `manual_close: YES` for backup alerts
- `opdata` with the item's current value
- Cascading triggers with `dependencies` to avoid alert flood
- `DISCARD_UNCHANGED_HEARTBEAT` on all items (boolean, text and numeric)
- `no_metrics=true` on all 0/1 items
- `scope:` tags on all triggers (`availability`, `data`, `performance`, `notice`)
- Template-level tags `class: application` + `target: nethotel`

---

## Changelog

| Version | Changes |
|---|---|
| 2.1 | DISCARD_UNCHANGED_HEARTBEAT on age_hours, size and total_size; delay on size (15m) and total_size (1h); no_metrics=true on all 0/1 items |
| 2.0 | Triggers with macros, dependencies, opdata, recovery expressions; global size triggers |

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

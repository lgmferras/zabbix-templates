# ATHOS by Zabbix agent active

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.1-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_active-339933?style=flat-square)
![OS](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

Zabbix template for complete monitoring of the **ATHOS** system (POS / commercial management) on Windows Server.

**Version:** 1.1
**Zabbix:** 7.4
**Agent:** Zabbix Agent 2 (active mode)
**Operating system:** Windows Server 2016+

---

## What Is Monitored

| Category | Qty | Description |
|---|---|---|
| Backup (pg_dump) | 8 | Age, size, filename, execution, count, current-day backup |
| PostgreSQL | 1 | Port 5432 responding |
| Logs | 2 | Size and retention of the `C:\logAthos` folder |
| Processes | 34 | State of each ATHOS module (0=stopped, 1=running) |
| **Total** | **45** | |

---

## Macros

Adjustable per host in **Configuration → Hosts → [host] → Macros**.

| Macro | Default | Description |
|---|---|---|
| `{$ATHOS.BACKUP.AGE.DISASTER}` | `48` | Hours without backup before DISASTER |
| `{$ATHOS.BACKUP.AGE.WARN}` | `24` | Hours without backup before WARNING |
| `{$ATHOS.BACKUP.EXPECTED_FILES}` | `7` | Expected `.backup` files (1 per weekday) |
| `{$ATHOS.BACKUP.MAX_RUNTIME}` | `1h` | Maximum pg_dump runtime before considering it stuck |
| `{$ATHOS.BACKUP.MIN_SIZE}` | `524288000` | Minimum acceptable backup size (500 MB) |
| `{$ATHOS.BACKUP.SIZE_DROP}` | `104857600` | Size drop that triggers an alert (100 MB) |
| `{$ATHOS.BACKUP.STALE_HOURS}` | `30h` | Period without size change before alerting |
| `{$ATHOS.SERVICE.CHECK_INTERVAL}` | `3m` | Check interval for processes and services |

---

## Triggers

### Backup — DISASTER

| Name | Condition | Recovery |
|---|---|---|
| Critical backup | `age_hours > {$ATHOS.BACKUP.AGE.DISASTER}` | `age_hours <= DISASTER` |
| No backup file found | `age_hours = -1` | — |
| PostgreSQL not responding on port 5432 | `pg.port_ok = 0` | `pg.port_ok = 1` |

### Backup — HIGH

| Name | Condition | Recovery |
|---|---|---|
| Athos process is stopped | `proc.status[Athos] = 0` | `= 1` |
| pdv process is stopped | `proc.status[pdv] = 0` | `= 1` |
| NFSe process is stopped | `proc.status[NFSe] = 0` | `= 1` |
| AthosBackup process is stopped | `proc.status[AthosBackup] = 0` | `= 1` |

### Backup — WARNING

| Name | Condition | Depends on |
|---|---|---|
| Outdated backup | `age_hours > {$ATHOS.BACKUP.AGE.WARN}` | Critical backup |
| Today's backup was not performed | `today_ok=0 after 06:00` | No backup file + AthosBackup stopped |
| Backup may be stuck | `min(running, MAX_RUNTIME)=1` | pg_dump running |
| Suspicious backup size | `size < MIN_SIZE and not running` | pg_dump running + No backup file |
| Backup finished with suspicious size | `running went back to 0 and size < MIN_SIZE` | pg_dump running |
| Backup size unchanged | `size stagnant for STALE_HOURS` | pg_dump running + No backup file |
| Backup size decreased | `change(size) < -SIZE_DROP` | pg_dump running |

### Backup — INFO / NOTICE

| Name | Condition |
|---|---|
| pg_dump running | `running = 1` (recovery: `= 0`) |
| Missing backup files | `file_count < EXPECTED_FILES` |

---

## Items — Backup

| Item Key | Type | Interval | Preprocessing | Description |
|---|---|---|---|---|
| `athos.backup.age_hours` | FLOAT (h) | 10m | DISCARD 3h | Hours since the last `.backup` file (-1 if none found) |
| `athos.backup.file_count` | INT | 1h | DISCARD 6h | Number of valid `.backup` files |
| `athos.backup.latest_file` | TEXT | 30m | DISCARD 3h | Name of the most recent `.backup` file |
| `athos.backup.latest_time` | TEXT | 10m | DISCARD 3h | Timestamp of the last backup (YYYY-MM-DD HH:mm:ss) |
| `athos.backup.running` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | Is pg_dump running? |
| `athos.backup.size` | BYTES | 15m | DISCARD 3h | Size of the most recent backup |
| `athos.backup.today_ok` | 0/1 | 30m | DISCARD 6h | Does today's backup exist and is it current? |
| `athos.backup.total_size` | BYTES | 1h | DISCARD 6h | Sum of all valid `.backup` files |

**Directory:** `C:\Athos\backupAthos\`
**File pattern:** `athosdom|athosseg|athoster|athosqua|athosqui|athossex|athossßb.backup`

---

## Items — PostgreSQL

| Item Key | Type | Interval | Preprocessing | Description |
|---|---|---|---|---|
| `athos.pg.port_ok` | 0/1 | `{$SERVICE.CHECK_INTERVAL}` | DISCARD 30m | Is port 5432 responding on 127.0.0.1? |

---

## Items — Logs

| Item Key | Type | Interval | Preprocessing | Description |
|---|---|---|---|---|
| `athos.log.oldest_days` | FLOAT (d) | 1h | DISCARD 6h | Age of the oldest log file in `C:\logAthos` |
| `athos.log.size_bytes` | BYTES | 15m | DISCARD 6h | Total size of the `C:\logAthos` folder |

---

## Items — Processes (34)

All items return `1=Running` / `0=Stopped` with the `no_metrics=true` tag and `DISCARD_UNCHANGED_HEARTBEAT 30m`.
Collected via `athos.proc.status[ProcessName]` at the `{$ATHOS.SERVICE.CHECK_INTERVAL}` interval.

| Process | Criticality | Trigger |
|---|---|---|
| **Athos** | HIGH | Yes |
| **pdv** | HIGH | Yes |
| **NFSe** | HIGH | Yes |
| **AthosBackup** | HIGH | Yes |
| Autoatendimento | — | — |
| Balathos | — | — |
| balcao | — | — |
| consultaComanda | — | — |
| consultaPreco | — | — |
| criaBanco | — | — |
| delivery | — | — |
| dwagsvc | — | — |
| ETQAthos | — | — |
| frenteVendaGrade | — | — |
| gacutil | — | — |
| gerenciadorConsultaPreco | — | — |
| gerenciadorConsultaTanca | — | — |
| MTGertec | — | — |
| MTImpressao | — | — |
| mtMonitoramento | — | — |
| mtWillTechGradual | — | — |
| notaEntrada | — | — |
| nothos | — | — |
| pg_dump | — | — |
| prathosTouch | — | — |
| prathos | — | — |
| Relatorio | — | — |
| SAThos | — | — |
| sincronizadorScanntech | — | — |
| Sintegra | — | — |
| suporteremoto | — | — |
| syncCardapioDigital | — | — |
| verificaAtualizacao | — | — |
| wCamVG | — | — |

> To add a trigger for another process: edit the desired item and add a trigger with the expression `last(/ATHOS by Zabbix agent active/athos.proc.status[ProcessName])=0`.

---

## Value Maps

| Value Map | 0 | 1 |
|---|---|---|
| ATHOS Backup Status | Pending - Today's backup not performed | OK - Today's backup performed |
| ATHOS Process State | Stopped | Running |
| ATHOS Port Status | Failed - Port not responding | OK - Port responding |

---

## Installation

### 1. Configure Zabbix Agent 2 on Windows

Copy the **`user_parameters_athos.conf`** file to the agent's configuration folder:

```
C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\
```

**Essential settings in `zabbix_agent2.conf`:**
```ini
ServerActive=<ZABBIX-SERVER-IP>   # Zabbix Server IP
Hostname=<HOST-NAME-IN-ZABBIX>    # Exact host name in Zabbix
UnsafeUserParameters=1            # Required for the PowerShell UserParameters
Timeout=30
```

### 2. Restart the agent service

```powershell
Restart-Service "Zabbix Agent 2"
```

### 3. Import the template into Zabbix

1. **Configuration → Templates → Import**
2. Select `template.json`
3. Check: Create new + Update existing
4. Click **Import**

### 4. Apply to the host

1. **Configuration → Hosts → [host-name] → Templates**
2. Add: **ATHOS by Zabbix agent active**
3. Adjust macros to match the environment

### 5. Verify collection

```bash
# On the Zabbix server, test active collection:
zabbix_get -s <HOST-IP> -k "athos.proc.status[Athos]"
# Should return 1 (if Athos is running)

zabbix_get -s <HOST-IP> -k "athos.backup.age_hours"
# Should return the number of hours (e.g. 3.5)
```

---

## UserParameters

File: **`user_parameters_athos.conf`**

| UserParameter | Description |
|---|---|
| `athos.proc.status[*]` | State of any process by name (1/0) |
| `athos.proc.running_list` | List of active ATHOS processes (inventory) |
| `athos.svc.status[*]` | State of any Windows service by name (1/0) |
| `athos.backup.running` | Is pg_dump running? (1/0) |
| `athos.backup.age_hours` | Hours since the last .backup file (float, InvariantCulture) |
| `athos.backup.size` | Size of the most recent backup (bytes) |
| `athos.backup.latest_file` | Name of the most recent .backup file |
| `athos.backup.latest_time` | Timestamp of the most recent backup |
| `athos.backup.file_count` | Number of valid .backup files |
| `athos.backup.total_size` | Sum of all .backup files (bytes) |
| `athos.backup.today_ok` | Was today's backup performed? (1/0) |
| `athos.pg.port_ok` | Is PostgreSQL responding on 127.0.0.1:5432? (1/0) |
| `athos.log.size_bytes` | Total size of `C:\logAthos` (bytes) |
| `athos.log.oldest_days` | Oldest log file (days, float) |

> To also monitor **Windows Server Backup** on the same host, additionally copy `user_parameters_windows_backup.conf` and apply the **Windows Backup by Zabbix agent 2** template.

---

## Troubleshooting

**Processes return 0 even though the process is running:**
```powershell
# Test directly on the server:
Get-Process -Name "Athos" -ErrorAction SilentlyContinue
# If it returns nothing, the process really is stopped
# Verify the process name matches exactly as listed (case sensitive in PowerShell)
```

**`athos.backup.age_hours` returns -1:**
- Verify that the `C:\Athos\backupAthos\` folder exists
- Verify that the files follow the pattern: `athosdom.backup`, `athosseg.backup`, etc.

**`athos.pg.port_ok` returns 0:**
```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 5432
# If it fails, PostgreSQL is stopped or not listening on port 5432
```

**`age_hours` returns with a decimal comma (pt-BR):**
- The UserParameter uses `InvariantCulture` to force a decimal point
- If the issue persists, check the PowerShell version

---

## Changelog

| Version | Changes |
|---|---|
| 1.1 | DISCARD_UNCHANGED_HEARTBEAT added to age_hours (3h), size (3h), total_size (6h), log.size_bytes (6h), log.oldest_days (6h); win.backup.* UserParameters moved to a separate file |
| 1.0.0 | Initial release with macros, triggers, preprocessing and template tags |

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

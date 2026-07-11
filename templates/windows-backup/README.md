# Windows Backup by Zabbix agent 2

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-2.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_active-339933?style=flat-square)
![OS](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

Zabbix template for monitoring **Windows Server Backup** (`wbadmin`) via the Windows Event Log.

**Version:** 2.0
**Zabbix:** 7.4
**Group:** Templates/Applications
**Agent:** Zabbix Agent 2 (active mode)
**Operating system:** Windows Server 2016+

---

## What Is Monitored

| Item Key | Type | Interval | Preprocessing | Description |
|---|---|---|---|---|
| `win.backup.age_hours` | FLOAT (h) | 15m | — | Hours since the last backup (Event ID 4). Returns `-1` if not found. |
| `win.backup.exists` | 0/1 | 10m | DISCARD 6h | Does `wbadmin get versions` succeed? |
| `win.backup.last_ok` | 0/1 | 30m | DISCARD 6h | Was a success event (Event ID 4) found? |
| `win.backup.last_time` | TEXT | 30m | DISCARD 3h | Timestamp of the last successful backup event |
| `win.backup.running` | 0/1 | 2m | DISCARD 30m | Event ID 1 with no later Event ID 4 = backup in progress |

> `0/1` items carry the `no_metrics=true` tag so they don't generate unnecessary graphs.

Data sources:
- Event Log `Microsoft-Windows-Backup` (ID 1 = backup started, ID 4 = backup completed successfully)
- `wbadmin get versions` (checks whether any backup versions are registered)

---

## Macros

Adjustable per host in **Configuration → Hosts → [host] → Macros**.

| Macro | Default | Description |
|---|---|---|
| `{$WIN.BACKUP.AGE.DISASTER}` | `48h` | Time without a backup before DISASTER |
| `{$WIN.BACKUP.AGE.WARN}` | `26h` | Time without a backup before WARNING |
| `{$WIN.BACKUP.MAX_RUNTIME}` | `4h` | Maximum tolerated duration of the backup process |

---

## Triggers (6)

### DISASTER

| Name | Condition | opdata |
|---|---|---|
| Last backup older than `{$WIN.BACKUP.AGE.DISASTER}` | `age_hours > AGE.DISASTER and age_hours <> -1` | Age: {ITEM.LASTVALUE} |
| No backup event found in the Event Log | `age_hours = -1` | No Event ID 4 in Microsoft-Windows-Backup |

### HIGH

| Name | Condition |
|---|---|
| No backup registered (`wbadmin get versions` fails) | `exists = 0` |

### WARNING

| Name | Condition | Depends on | opdata |
|---|---|---|---|
| Last backup older than `{$WIN.BACKUP.AGE.WARN}` | `age_hours > AGE.WARN and age_hours <> -1` | DISASTER age trigger | Age: {ITEM.LASTVALUE} |
| No success event (ID 4) in the last `{$WIN.BACKUP.AGE.DISASTER}` | `max(last_ok, AGE.DISASTER) = 0` | No backup registered trigger | No Event ID 4 in the last Xh |

### INFO

| Name | Condition |
|---|---|
| Backup running for more than `{$WIN.BACKUP.MAX_RUNTIME}` | `min(running, MAX_RUNTIME) = 1` |

All triggers use `manual_close=YES` and an explicit recovery expression.

---

## Value Maps

| Value Map | 0 | 1 |
|---|---|---|
| WB Running | Not running | Running |
| WB Yes/No | No/Fail | Yes/OK |

---

## Installation

### 1. Requirements

Windows Server Backup must be installed:

```powershell
# Check if installed
Get-WindowsFeature Windows-Server-Backup

# Install if needed
Install-WindowsFeature Windows-Server-Backup
```

The template depends on the `Microsoft-Windows-Backup` Event Log:
- **Event ID 1:** Backup started
- **Event ID 4:** Backup completed successfully

```powershell
# Check for existing backup events
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Backup'; Id=4} -MaxEvents 5
```

### 2. Configure Zabbix Agent 2 on Windows

Copy the **`user_parameters_windows_backup.conf`** file to the agent's configuration folder:

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

### 3. Restart the agent service

```powershell
Restart-Service "Zabbix Agent 2"
```

### 4. Import the template into Zabbix

1. **Configuration → Templates → Import**
2. Select `template.json`
3. Check: Create new + Update existing
4. Click **Import**

### 5. Apply to the host

1. **Configuration → Hosts → [host-name] → Templates**
2. Add: **Windows Backup by Zabbix agent 2**
3. Adjust macros to match the environment

---

## UserParameters

File: **`user_parameters_windows_backup.conf`**

| UserParameter | Description |
|---|---|
| `win.backup.exists` | Does `wbadmin get versions` succeed? (1/0) |
| `win.backup.running` | Is a backup currently running (Event ID 1 without a later ID 4)? (1/0) |
| `win.backup.last_ok` | Was a success event (Event ID 4) found? (1/0) |
| `win.backup.last_time` | Timestamp of the last successful backup (`YYYY-MM-DD HH:MM:SS` or `N/A`) |
| `win.backup.age_hours` | Hours since the last successful backup (float, InvariantCulture), or `-1` if not found |

---

## Troubleshooting

**`win.backup.age_hours` returns `-1`:**
```powershell
# Verify that success events exist in the Event Log
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Backup'; Id=4} -MaxEvents 5
```
- Confirm Windows Server Backup is configured and has completed at least one run

**`win.backup.exists` returns `0`:**
```powershell
# Run manually on the server to check for errors
wbadmin get versions
```
- Verify the Windows Server Backup feature is installed and the scheduled backup is configured

**`win.backup.age_hours` returns a value with a decimal comma (pt-BR locale):**
- The UserParameter uses `InvariantCulture` to force a decimal point
- If the issue persists, check the PowerShell version on the host

---

## Note on Combining with ATHOS

The **Windows Backup** template can be applied **together** with the **ATHOS** template on the same host.

- **ATHOS** monitors the backup of the **application** (`pg_dump` → `.backup`)
- **Windows Backup** monitors the backup of the **operating system** (`wbadmin` → server image)

The two are complementary and use separate UserParameters files (no conflict):
- `user_parameters_athos.conf` → `athos.*` keys
- `user_parameters_windows_backup.conf` → `win.backup.*` keys

---

## Changelog

| Version | Changes |
|---|---|
| 2.0 | Macros for thresholds; `age_hours = -1` DISASTER trigger; `DISCARD_UNCHANGED_HEARTBEAT` preprocessing; `no_metrics` tag on 0/1 items; `opdata` on all triggers; dependencies between triggers; group moved to Templates/Applications |
| 1.0 | Initial release |

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

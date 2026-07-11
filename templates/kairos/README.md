# Kairos by Zabbix agent active

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Collection method](https://img.shields.io/badge/Collection_method-Zabbix_Agent_2_active-7F13EC?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

| | |
|---|---|
| **Category** | Windows / Applications |
| **Collection method** | Zabbix Agent 2 (active) |
| **Items** | 1 |
| **Zabbix version** | 7.4 |

## Description

Minimal template for monitoring the **NotifyKairosConnect** process of the **Kairos** hotel management system. It checks whether the process is running on the Windows host and raises an alert when it stops.

## Requirements

- Zabbix Server 7.4+
- Zabbix Agent 2 (active) configured on the monitored Windows host
- `user_parameters_kairos.conf` copied to the agent's UserParameter directory

## Macros

No macros required — this template has no configurable thresholds.

## Items

| Key | Description | Type | Trigger |
|---|---|---|---|
| `kairos.NotifyKairosConnect` | State of service Kairos - Notify Connect | Zabbix Agent (active) | HIGH — stopped → recovery: running |

### Trigger detail

- **Name:** Kairos - Processo Notify Connect está parado
- **Expression:** `last(/Kairos by Zabbix agent active/kairos.NotifyKairosConnect)=0`
- **Recovery expression:** `last(/Kairos by Zabbix agent active/kairos.NotifyKairosConnect)=1`
- **Severity:** HIGH
- **Manual close:** Yes

### Value map

The item uses the **NETHOTEL Value Mapping** value map (shared with the NETHOTEL template):

| Value | Text |
|---|---|
| 0 | Stoped |
| 1 | Running |

## Installation

### 1. UserParameter

Copy `user_parameters_kairos.conf` to:
```
C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\
```

It defines the following UserParameter, which checks whether the `NotifyKairosConnect` process is running via PowerShell:

```ini
UserParameter=kairos.NotifyKairosConnect,powershell -NoProfile -Command "if(Get-Process -Name NotifyKairosConnect -ErrorAction SilentlyContinue){1}else{0}"
```

Then restart the agent:
```powershell
Restart-Service "Zabbix Agent 2"
```

### 2. Import the template

1. Go to **Configuration → Templates → Import**
2. Select `template.json`
3. Apply the template to the Windows host running Kairos

## Note

This template is intentionally minimal — it monitors only the main Kairos process. To expand it, add new `kairos.*` items following the pattern used in the ATHOS PDV or NETHOTEL templates.

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

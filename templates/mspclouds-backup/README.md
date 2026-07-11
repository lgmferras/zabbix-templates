# MSPClouds Backup Monitor

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-4.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-HTTP_Agent-009639?style=flat-square)
![LLD](https://img.shields.io/badge/LLD-per_client-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

**Category:** Applications / Cloud
**Collection method:** HTTP Agent (master item) + DEPENDENT (derived items)
**Items:** 11 general + LLD discovery (per client/backup set, per alert)
**Zabbix version:** 7.4+

## Description

Zabbix template for monitoring cloud backups via the **MSPClouds API**. It collects the aggregate backup status (success / error / warning / running / unmonitored) and active alerts for an MSPClouds account, and uses low-level discovery (LLD) to automatically create items and triggers per client/backup set and per active alert — without requiring a Zabbix Agent on any monitored endpoint.

## What Is Monitored

### General items (11)

| Key | Description | History | Trends |
|---|---|---|---|
| `mspclouds.alerts.raw` | Raw JSON from the alerts endpoint (master item) | 7d | — |
| `mspclouds.alerts.count` | Number of active alerts | 90d | 365d |
| `mspclouds.status.raw` | Raw JSON from the status endpoint (master item) | 7d | — |
| `mspclouds.company.name` | Company/provider name | default | — |
| `mspclouds.status.success` | Backups finished successfully | 90d | 365d |
| `mspclouds.status.error` | Backups finished with an error | 90d | 365d |
| `mspclouds.status.warning` | Backups finished with a warning | 90d | 365d |
| `mspclouds.status.info` | Backups currently **running** | 90d | 365d |
| `mspclouds.status.nomon` | Backups without monitoring | 90d | 365d |
| `mspclouds.status.total` | Total monitored backup jobs | 90d | 365d |
| `mspclouds.status.updated_at` | Timestamp of the last data update | default | — |

### Low-level discovery (LLD)

| Rule | Discovered items | Triggers |
|---|---|---|
| Clients and backup sets | Status, dates, timestamps, report URL, age since last success | Backup with ERROR (HIGH), backup overdue (WARNING) |
| Active alerts | Message per alert (client + type) | — |

## Macros

| Macro | Default | Description |
|---|---|---|
| `{$MSPCLOUDS.API.KEY}` | — | MSPClouds API authentication key (secret text) |
| `{$MSPCLOUDS.API.URL}` | `https://mspclouds.com/api/v1` | API base URL |
| `{$MSPCLOUDS.BACKUP.MAX_AGE}` | `36h` | Maximum tolerated age without a successful backup |

> **Important:** `{$MSPCLOUDS.API.KEY}` must be configured **per host**, since each client has its own API key. The macro ships as a `SECRET_TEXT` type with no default value baked into the template.

## Triggers

### General triggers

| Name | Severity | Condition | opdata |
|---|---|---|---|
| There are N backup(s) with ERROR | HIGH | `status.error > 0` | "Check each client's individual alerts" |
| There are N backup(s) with WARNING | WARNING | `status.warning > 0` | "There are {ITEM.LASTVALUE} backup(s) with a warning" |
| There are N active alert(s) | INFO | `alerts.count > 0 and status.error > 0` | "Check the alert items for details" |

### Trigger prototypes (per client/backup set)

| Name | Severity | Condition |
|---|---|---|
| Backup "[backupset]" with ERROR | HIGH | `status = "error"` |
| Backup "[backupset]" without success for over {MAX_AGE} | WARNING | `now() - last_success_ts > MAX_AGE` |

## Collection Architecture

```
HTTP Agent → MSPClouds API (2x/day — 08:00)
    │
    ├── mspclouds.alerts.raw        (raw JSON — history 7d)
    │       ├── mspclouds.alerts.count      (JSONPATH: $.length())
    │       └── [LLD] mspclouds.alert.message[client,type,created]
    │
    └── mspclouds.status.raw        (raw JSON — history 7d)
            ├── mspclouds.company.name
            ├── mspclouds.status.success    ($.status.success)
            ├── mspclouds.status.error      ($.status.error)
            ├── mspclouds.status.warning    ($.status.warning)
            ├── mspclouds.status.info       ($.status.info — running)
            ├── mspclouds.status.nomon      ($.status.nomon)
            ├── mspclouds.status.total      ($.status.total)
            ├── mspclouds.status.updated_at
            └── [LLD] per client/backup set
                    ├── status / status_code / status_desc
                    ├── last_backup_date / last_backup_ts
                    ├── last_success_date / last_success_ts
                    ├── last_success_age  (CALCULATED)
                    └── report_url
```

## Differences From the Official Documentation

The official documentation (validated on Zabbix 6.2) describes an integration via a bash script + UserParameter on the Zabbix agent. This template uses a different, more advanced approach:

| Aspect | Official documentation | This template |
|---|---|---|
| Collection | Bash script + UserParameter | Native HTTP_AGENT on the Zabbix Server |
| Agent required | Yes (on the Zabbix server) | No |
| Items | 5 (basic) | 11 general + LLD per client |
| Triggers | — | Per backup set, with report URL |
| Zabbix | 6.2 | 7.4 |

## Suggested Dashboard (per the official documentation)

Build a dashboard with:
- **Value widgets (colored tiles):** success (green), error (red), warning (orange), info (blue), total
- **"Consolidated Backup" pie chart:** success + error + warning + info (excluding nomon)
- **Data overview:** grid with status per client discovered via LLD

## API Call Rate Limiting

Collection is configured for **2x per day** (8-hour interval) to save API calls, which may be subject to cost or rate limits.

If more frequent checks are needed, adjust the master items' `delay` and verify the client's MSPClouds API limits.

## Installation

### 1. Import the template

**Configuration → Templates → Import** → `template.json`

### 2. Create the host

The template **does not require a Zabbix Agent** — collection is performed directly by the Zabbix server over HTTP.

Create a "virtual" host for each MSPClouds client:
- **Name:** `MSPClouds - [Client Name]`
- **Interface:** none (or a dummy IP)
- **Template:** MSPClouds Backup Monitor

### 3. Configure the host macros

| Macro | Value |
|---|---|
| `{$MSPCLOUDS.API.KEY}` | Client's API key (obtained from the MSPClouds panel) |
| `{$MSPCLOUDS.API.URL}` | `https://mspclouds.com/api/v1` (confirm with MSPClouds) |
| `{$MSPCLOUDS.BACKUP.MAX_AGE}` | Adjust according to the client's SLA (e.g. `24h`, `36h`, `48h`) |

## Changelog

| Version | Changes |
|---|---|
| 4.0 | Added `mspclouds.status.info` (running backups); history 90d and trends 365d on numeric items; opdata on the warning trigger |
| 3.0 | LLD discovery of clients/backup sets; per-client trigger prototypes; report URL in opdata |

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

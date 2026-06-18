# Kairos by Zabbix agent active

| | |
|---|---|
| **Category** | Windows / Applications |
| **Collection method** | Zabbix Agent 2 (active) |
| **Items** | 1 |
| **Zabbix version** | 7.4 |

Minimal template for monitoring the **NotifyKairosConnect** process of the **Kairos** hotel management system.

## Requirements

- Zabbix Agent 2 installed on the Windows Server host
- `user_parameters_kairos.conf` copied to `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\`
- Agent service restarted after installing the UserParameter

## Import

1. Go to **Configuration → Templates → Import**
2. Select `template.json`
3. Apply the template to the Windows host running Kairos

## UserParameter

Copy `user_parameters_kairos.conf` to:
```
C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\
```

Then restart the agent:
```powershell
Restart-Service "Zabbix Agent 2"
```

## Items

| Key | Description | Type | Trigger |
|---|---|---|---|
| `kairos.NotifyKairosConnect` | NotifyKairosConnect process state | Zabbix Agent (active) | HIGH — stopped → recovery: running |

## Macros

No macros required.

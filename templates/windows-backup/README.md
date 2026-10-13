# Windows Backup by Zabbix agent 2

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-2.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_active-339933?style=flat-square)
![OS](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

Template Zabbix para monitoramento do **Windows Server Backup** (`wbadmin`) via Event Log do Windows.

**Versão:** 2.0
**Zabbix:** 7.4
**Grupo:** Templates/Applications
**Agente:** Zabbix Agent 2 (modo ativo)
**Sistema operacional:** Windows Server 2016+

---

## O que é Monitorado

| Item Key | Tipo | Intervalo | Preprocessing | Descrição |
|---|---|---|---|---|
| `win.backup.age_hours` | FLOAT (h) | 15m | — | Horas desde o último backup (Event ID 4). Retorna `-1` se não encontrado. |
| `win.backup.exists` | 0/1 | 10m | DISCARD 6h | O `wbadmin get versions` é bem-sucedido? |
| `win.backup.last_ok` | 0/1 | 30m | DISCARD 6h | Foi encontrado um evento de sucesso (Event ID 4)? |
| `win.backup.last_time` | TEXT | 30m | DISCARD 3h | Timestamp do último evento de backup bem-sucedido |
| `win.backup.running` | 0/1 | 2m | DISCARD 30m | Event ID 1 sem Event ID 4 posterior = backup em andamento |

> Itens `0/1` carregam a tag `no_metrics=true` para não gerar gráficos desnecessários.

Fontes de dados:
- Event Log `Microsoft-Windows-Backup` (ID 1 = backup iniciado, ID 4 = backup concluído com sucesso)
- `wbadmin get versions` (verifica se há versões de backup registradas)

---

## Macros

Ajustáveis por host em **Configuration → Hosts → [host] → Macros**.

| Macro | Padrão | Descrição |
|---|---|---|
| `{$WIN.BACKUP.AGE.DISASTER}` | `48` | Idade do último backup, em horas, para DISASTER. Número puro, sem sufixo |
| `{$WIN.BACKUP.AGE.WARN}` | `26` | Idade do último backup, em horas, para WARNING. Número puro, sem sufixo |
| `{$WIN.BACKUP.MAX_RUNTIME}` | `4h` | Duração máxima tolerada do processo de backup |
| `{$WIN.BACKUP.NO_SUCCESS.PERIOD}` | `48h` | Janela sem nenhum evento de sucesso (Event ID 4) para alertar. Período de tempo, com sufixo |

> As macros `AGE.*` são comparadas com `win.backup.age_hours`, que já está em horas. Não use sufixo de tempo (`48h`) nelas: o Zabbix converteria para segundos e o trigger nunca dispararia.

---

## Triggers (6)

### DISASTER

| Nome | Condição | opdata |
|---|---|---|
| Último backup com mais de `{$WIN.BACKUP.AGE.DISASTER}`h | `age_hours > AGE.DISASTER and age_hours <> -1` | Idade: {ITEM.LASTVALUE} |
| Nenhum evento de backup encontrado no Event Log | `age_hours = -1` | Sem Event ID 4 em Microsoft-Windows-Backup |

### HIGH

| Nome | Condição |
|---|---|
| Nenhum backup registrado (`wbadmin get versions` falha) | `exists = 0` |

### WARNING

| Nome | Condição | Depende de | opdata |
|---|---|---|---|
| Último backup com mais de `{$WIN.BACKUP.AGE.WARN}`h | `age_hours > AGE.WARN and age_hours <> -1` | Trigger de idade DISASTER | Idade: {ITEM.LASTVALUE} |
| Sem evento de sucesso (ID 4) nas últimas `{$WIN.BACKUP.NO_SUCCESS.PERIOD}` | `max(last_ok, NO_SUCCESS.PERIOD) = 0` | Trigger de nenhum backup registrado | Sem Event ID 4 nas últimas Xh |

### INFO

| Nome | Condição |
|---|---|
| Backup em execução há mais de `{$WIN.BACKUP.MAX_RUNTIME}` | `min(running, MAX_RUNTIME) = 1` |

Todos os triggers usam `manual_close=YES` e uma expressão de recuperação explícita.

---

## Mapas de Valor

| Mapa de Valor | 0 | 1 |
|---|---|---|
| WB Running | Not running | Running |
| WB Yes/No | No/Fail | Yes/OK |

---

## Instalação

### 1. Pré-requisitos

O Windows Server Backup precisa estar instalado:

```powershell
# Verificar se está instalado
Get-WindowsFeature Windows-Server-Backup

# Instalar se necessário
Install-WindowsFeature Windows-Server-Backup
```

O template depende do Event Log `Microsoft-Windows-Backup`:
- **Event ID 1:** Backup iniciado
- **Event ID 4:** Backup concluído com sucesso

```powershell
# Verificar se existem eventos de backup
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Backup'; Id=4} -MaxEvents 5
```

### 2. Configurar o Zabbix Agent 2 no Windows

Copie o arquivo **`user_parameters_windows_backup.conf`** para a pasta de configuração do agente:

```
C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\
```

**Configurações essenciais em `zabbix_agent2.conf`:**
```ini
ServerActive=<IP-DO-SERVIDOR-ZABBIX>   # IP do Zabbix Server
Hostname=<NOME-DO-HOST-NO-ZABBIX>      # Nome exato do host no Zabbix
UnsafeUserParameters=1                 # Necessário para os UserParameters em PowerShell
Timeout=30
```

### 3. Reiniciar o serviço do agente

```powershell
Restart-Service "Zabbix Agent 2"
```

### 4. Importar o template no Zabbix

1. **Configuration → Templates → Import**
2. Selecione `template.json`
3. Marque: Create new + Update existing
4. Clique em **Import**

### 5. Aplicar ao host

1. **Configuration → Hosts → [nome-do-host] → Templates**
2. Adicione: **Windows Backup by Zabbix agent 2**
3. Ajuste as macros conforme o ambiente

---

## UserParameters

Arquivo: **`user_parameters_windows_backup.conf`**

| UserParameter | Descrição |
|---|---|
| `win.backup.exists` | O `wbadmin get versions` é bem-sucedido? (1/0) |
| `win.backup.running` | Há um backup em execução (Event ID 1 sem ID 4 posterior)? (1/0) |
| `win.backup.last_ok` | Foi encontrado um evento de sucesso (Event ID 4)? (1/0) |
| `win.backup.last_time` | Timestamp do último backup bem-sucedido (`YYYY-MM-DD HH:MM:SS` ou `N/A`) |
| `win.backup.age_hours` | Horas desde o último backup bem-sucedido (float, InvariantCulture), ou `-1` se não encontrado |

---

## Solução de Problemas

**`win.backup.age_hours` retorna `-1`:**
```powershell
# Verificar se existem eventos de sucesso no Event Log
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Backup'; Id=4} -MaxEvents 5
```
- Confirme que o Windows Server Backup está configurado e já concluiu ao menos uma execução

**`win.backup.exists` retorna `0`:**
```powershell
# Executar manualmente no servidor para verificar erros
wbadmin get versions
```
- Verifique se o recurso Windows Server Backup está instalado e se o backup agendado está configurado

**`win.backup.age_hours` retorna um valor com vírgula decimal (locale pt-BR):**
- O UserParameter usa `InvariantCulture` para forçar o ponto decimal
- Se o problema persistir, verifique a versão do PowerShell no host

---

## Nota sobre Combinação com ATHOS

O template **Windows Backup** pode ser aplicado **em conjunto** com o template **ATHOS** no mesmo host.

- **ATHOS** monitora o backup da **aplicação** (`pg_dump` → `.backup`)
- **Windows Backup** monitora o backup do **sistema operacional** (`wbadmin` → imagem do servidor)

Os dois são complementares e usam arquivos de UserParameters separados (sem conflito):
- `user_parameters_athos.conf` → keys `athos.*`
- `user_parameters_windows_backup.conf` → keys `win.backup.*`

---

## Changelog

| Versão | Mudanças |
|---|---|
| 2.0 | Macros para thresholds; trigger DISASTER para `age_hours = -1`; preprocessing `DISCARD_UNCHANGED_HEARTBEAT`; tag `no_metrics` nos itens 0/1; `opdata` em todos os triggers; dependências entre triggers; grupo movido para Templates/Applications |
| 1.0 | Versão inicial |

---

<a id="en-us"></a>
## 🇺🇸 English

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
| `{$WIN.BACKUP.AGE.DISASTER}` | `48` | Age of the last backup, in hours, for DISASTER. Plain number, no suffix |
| `{$WIN.BACKUP.AGE.WARN}` | `26` | Age of the last backup, in hours, for WARNING. Plain number, no suffix |
| `{$WIN.BACKUP.MAX_RUNTIME}` | `4h` | Maximum tolerated duration of the backup process |
| `{$WIN.BACKUP.NO_SUCCESS.PERIOD}` | `48h` | Window with no success event (Event ID 4) before alerting. Time period, with suffix |

> The `AGE.*` macros are compared against `win.backup.age_hours`, which is already in hours. Do not use a time suffix (`48h`) on them: Zabbix would convert it to seconds and the trigger would never fire.

---

## Triggers (6)

### DISASTER

| Name | Condition | opdata |
|---|---|---|
| Last backup older than `{$WIN.BACKUP.AGE.DISASTER}`h | `age_hours > AGE.DISASTER and age_hours <> -1` | Age: {ITEM.LASTVALUE} |
| No backup event found in the Event Log | `age_hours = -1` | No Event ID 4 in Microsoft-Windows-Backup |

### HIGH

| Name | Condition |
|---|---|
| No backup registered (`wbadmin get versions` fails) | `exists = 0` |

### WARNING

| Name | Condition | Depends on | opdata |
|---|---|---|---|
| Last backup older than `{$WIN.BACKUP.AGE.WARN}`h | `age_hours > AGE.WARN and age_hours <> -1` | DISASTER age trigger | Age: {ITEM.LASTVALUE} |
| No success event (ID 4) in the last `{$WIN.BACKUP.NO_SUCCESS.PERIOD}` | `max(last_ok, NO_SUCCESS.PERIOD) = 0` | No backup registered trigger | No Event ID 4 in the last Xh |

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

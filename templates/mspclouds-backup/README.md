# MSPClouds Backup Monitor

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-4.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-HTTP_Agent-009639?style=flat-square)
![LLD](https://img.shields.io/badge/LLD-per_client-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

**Categoria:** Applications / Cloud
**Método de coleta:** HTTP Agent (item mestre) + DEPENDENT (itens derivados)
**Itens:** 11 gerais + descoberta LLD (por cliente/backup set, por alerta)
**Versão do Zabbix:** 7.4+

## Descrição

Template Zabbix para monitoramento de backups em nuvem via **API MSPClouds**. Ele coleta o status agregado dos backups (sucesso / erro / aviso / em execução / sem monitoramento) e os alertas ativos de uma conta MSPClouds, e usa descoberta de baixo nível (LLD) para criar automaticamente itens e triggers por cliente/backup set e por alerta ativo — sem exigir um Zabbix Agent em nenhum endpoint monitorado.

## O que é Monitorado

### Itens gerais (11)

| Chave | Descrição | History | Trends |
|---|---|---|---|
| `mspclouds.alerts.raw` | JSON bruto do endpoint de alertas (item mestre) | 7d | — |
| `mspclouds.alerts.count` | Quantidade de alertas ativos | 90d | 365d |
| `mspclouds.status.raw` | JSON bruto do endpoint de status (item mestre) | 7d | — |
| `mspclouds.company.name` | Nome da empresa/provedor | padrão | — |
| `mspclouds.status.success` | Backups finalizados com sucesso | 90d | 365d |
| `mspclouds.status.error` | Backups finalizados com erro | 90d | 365d |
| `mspclouds.status.warning` | Backups finalizados com aviso | 90d | 365d |
| `mspclouds.status.info` | Backups atualmente **em execução** | 90d | 365d |
| `mspclouds.status.nomon` | Backups sem monitoramento | 90d | 365d |
| `mspclouds.status.total` | Total de tarefas de backup monitoradas | 90d | 365d |
| `mspclouds.status.updated_at` | Timestamp da última atualização dos dados | padrão | — |

### Descoberta de baixo nível (LLD)

| Regra | Itens descobertos | Triggers |
|---|---|---|
| Clientes e backup sets | Status, datas, timestamps, URL do relatório, idade desde o último sucesso | Backup com ERRO (HIGH), backup atrasado (WARNING) |
| Alertas ativos | Mensagem por alerta (cliente + tipo) | — |

## Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$MSPCLOUDS.API.KEY}` | — | Chave de autenticação da API MSPClouds (texto secreto) |
| `{$MSPCLOUDS.API.URL}` | `https://mspclouds.com/api/v1` | URL base da API |
| `{$MSPCLOUDS.BACKUP.MAX_AGE}` | `36h` | Idade máxima tolerada sem um backup bem-sucedido |

> **Importante:** `{$MSPCLOUDS.API.KEY}` deve ser configurada **por host**, pois cada cliente possui sua própria chave de API. A macro é do tipo `SECRET_TEXT` e não vem com nenhum valor padrão embutido no template.

## Triggers

### Triggers gerais

| Nome | Severidade | Condição | opdata |
|---|---|---|---|
| Existem N backup(s) com ERRO | HIGH | `status.error > 0` | "Verifique os alertas individuais de cada cliente" |
| Existem N backup(s) com WARNING | WARNING | `status.warning > 0` | "Existem {ITEM.LASTVALUE} backup(s) com aviso" |
| Existem N alerta(s) ativo(s) | INFO | `alerts.count > 0 and status.error > 0` | "Verifique os itens de alerta para detalhes" |

### Trigger prototypes (por cliente/backup set)

| Nome | Severidade | Condição |
|---|---|---|
| Backup "[backupset]" com ERRO | HIGH | `status = "error"` |
| Backup "[backupset]" sem sucesso há mais de {MAX_AGE} | WARNING | `now() - last_success_ts > MAX_AGE` |

## Arquitetura de Coleta

```
HTTP Agent → API MSPClouds (2x/dia — 08:00)
    │
    ├── mspclouds.alerts.raw        (JSON bruto — history 7d)
    │       ├── mspclouds.alerts.count      (JSONPATH: $.length())
    │       └── [LLD] mspclouds.alert.message[client,type,created]
    │
    └── mspclouds.status.raw        (JSON bruto — history 7d)
            ├── mspclouds.company.name
            ├── mspclouds.status.success    ($.status.success)
            ├── mspclouds.status.error      ($.status.error)
            ├── mspclouds.status.warning    ($.status.warning)
            ├── mspclouds.status.info       ($.status.info — em execução)
            ├── mspclouds.status.nomon      ($.status.nomon)
            ├── mspclouds.status.total      ($.status.total)
            ├── mspclouds.status.updated_at
            └── [LLD] por cliente/backup set
                    ├── status / status_code / status_desc
                    ├── last_backup_date / last_backup_ts
                    ├── last_success_date / last_success_ts
                    ├── last_success_age  (CALCULATED)
                    └── report_url
```

## Diferenças em Relação à Documentação Oficial

A documentação oficial (validada no Zabbix 6.2) descreve uma integração via script bash + UserParameter no agente Zabbix. Este template usa uma abordagem diferente e mais avançada:

| Aspecto | Documentação oficial | Este template |
|---|---|---|
| Coleta | Bash script + UserParameter | HTTP_AGENT nativo no Zabbix Server |
| Agente necessário | Sim (no servidor Zabbix) | Não |
| Itens | 5 (básicos) | 11 gerais + LLD por cliente |
| Triggers | — | Por backup set, com URL do relatório |
| Zabbix | 6.2 | 7.4 |

## Dashboard Sugerido (conforme documentação oficial)

Monte um dashboard com:
- **Widgets de valor (tiles coloridos):** success (verde), error (vermelho), warning (laranja), info (azul), total
- **Gráfico de pizza "Consolidated Backup":** success + error + warning + info (excluindo nomon)
- **Data overview:** grade com status por cliente descoberto via LLD

## Limitação de Chamadas de API

A coleta é configurada para **2x por dia** (intervalo de 8 horas) para economizar chamadas de API, que podem estar sujeitas a custo ou limites de rate.

Caso seja necessária uma checagem mais frequente, ajuste o `delay` dos itens mestres e verifique os limites da API MSPClouds do cliente.

## Instalação

### 1. Importar o template

**Configuration → Templates → Import** → `template.json`

### 2. Criar o host

O template **não exige um Zabbix Agent** — a coleta é feita diretamente pelo servidor Zabbix via HTTP.

Crie um host "virtual" para cada cliente MSPClouds:
- **Nome:** `MSPClouds - [Nome do Cliente]`
- **Interface:** nenhuma (ou um IP fictício)
- **Template:** MSPClouds Backup Monitor

### 3. Configurar as macros do host

| Macro | Valor |
|---|---|
| `{$MSPCLOUDS.API.KEY}` | Chave de API do cliente (obtida no painel MSPClouds) |
| `{$MSPCLOUDS.API.URL}` | `https://mspclouds.com/api/v1` (confirmar com a MSPClouds) |
| `{$MSPCLOUDS.BACKUP.MAX_AGE}` | Ajustar conforme o SLA do cliente (ex: `24h`, `36h`, `48h`) |

## Changelog

| Versão | Mudanças |
|---|---|
| 4.0 | Adicionado `mspclouds.status.info` (backups em execução); history 90d e trends 365d nos itens numéricos; opdata no trigger de warning |
| 3.0 | Descoberta LLD de clientes/backup sets; trigger prototypes por cliente; URL do relatório no opdata |

---

<a id="en-us"></a>
## 🇺🇸 English

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

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

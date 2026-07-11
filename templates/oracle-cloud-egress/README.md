# Oracle Cloud Egress Monthly by HTTP

![Zabbix](https://img.shields.io/badge/Zabbix-7.4+-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0-7F13EC?style=flat-square)
![Oracle Cloud](https://img.shields.io/badge/Oracle_Cloud-OCI-F80000?style=flat-square&logo=oracle&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-HTTP_Script-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

**Categoria:** Nuvem / Rede
**Método de coleta:** SCRIPT (API de Monitoramento OCI, assinatura HTTP RSA-SHA256)
**Itens:** 4
**Triggers:** 3
**Versão do Zabbix:** 7.4+

## Descrição

Monitora o egresso de rede (`NetworksBytesOut`) do mês corrente para uma instância Compute da Oracle Cloud Infrastructure (OCI) via API de Monitoramento OCI. O egresso é o recurso mais propenso a gerar cobranças inesperadas em uma tenancy **Always Free**, já que o limite gratuito é de 10 TB/mês — este template acompanha o uso acumulado no mês em relação a esse limite e escalona alertas conforme ele é consumido.

É um complemento aos templates oficiais `Oracle Cloud by HTTP` e `Oracle Cloud Compute by HTTP` e deve ser aplicado ao mesmo host, reutilizando as mesmas macros de autenticação da API OCI e da instância compute.

## Como funciona

1. Um item do tipo `SCRIPT` (`oci.egress.monthly.get`) assina e envia uma requisição à API de Monitoramento OCI usando autenticação por assinatura HTTP RSA-SHA256.
2. Ele calcula `startTime` = primeiro dia do mês corrente (UTC) e `endTime` = agora, e então consulta `POST /20180401/metrics/actions/summarizeMetricsData` no namespace `oci_computeagent` com a query MQL `NetworksBytesOut[1d]{resourceId=<instance_id>}.rate()`.
3. `NetworksBytesOut` é um contador cumulativo; `.rate()` retorna bytes/segundo em resolução diária, valor que o script multiplica por 86400 para obter bytes por dia e soma em todos os datapoints retornados para chegar ao total acumulado do mês.
4. O percentual do limite mensal configurado e os bytes restantes são calculados a partir desse total.
5. Três itens dependentes extraem `bytes`, `pct` e `remaining_bytes` do JSON bruto via pré-processamento JSONPath.
6. Três triggers escalonam conforme o uso se aproxima do limite — `WARNING` em 80%, `HIGH` em 90%, `DISASTER` em 95% por padrão — cada uma suprimida pela trigger de severidade imediatamente superior, de modo que apenas o alerta ativo mais severo fica visível.

## Itens

| Item key | Nome | Tipo | Intervalo | Tipo de valor |
|---|---|---|---|---|
| `oci.egress.monthly.get` | OCI: Get monthly egress data | SCRIPT | 1h | TEXT (JSON bruto) |
| `oci.egress.monthly.bytes` | OCI: Egress mensal (bytes) | DEPENDENT | — | FLOAT (B) |
| `oci.egress.monthly.pct` | OCI: Egress mensal (%) | DEPENDENT | — | FLOAT (%) |
| `oci.egress.monthly.remaining` | OCI: Egress mensal restante | DEPENDENT | — | FLOAT (B) |

O item bruto retorna JSON no formato `{"bytes": <total>, "pct": <percent_of_limit>, "remaining_bytes": <remaining>}`; os itens dependentes extraem `bytes`, `pct` e `remaining_bytes` via pré-processamento JSONPath `$.bytes`, `$.pct` e `$.remaining_bytes`, descartando valores inalterados após um heartbeat de 6h.

## Triggers

| Nome | Severidade | Condição |
|---|---|---|
| OCI Egress: Uso mensal de egresso alto (>= `{$OCI.EGRESS.WARN.PCT}`%) | WARNING | `last(/.../oci.egress.monthly.pct) >= {$OCI.EGRESS.WARN.PCT}` |
| OCI Egress: Uso mensal de egresso crítico (>= `{$OCI.EGRESS.HIGH.PCT}`%) | HIGH | `last(/.../oci.egress.monthly.pct) >= {$OCI.EGRESS.HIGH.PCT}` |
| OCI Egress: Uso mensal de egresso em nível de desastre (>= `{$OCI.EGRESS.DISASTER.PCT}`%) | DISASTER | `last(/.../oci.egress.monthly.pct) >= {$OCI.EGRESS.DISASTER.PCT}` |

Cada trigger de severidade mais baixa declara uma dependência da próxima acima, de modo que apenas a trigger de maior severidade atualmente ativa permanece visível no frontend.

<a id="macros-pt-br"></a>
## Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$OCI.EGRESS.LIMIT.TB}` | `10` | Limite mensal de egresso em TB (OCI Always Free = 10 TB/mês). |
| `{$OCI.EGRESS.WARN.PCT}` | `80` | % do limite em que a trigger WARNING dispara. |
| `{$OCI.EGRESS.HIGH.PCT}` | `90` | % do limite em que a trigger HIGH dispara. |
| `{$OCI.EGRESS.DISASTER.PCT}` | `95` | % do limite em que a trigger DISASTER dispara. |
| `{$OCI.API.TELEMETRY.HOST}` | *(nenhum, ex.: `telemetry.sa-saopaulo-1.oraclecloud.com`)* | Hostname da API de Monitoramento OCI para a região da sua tenancy. |
| `{$OCI.COMPUTE.COMPARTMENT.ID}` | *(nenhum)* | OCID do compartment (geralmente igual ao OCID da tenancy). Compartilhado com `Oracle Cloud Compute by HTTP`. |
| `{$OCI.COMPUTE.INSTANCE.ID}` | *(nenhum)* | OCID da instância compute cujo egresso é medido. Compartilhado com `Oracle Cloud Compute by HTTP`. |
| `{$OCI.API.TENANCY}` | *(nenhum)* | OCID da tenancy. **Deve ser definido por host — sem padrão, por segurança.** Compartilhado com o template `Oracle Cloud by HTTP`. |
| `{$OCI.API.USER}` | *(nenhum)* | OCID do usuário da API. **Deve ser definido por host — sem padrão, por segurança.** |
| `{$OCI.API.PRIVATE.KEY}` | *(nenhum)* | Conteúdo PEM da chave privada de assinatura da API. **Deve ser definido por host — sem padrão, por segurança.** |
| `{$OCI.API.FINGERPRINT}` | *(nenhum)* | Fingerprint da chave de assinatura da API. **Deve ser definido por host — sem padrão, por segurança.** |
| `{$OCI.HTTP.RETURN.CODE.OK}` | *(nenhum, espera `200`)* | Código de status HTTP esperado para uma chamada de API bem-sucedida. Compartilhado com o template `Oracle Cloud by HTTP`. |
| `{$OCI.HTTP.PROXY}` | *(nenhum)* | URL de proxy para a requisição HTTP. Deixe vazio se nenhum proxy for usado. |

As quatro macros de autenticação (`TENANCY`, `USER`, `PRIVATE.KEY`, `FINGERPRINT`) intencionalmente não trazem **nenhum valor padrão** — elas armazenam credenciais sensíveis e devem ser definidas apenas no nível do host, nunca no próprio template.

## Requisitos

- Zabbix Server 7.4+, com o engine de pré-processamento/scripting JavaScript habilitado (nativo).
- O host já deve ter as macros de autenticação da API OCI e da instância compute configuradas (veja a seção Macros acima) — normalmente compartilhadas com os templates `Oracle Cloud by HTTP` e `Oracle Cloud Compute by HTTP` aplicados ao mesmo host.
- O usuário da API OCI precisa de acesso de leitura às métricas de compute (namespace `oci_computeagent`), o que já é padrão para qualquer conta que colete métricas com o template oficial de Compute.

## Instalação

### 1. Reutilize (ou gere) a chave de assinatura da API OCI

Se o host já executa `Oracle Cloud by HTTP`, a chave de API, o OCID da tenancy, o OCID do usuário e o fingerprint já estão disponíveis e podem ser reutilizados. Caso contrário, gere uma no Console OCI: **Profile → User Settings → API Keys → Add API Key**.

### 2. Importe o template

**Data collection → Templates → Import**, selecione `template.json`.

### 3. Aplique ao host e configure as macros

No host que já executa `Oracle Cloud by HTTP` / `Oracle Cloud Compute by HTTP`:

- **Data collection → Hosts → [host] → Templates** → adicione `Oracle Cloud Egress Monthly by HTTP`.
- Aba **Macros** → defina `{$OCI.API.TENANCY}`, `{$OCI.API.USER}`, `{$OCI.API.PRIVATE.KEY}`, `{$OCI.API.FINGERPRINT}`, `{$OCI.API.TELEMETRY.HOST}`, `{$OCI.COMPUTE.COMPARTMENT.ID}`, `{$OCI.COMPUTE.INSTANCE.ID}` e `{$OCI.HTTP.RETURN.CODE.OK}` (`200`) caso ainda não sejam herdadas de templates irmãos.
- Opcionalmente, sobrescreva `{$OCI.EGRESS.LIMIT.TB}` se o limite gratuito de egresso do seu plano for diferente de 10 TB, e os limiares `{$OCI.EGRESS.WARN.PCT}` / `{$OCI.EGRESS.HIGH.PCT}` / `{$OCI.EGRESS.DISASTER.PCT}` caso queira níveis de alerta diferentes.

### 4. Verifique a coleta

Aguarde o primeiro ciclo de coleta (até 1h) e então verifique em **Monitoring → Hosts → [host] → Latest data**.

## Notas

### Limite do Free Tier

O plano OCI Always Free inclui **10 TB/mês de egresso** (transferência de dados de saída) somando todas as regiões. Esse limite é compartilhado entre todas as instâncias da conta. Detalhes: [OCI Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

### Janela curta no início do mês

No 1º dia do mês, `startTime` é igual a `endTime`, então o valor reportado pode ser `0 bytes`. Isso é esperado e não dispara nenhum alerta, já que ainda não ocorreu egresso.

---

<a id="en-us"></a>
## 🇺🇸 English

**Category:** Cloud / Network
**Collection method:** SCRIPT (OCI Monitoring API, RSA-SHA256 HTTP Signature)
**Items:** 4
**Triggers:** 3
**Zabbix version:** 7.4+

## Description

Monitors the current month's outbound network egress (`NetworksBytesOut`) for an Oracle Cloud Infrastructure (OCI) Compute instance via the OCI Monitoring API. Egress is the resource most likely to generate unexpected charges on an **Always Free** tenancy, since the free allowance is capped at 10 TB/month, so this template tracks month-to-date usage against that limit and escalates as it gets consumed.

It is a companion to the official `Oracle Cloud by HTTP` and `Oracle Cloud Compute by HTTP` templates and is meant to be applied to the same host, reusing the same OCI API authentication and compute-instance macros.

## How it works

1. A `SCRIPT`-type item (`oci.egress.monthly.get`) signs and sends a request to the OCI Monitoring API using RSA-SHA256 HTTP Signature authentication.
2. It computes `startTime` = first day of the current month (UTC) and `endTime` = now, then queries `POST /20180401/metrics/actions/summarizeMetricsData` in the `oci_computeagent` namespace with the MQL query `NetworksBytesOut[1d]{resourceId=<instance_id>}.rate()`.
3. `NetworksBytesOut` is a cumulative counter; `.rate()` returns bytes/second at daily resolution, which the script multiplies by 86400 to get daily bytes and sums across every returned datapoint to obtain the month-to-date total.
4. The percentage of the configured monthly limit and the remaining bytes are computed from that total.
5. Three dependent items extract `bytes`, `pct` and `remaining_bytes` from the raw JSON via JSONPath preprocessing.
6. Three triggers escalate as usage approaches the limit — `WARNING` at 80%, `HIGH` at 90%, `DISASTER` at 95% by default — each one suppressed by the next higher-severity trigger so only the most severe active alert is shown.

## Items

| Item key | Name | Type | Interval | Value type |
|---|---|---|---|---|
| `oci.egress.monthly.get` | OCI: Get monthly egress data | SCRIPT | 1h | TEXT (raw JSON) |
| `oci.egress.monthly.bytes` | OCI: Egress mensal (bytes) | DEPENDENT | — | FLOAT (B) |
| `oci.egress.monthly.pct` | OCI: Egress mensal (%) | DEPENDENT | — | FLOAT (%) |
| `oci.egress.monthly.remaining` | OCI: Egress mensal restante | DEPENDENT | — | FLOAT (B) |

The raw item returns JSON in the form `{"bytes": <total>, "pct": <percent_of_limit>, "remaining_bytes": <remaining>}`; the dependent items extract `bytes`, `pct` and `remaining_bytes` via `$.bytes`, `$.pct` and `$.remaining_bytes` JSONPath preprocessing, discarding unchanged values after a 6h heartbeat.

## Triggers

| Name | Severity | Condition |
|---|---|---|
| OCI Egress: Uso mensal de egresso alto (>= `{$OCI.EGRESS.WARN.PCT}`%) | WARNING | `last(/.../oci.egress.monthly.pct) >= {$OCI.EGRESS.WARN.PCT}` |
| OCI Egress: Uso mensal de egresso crítico (>= `{$OCI.EGRESS.HIGH.PCT}`%) | HIGH | `last(/.../oci.egress.monthly.pct) >= {$OCI.EGRESS.HIGH.PCT}` |
| OCI Egress: Uso mensal de egresso em nível de desastre (>= `{$OCI.EGRESS.DISASTER.PCT}`%) | DISASTER | `last(/.../oci.egress.monthly.pct) >= {$OCI.EGRESS.DISASTER.PCT}` |

Each lower-severity trigger declares a dependency on the next one up, so only the highest-severity trigger that is currently true stays visible in the frontend.

<a id="macros-en-us"></a>
## Macros

| Macro | Default | Description |
|---|---|---|
| `{$OCI.EGRESS.LIMIT.TB}` | `10` | Monthly egress limit in TB (OCI Always Free = 10 TB/month). |
| `{$OCI.EGRESS.WARN.PCT}` | `80` | % of the limit at which the WARNING trigger fires. |
| `{$OCI.EGRESS.HIGH.PCT}` | `90` | % of the limit at which the HIGH trigger fires. |
| `{$OCI.EGRESS.DISASTER.PCT}` | `95` | % of the limit at which the DISASTER trigger fires. |
| `{$OCI.API.TELEMETRY.HOST}` | *(none, e.g. `telemetry.sa-saopaulo-1.oraclecloud.com`)* | OCI Monitoring API hostname for your tenancy's region. |
| `{$OCI.COMPUTE.COMPARTMENT.ID}` | *(none)* | Compartment OCID (usually equal to the tenancy OCID). Shared with `Oracle Cloud Compute by HTTP`. |
| `{$OCI.COMPUTE.INSTANCE.ID}` | *(none)* | OCID of the compute instance whose egress is measured. Shared with `Oracle Cloud Compute by HTTP`. |
| `{$OCI.API.TENANCY}` | *(none)* | Tenancy OCID. **Must be set per host — no default, for security.** Shared with the `Oracle Cloud by HTTP` template. |
| `{$OCI.API.USER}` | *(none)* | API user OCID. **Must be set per host — no default, for security.** |
| `{$OCI.API.PRIVATE.KEY}` | *(none)* | PEM content of the API signing private key. **Must be set per host — no default, for security.** |
| `{$OCI.API.FINGERPRINT}` | *(none)* | Fingerprint of the API signing key. **Must be set per host — no default, for security.** |
| `{$OCI.HTTP.RETURN.CODE.OK}` | *(none, expects `200`)* | Expected HTTP status code for a successful API call. Shared with the `Oracle Cloud by HTTP` template. |
| `{$OCI.HTTP.PROXY}` | *(none)* | Proxy URL for the HTTP request. Leave empty if no proxy is used. |

The four authentication macros (`TENANCY`, `USER`, `PRIVATE.KEY`, `FINGERPRINT`) intentionally ship with **no default value** — they hold sensitive credentials and are expected to be defined at the host level only, never in the template itself.

## Requirements

- Zabbix Server 7.4+, with the JavaScript preprocessing/scripting engine enabled (built in).
- The host must already have the OCI API authentication and compute-instance macros configured (see [Macros](#macros-en-us)) — typically shared with the `Oracle Cloud by HTTP` and `Oracle Cloud Compute by HTTP` templates applied to the same host.
- The OCI API user needs read access to compute metrics (`oci_computeagent` namespace), which is standard for any account already collecting metrics with the official Compute template.

## Setup

### 1. Reuse (or generate) the OCI API signing key

If the host already runs `Oracle Cloud by HTTP`, the API key, tenancy OCID, user OCID and fingerprint are already available and can be reused. Otherwise, generate one in the OCI Console: **Profile → User Settings → API Keys → Add API Key**.

### 2. Import the template

**Data collection → Templates → Import**, select `template.json`.

### 3. Apply to the host and configure macros

On the host that already runs `Oracle Cloud by HTTP` / `Oracle Cloud Compute by HTTP`:

- **Data collection → Hosts → [host] → Templates** → add `Oracle Cloud Egress Monthly by HTTP`.
- **Macros** tab → set `{$OCI.API.TENANCY}`, `{$OCI.API.USER}`, `{$OCI.API.PRIVATE.KEY}`, `{$OCI.API.FINGERPRINT}`, `{$OCI.API.TELEMETRY.HOST}`, `{$OCI.COMPUTE.COMPARTMENT.ID}`, `{$OCI.COMPUTE.INSTANCE.ID}` and `{$OCI.HTTP.RETURN.CODE.OK}` (`200`) if not already inherited from sibling templates.
- Optionally override `{$OCI.EGRESS.LIMIT.TB}` if your plan's free egress allowance differs from 10 TB, and the `{$OCI.EGRESS.WARN.PCT}` / `{$OCI.EGRESS.HIGH.PCT}` / `{$OCI.EGRESS.DISASTER.PCT}` thresholds if you want different alert levels.

### 4. Verify collection

Wait for the first collection cycle (up to 1h), then check **Monitoring → Hosts → [host] → Latest data**.

## Notes

### Free Tier limit

The OCI Always Free plan includes **10 TB/month of egress** (outbound data transfer) from all regions combined. This limit is shared across every instance in the account. Details: [OCI Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

### Short window at the start of the month

On the 1st day of the month, `startTime` equals `endTime`, so the reported value may be `0 bytes`. This is expected and does not trigger any alert, since no egress has occurred yet.

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

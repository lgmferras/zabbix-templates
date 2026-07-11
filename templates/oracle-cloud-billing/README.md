# Oracle Cloud Billing Monthly by HTTP

![Zabbix](https://img.shields.io/badge/Zabbix-7.4+-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0-7F13EC?style=flat-square)
![Oracle Cloud](https://img.shields.io/badge/Oracle_Cloud-OCI-F80000?style=flat-square&logo=oracle&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-HTTP_Script-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

**Categoria:** Nuvem / Custo
**Método de coleta:** SCRIPT (OCI Usage Reports API, assinatura HTTP RSA-SHA256)
**Itens:** 2
**Triggers:** 1
**Versão do Zabbix:** 7.4+

### Descrição

Monitora o custo da fatura do mês atual da Oracle Cloud Infrastructure (OCI) através da OCI Usage Reports API. Em tenants **Always Free**, o custo deve ser sempre `0.00`, portanto este template dispara um alerta assim que qualquer cobrança inesperada aparecer na conta.

É complementar aos templates oficiais `Oracle Cloud by HTTP` e deve ser aplicado ao mesmo host, reaproveitando as mesmas macros de autenticação da API OCI.

### Como funciona

1. Um item do tipo `SCRIPT` (`oci.billing.monthly.get`) assina e envia uma requisição à OCI Usage Reports API usando autenticação por assinatura HTTP RSA-SHA256.
2. Calcula `startTime` = primeiro dia do mês atual e `endTime` = primeiro dia do próximo mês (UTC), depois consulta `POST /20200107/usage` com `granularity: MONTHLY` e `queryType: COST`.
3. O campo `computedAmount` de cada item da resposta é somado para obter o custo total mensal.
4. Um item dependente (`oci.billing.monthly.cost`) extrai o campo `cost` do JSON bruto via pré-processamento JSONPath.
5. Um trigger dispara com severidade `HIGH` caso o custo acumulado ultrapasse o limiar configurado — em uma conta Always Free, qualquer cobrança diferente de zero merece investigação imediata.

### Itens

| Item key | Nome | Tipo | Intervalo | Tipo de valor |
|---|---|---|---|---|
| `oci.billing.monthly.get` | OCI: Get monthly billing data | SCRIPT | 6h | TEXT (JSON bruto) |
| `oci.billing.monthly.cost` | OCI: Custo mensal (fatura) | DEPENDENT | — | FLOAT |

O item bruto retorna um JSON no formato `{"cost": <total_cost>, "currency": "BRL"}`; o item dependente extrai `cost` via pré-processamento JSONPath `$.cost`, descartando valores inalterados após um heartbeat de 12h.

### Triggers

| Nome | Severidade | Condição |
|---|---|---|
| Cobranças inesperadas detectadas na fatura mensal | HIGH | `last(/.../oci.billing.monthly.cost) > {$OCI.BILLING.WARN.COST}` |

<a id="macros-pt-br"></a>
### Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$OCI.API.USAGE.HOST}` | `usageapi.sa-saopaulo-1.oci.oraclecloud.com` | Hostname da OCI Usage Reports API. Sobrescreva com a home region do seu tenancy, caso seja diferente. |
| `{$OCI.BILLING.WARN.COST}` | `1` | Custo mensal (na moeda local) acima do qual o trigger HIGH é disparado. O padrão assume uma conta Always Free, onde qualquer cobrança acima de um limiar de arredondamento insignificante é inesperada. |
| `{$OCI.API.TENANCY}` | *(nenhum)* | OCID do tenancy. **Deve ser definido por host — sem padrão, por segurança.** Compartilhada com o template `Oracle Cloud by HTTP`. |
| `{$OCI.API.USER}` | *(nenhum)* | OCID do usuário da API. **Deve ser definido por host — sem padrão, por segurança.** |
| `{$OCI.API.PRIVATE.KEY}` | *(nenhum)* | Conteúdo PEM da chave privada de assinatura da API. **Deve ser definido por host — sem padrão, por segurança.** |
| `{$OCI.API.FINGERPRINT}` | *(nenhum)* | Fingerprint da chave de assinatura da API. **Deve ser definido por host — sem padrão, por segurança.** |
| `{$OCI.HTTP.RETURN.CODE.OK}` | *(nenhum, espera `200`)* | Código de status HTTP esperado para uma chamada de API bem-sucedida. Compartilhada com o template `Oracle Cloud by HTTP`. |
| `{$OCI.HTTP.PROXY}` | *(nenhum)* | URL do proxy para a requisição HTTP. Deixe vazio se nenhum proxy for utilizado. |

As quatro macros de autenticação (`TENANCY`, `USER`, `PRIVATE.KEY`, `FINGERPRINT`) intencionalmente não possuem valor padrão — elas armazenam credenciais sensíveis e devem ser definidas apenas em nível de host, nunca no próprio template.

### Requisitos

- Zabbix Server 7.4+, com o mecanismo de pré-processamento/scripting JavaScript habilitado (nativo).
- O host já deve ter as macros de autenticação da API OCI configuradas (veja [Macros](#macros-pt-br)) — normalmente compartilhadas com o template `Oracle Cloud by HTTP` aplicado ao mesmo host.
- O usuário da API OCI precisa da policy IAM `inspect usage-reports` no tenancy:
  ```
  Allow group <group-name> to inspect usage-reports in tenancy
  ```
  Sem essa policy, a chamada à Usage API retorna 404 ou um erro de autorização.

### Instalação

#### 1. Gerar uma chave de assinatura da API OCI

No console da OCI: **Profile → User Settings → API Keys → Add API Key**. Gere ou envie um par de chaves RSA. A OCI mostrará o **fingerprint** e uma **prévia do arquivo de configuração** contendo o **OCID do tenancy** e o **OCID do usuário** — salve-os, você precisará deles para as macros do host.

#### 2. Conceder a policy IAM necessária

Crie uma policy (ou adicione a uma existente) concedendo ao grupo do usuário da API a permissão para inspecionar relatórios de uso, como mostrado acima.

#### 3. Importar o template

**Data collection → Templates → Import**, selecione `template.json`.

#### 4. Aplicar ao host e configurar as macros

No host que já executa o `Oracle Cloud by HTTP`:

- **Data collection → Hosts → [host] → Templates** → adicione `Oracle Cloud Billing Monthly by HTTP`.
- Aba **Macros** → defina `{$OCI.API.TENANCY}`, `{$OCI.API.USER}`, `{$OCI.API.PRIVATE.KEY}`, `{$OCI.API.FINGERPRINT}`, `{$OCI.HTTP.RETURN.CODE.OK}` (`200`) caso ainda não estejam herdadas do template irmão.
- Opcionalmente, sobrescreva `{$OCI.API.USAGE.HOST}` se a home region do seu tenancy for diferente de `sa-saopaulo-1`, e `{$OCI.BILLING.WARN.COST}` se quiser um limiar de alerta diferente.

#### 5. Verificar a coleta

Aguarde o primeiro ciclo de coleta (até 6h), depois verifique em **Monitoring → Hosts → [host] → Latest data**.

---

<a id="en-us"></a>
## 🇺🇸 English

**Category:** Cloud / Cost
**Collection method:** SCRIPT (OCI Usage Reports API, RSA-SHA256 HTTP Signature)
**Items:** 2
**Triggers:** 1
**Zabbix version:** 7.4+

### Description

Monitors the current month's Oracle Cloud Infrastructure (OCI) billing cost via the OCI Usage Reports API. For **Always Free** tenants the cost should always be `0.00`, so this template alerts as soon as any unexpected charge shows up on the account.

It is a companion to the official `Oracle Cloud by HTTP` templates and is meant to be applied to the same host, reusing the same OCI API authentication macros.

### How it works

1. A `SCRIPT`-type item (`oci.billing.monthly.get`) signs and sends a request to the OCI Usage Reports API using RSA-SHA256 HTTP Signature authentication.
2. It computes `startTime` = first day of the current month and `endTime` = first day of the next month (UTC), then queries `POST /20200107/usage` with `granularity: MONTHLY` and `queryType: COST`.
3. The `computedAmount` field of every item in the response is summed to obtain the total monthly cost.
4. A dependent item (`oci.billing.monthly.cost`) extracts the `cost` field from the raw JSON via JSONPath preprocessing.
5. A trigger fires with `HIGH` severity if the accumulated cost exceeds the configured threshold — on an Always Free account, any nonzero charge is worth investigating immediately.

### Items

| Item key | Name | Type | Interval | Value type |
|---|---|---|---|---|
| `oci.billing.monthly.get` | OCI: Get monthly billing data | SCRIPT | 6h | TEXT (raw JSON) |
| `oci.billing.monthly.cost` | OCI: Monthly cost (billing) | DEPENDENT | — | FLOAT |

The raw item returns JSON in the form `{"cost": <total_cost>, "currency": "BRL"}`; the dependent item extracts `cost` via `$.cost` JSONPath preprocessing, discarding unchanged values after a 12h heartbeat.

### Triggers

| Name | Severity | Condition |
|---|---|---|
| Unexpected charges detected in the monthly bill | HIGH | `last(/.../oci.billing.monthly.cost) > {$OCI.BILLING.WARN.COST}` |

<a id="macros-en-us"></a>
### Macros

| Macro | Default | Description |
|---|---|---|
| `{$OCI.API.USAGE.HOST}` | `usageapi.sa-saopaulo-1.oci.oraclecloud.com` | OCI Usage Reports API hostname. Override with your tenancy's home region if it differs. |
| `{$OCI.BILLING.WARN.COST}` | `1` | Monthly cost (in local currency) above which the HIGH trigger fires. Default assumes an Always Free account, where any charge above a negligible rounding threshold is unexpected. |
| `{$OCI.API.TENANCY}` | *(none)* | Tenancy OCID. **Must be set per host — no default, for security.** Shared with the `Oracle Cloud by HTTP` template. |
| `{$OCI.API.USER}` | *(none)* | API user OCID. **Must be set per host — no default, for security.** |
| `{$OCI.API.PRIVATE.KEY}` | *(none)* | PEM content of the API signing private key. **Must be set per host — no default, for security.** |
| `{$OCI.API.FINGERPRINT}` | *(none)* | Fingerprint of the API signing key. **Must be set per host — no default, for security.** |
| `{$OCI.HTTP.RETURN.CODE.OK}` | *(none, expects `200`)* | Expected HTTP status code for a successful API call. Shared with the `Oracle Cloud by HTTP` template. |
| `{$OCI.HTTP.PROXY}` | *(none)* | Proxy URL for the HTTP request. Leave empty if no proxy is used. |

The four authentication macros (`TENANCY`, `USER`, `PRIVATE.KEY`, `FINGERPRINT`) intentionally ship with **no default value** — they hold sensitive credentials and are expected to be defined at the host level only, never in the template itself.

### Requirements

- Zabbix Server 7.4+, with the JavaScript preprocessing/scripting engine enabled (built in).
- The host must already have the OCI API authentication macros configured (see [Macros](#macros-en-us)) — typically shared with the `Oracle Cloud by HTTP` template applied to the same host.
- The OCI API user needs the `inspect usage-reports` IAM policy on the tenancy:
  ```
  Allow group <group-name> to inspect usage-reports in tenancy
  ```
  Without this policy the Usage API call returns a 404 or an authorization error.

### Setup

#### 1. Generate an OCI API signing key

In the OCI Console: **Profile → User Settings → API Keys → Add API Key**. Generate or upload an RSA key pair. OCI will show you the **fingerprint** and a **configuration file preview** containing your **tenancy OCID** and **user OCID** — save these, you'll need them for the host macros.

#### 2. Grant the required IAM policy

Create a policy (or add to an existing one) granting the API user's group permission to inspect usage reports, as shown above.

#### 3. Import the template

**Data collection → Templates → Import**, select `template.json`.

#### 4. Apply to the host and configure macros

On the host that already runs `Oracle Cloud by HTTP`:

- **Data collection → Hosts → [host] → Templates** → add `Oracle Cloud Billing Monthly by HTTP`.
- **Macros** tab → set `{$OCI.API.TENANCY}`, `{$OCI.API.USER}`, `{$OCI.API.PRIVATE.KEY}`, `{$OCI.API.FINGERPRINT}`, `{$OCI.HTTP.RETURN.CODE.OK}` (`200`) if not already inherited from the sibling template.
- Optionally override `{$OCI.API.USAGE.HOST}` if your tenancy's home region differs from `sa-saopaulo-1`, and `{$OCI.BILLING.WARN.COST}` if you want a different alert threshold.

#### 5. Verify collection

Wait for the first collection cycle (up to 6h), then check **Monitoring → Hosts → [host] → Latest data**.

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

# NFe SEFAZ Monitor

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_passive_+_Python-339933?style=flat-square)
![LLD](https://img.shields.io/badge/LLD-per_authorizer-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

Zabbix template for monitoring the **public availability of Brazil's NF-e (electronic invoice) system**, operated by SEFAZ — scrapes the official status page `https://www.nfe.fazenda.gov.br/portal/disponibilidade.aspx` via Python, with proactive alerting when an authorizer becomes unstable or unavailable.

**Zabbix version:** 7.4
**Collection type:** Zabbix Agent 2 (**passive** interface) + Python script (`requests` + `BeautifulSoup`)

---

## What Is Monitored

| Category | Qty | Description |
|---|---|---|
| Master item | 1 | Raw JSON with the status of all authorizers (1 scrape every 5m) |
| LLD — authorizers | dynamic | Discovery dependent on the master item, filtered by `{$NFE.UF.MATCHES}` |
| Items per authorizer | 8/authorizer | 7 services (traffic-light 0/1/2/-1) + 1 text (average response time) |
| Triggers | 1 + 2/service | `nodata` on the master item + unavailable/unstable per discovered service |

Unlike other active-agent templates in this collection, this one runs on a **single HTTP scrape** every 5 minutes — every authorizer and service is derived from that same JSON via **dependent items** (JSONPath), with no extra calls to SEFAZ.

---

## Collection Architecture

```
Zabbix Server → Agent 2, passive (<agent-container-ip>:10050) → UserParameter → nfe_status.py
                                                                        ↓
                                          www.nfe.fazenda.gov.br (HTTPS scraping)

Passive master item nfe.status.json (5m, 1 scrape)
      ├── Dependent LLD nfe.autorizador.discovery (filtered by {$NFE.UF.MATCHES})
      └── 8 dependent items per discovered authorizer (JSONPath/JS, no extra scrape)
```

**Why a dedicated ("virtual") host instead of adding items to an infra host:** Zabbix permissions are granted per host group, not per item. Keeping the master item alone on its own host lets you scope read-only access to just this availability data — without exposing infrastructure items — to anyone who needs it. Dependent items require the master item to live on the same host, so the whole tree (master + LLD + dependents) lives on this dedicated host.

**Why a passive interface instead of an active agent:** active items are tied to a fixed `Hostname` on the agent side. If your Zabbix Agent 2 container/host already serves other active-mode templates under a different hostname, adding a new active host for this template would mean reconfiguring the whole agent. A passive interface avoids that: any host whose interface points at the agent's `<IP>:10050` will respond to `nfe.status.json`.

---

## Macros

| Macro | Default | Description |
|---|---|---|
| `{$NFE.UF.MATCHES}` | `^(SP\|SVC-AN)$` | Regex of which authorizers to discover. `SVC-AN` is the contingency authorizer that backs up SP. To add a state: e.g. `^(SP\|RJ\|SVC-AN)$`. For all authorizers: `^.*$` |

---

## Items per Authorizer (LLD)

Base key: `nfe.<service>[{#AUTORIZADOR}]`

| Service | Type | Trigger |
|---|---|---|
| `autorizacao` (authorization) | FLOAT (traffic-light) | ✅ |
| `retorno_autorizacao` (authorization return) | FLOAT (traffic-light) | ✅ |
| `inutilizacao` (voiding) | FLOAT (traffic-light) | ✅ |
| `consulta_protocolo` (protocol lookup) | FLOAT (traffic-light) | ✅ |
| `status_servico` (service status) | FLOAT (traffic-light) | ✅ |
| `consulta_cadastro` (registration lookup) | FLOAT (traffic-light) | ✅ |
| `recepcao_evento` (event reception) | FLOAT (traffic-light) | ✅ |
| `tempo_medio` (average time) | CHAR (text — "-" or a value) | — (no trigger, it's text) |

---

## Value Map — Traffic Light

| Value | Text |
|---|---|
| `1` | Available (green) |
| `2` | Unstable (yellow) |
| `0` | Unavailable (red) |
| `-1` | N/A (service not offered by this authorizer — no trigger) |

---

## Triggers

### Master item

| Name | Severity | Condition |
|---|---|---|
| NFe: SEFAZ page scrape has had no data for 30 minutes | WARNING | `nodata(nfe.status.json,30m)=1` |

Covers collection failure — the script exits with `exit 1` on error (network issue, page layout changed, certificate problem) and the item goes NOTSUPPORTED; without this trigger, a broken scrape would fail silently.

### Per discovered authorizer (14 trigger prototypes — 7 services × 2 severities)

| Condition | Severity |
|---|---|
| `last(nfe.<service>[{#AUTORIZADOR}])=0` (red) | HIGH |
| `last(nfe.<service>[{#AUTORIZADOR}])=2` (yellow) | WARNING |

`tempo_medio` never fires a trigger (it's text). `-1` (N/A) also never fires — it's the expected state for services an authorizer simply doesn't offer.

---

## Files

| File | Destination | Description |
|---|---|---|
| `template.json` | Import into Zabbix | Full template (items, LLD, triggers, macro, value map) |
| `nfe.conf` | `/etc/zabbix/zabbix_agent2.d/` on the agent container/host | 2 fixed-key UserParameters (no `[*]`, no `UnsafeUserParameters`) |
| `nfe_status.py` | e.g. `/zbx_scripts/` on the agent container/host | Python scraper — `--json` (master item) and `--discovery` (manual test) |
| `Dockerfile` | reference | Snippet of the custom Zabbix Agent 2 Dockerfile used in production — **not standalone**, see note below |
| `isrg-root-yr.crt` | reference | Let's Encrypt "Gen Y" TLS root, installed in the custom image's trust store |

> **About the Dockerfile:** unlike the other templates in this collection (which run on existing Windows/Linux hosts), this one requires a **custom Zabbix Agent 2 image** with Python + libraries + the `ISRG Root YR` CA. The file here is a reference copy of the actual Dockerfile used in a separate infrastructure-as-code project — its `COPY` instruction assumes that project's build context, not this folder's. To reproduce it elsewhere, adjust the `COPY` path or copy both files (`Dockerfile` + `isrg-root-yr.crt`) into your own build context.

---

## Installation

### 1. Build the custom Zabbix Agent 2 image

The container needs Python 3 + `requests` + `beautifulsoup4` + the Gen Y TLS root (see Gotchas below). Build an image on top of `zabbix/zabbix-agent2:alpine-7.4-latest` using the provided `Dockerfile` as a reference.

### 2. Copy the script and the UserParameter to the agent container/host

```bash
# Script
cp nfe_status.py <destination>/zbx_scripts/nfe_status.py

# UserParameter
cp nfe.conf <destination>/etc/zabbix/zabbix_agent2.d/nfe.conf
```

`UnsafeUserParameters` is **not** required here — both keys (`nfe.status.json`, `nfe.status.discovery`) are fixed, with no `[*]`.

### 3. Restart the agent

```bash
# In a container:
docker compose restart zabbix-agent2
# Or on a bare host:
systemctl restart zabbix-agent2
```

### 4. Import the template

1. **Data collection → Templates → Import**
2. Select `template.json`
3. Check: **Create new** + **Update existing**
4. Click **Import**

### 5. Create the dedicated host

Don't apply this template to an existing infrastructure host — create a **dedicated host** (see Architecture above):

1. **Data collection → Hosts → Create host**
2. Name: e.g. `NFe SEFAZ - Availability`
3. Host group: a dedicated group (e.g. `NFe SEFAZ`) — don't reuse an infrastructure group; this separation is what lets you grant read-only access to just this data
4. Interface: **Agent**, IP/port of the container running `nfe_status.py` (e.g. `<agent-container-ip>:10050`)
5. Template: **Template Zabbix NFe Monitor**
6. Adjust `{$NFE.UF.MATCHES}` if you need to monitor states other than SP/SVC-AN

### 6. Verify collection

```bash
# Directly on the agent container/host
zabbix_agent2 -t nfe.status.json
python3 /zbx_scripts/nfe_status.py --json

# From the Zabbix server (passive item — any host pointed at that interface responds)
zabbix_get -s <AGENT-IP> -k nfe.status.json

# Force an immediate collection without waiting for the 5m interval
# (passive items accept task.create type=6, unlike active-item LLD):
# 1. item.get hostids=[<hostid>] filter key_=nfe.status.json → get the itemid
# 2. task.create {"type": 6, "request": {"itemid": "<id>"}}
```

---

## Parser Gotchas (found empirically)

1. **The red ball image is `bola_vermelho_P.png`** (masculine form in Portuguese) — the script matches on the prefix `vermelh`, not `vermelha`. Green/yellow follow the regular feminine form (`verde`, `amarela`).
2. **The "Average Time" column is text** (`"-"` or a value), not an image — handled separately in the parser, with no traffic-light logic.
3. **TLS Gen Y:** SEFAZ uses Let's Encrypt's **Gen Y** hierarchy (root `ISRG Root YR`), which is absent from default trust stores (as of mid-2026) and isn't cross-signed in the served chain. The root must be installed in the image (see `isrg-root-yr.crt`) for the script to run with `verify=True`. If collection breaks with a certificate error, check whether SEFAZ rotated its CA.
4. **`pip3 install` fails on Alpine ≥ 3.19** (PEP 668, "externally-managed-environment") — the image uses `apk add py3-requests py3-beautifulsoup4` instead of pip.
5. **If the SEFAZ page layout changes:** adjust `nfe_status.py`'s `scrape_nfe()` function — the parser depends on the `tabelaListagemDados` CSS class and the fixed column order (`SERVICOS` at the top of the script).

---

## Export Gotcha — `configuration.export` drops this template's triggers

When exporting this template via the API (`configuration.export`, JSON format), the 14 `trigger_prototypes` on the LLD rule and the native `nodata` trigger **do not appear** in the result, even though they demonstrably belong to the template (verified via `template.get` with `selectTriggers`/`selectDiscoveries` and `triggerprototype.get`, all matching the template's internal ID). The root cause wasn't identified (it isn't a permissions issue — tested with a Super Admin account); it may be a Zabbix 7.4 quirk specific to `DEPENDENT`-type discovery rules.

**Practical effect:** a raw re-export via `configuration.export` produces an incomplete JSON with no alerting. `template.json` in this directory was **reconstructed manually** — the triggers/trigger prototypes were fetched via `trigger.get`/`triggerprototype.get` (with `expandExpression`) and inserted into the JSON in the format Zabbix expects for import.

**When re-syncing this template in the future:** always check whether `.triggers` (top-level) and `.discovery_rules[].trigger_prototypes` are present in a fresh export before overwriting this file — if they come back empty/missing again, repeat the manual reconstruction rather than assuming the triggers were removed on the server.

---

## Maintenance

```bash
# Change monitored states: edit the {$NFE.UF.MATCHES} macro on the template (or override per host)
# If the SEFAZ page layout changes: adjust nfe_status.py (the 'tabelaListagemDados' table)

# Grant read access to a new Zabbix user group
# usergroup.update usrgrpid=<id> hostgroup_rights=[..., {"id": "<nfe-hostgroup-id>", "permission": 2}]

# Rebuild the custom agent image after a Dockerfile/script change
docker compose up -d --build zabbix-agent2
```

---

## Changelog

| Version | Changes |
|---|---|
| 1.0 | Initial release: master item + dependent LLD per authorizer (8 items/authorizer), 1 nodata trigger + 14 trigger prototypes (HIGH/WARNING), `{$NFE.UF.MATCHES}` macro, traffic-light value map |

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

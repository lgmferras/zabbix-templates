# NFe SEFAZ Monitor

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.1-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_passive_+_Python-339933?style=flat-square)
![LLD](https://img.shields.io/badge/LLD-per_authorizer-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

Template Zabbix para monitorar a **disponibilidade pública do sistema de NF-e (nota fiscal eletrônica) do Brasil**, operado pela SEFAZ — faz scraping da página oficial de status `https://www.nfe.fazenda.gov.br/portal/disponibilidade.aspx` via Python, com alerta proativo quando um autorizador fica instável ou indisponível.

**Versão do Zabbix:** 7.4
**Tipo de coleta:** Zabbix Agent 2 (interface **passiva**) + script Python (`requests` + `BeautifulSoup`)

---

## O Que É Monitorado

| Categoria | Qtd | Descrição |
|---|---|---|
| Item mestre | 1 | JSON bruto com o status de todos os autorizadores (1 scrape a cada 5m) |
| LLD — autorizadores | dinâmico | Descoberta dependente do item mestre, filtrada por `{$NFE.UF.MATCHES}` |
| Itens por autorizador | 8/autorizador | 7 serviços (semáforo 0/1/2/-1) + 1 texto (tempo médio de resposta) |
| Triggers | 1 + 2/serviço | `nodata` no item mestre + indisponível/instável por serviço descoberto |

Diferente de outros templates de agente ativo desta coleção, este roda com um **único scrape HTTP** a cada 5 minutos — todos os autorizadores e serviços são derivados desse mesmo JSON via **itens dependentes** (JSONPath), sem chamadas extras à SEFAZ.

---

## Arquitetura de Coleta

```
Zabbix Server → Agent 2, passivo (<agent-container-ip>:10050) → UserParameter → nfe_status.py
                                                                        ↓
                                          www.nfe.fazenda.gov.br (scraping HTTPS)

Item mestre passivo nfe.status.json (5m, 1 scrape)
      ├── LLD dependente nfe.autorizador.discovery (filtrado por {$NFE.UF.MATCHES})
      └── 8 itens dependentes por autorizador descoberto (JSONPath/JS, sem scrape extra)
```

**Por que um host dedicado ("virtual") em vez de adicionar itens a um host de infraestrutura:** as permissões do Zabbix são concedidas por host group, não por item. Manter o item mestre sozinho em seu próprio host permite restringir o acesso somente-leitura a esse dado de disponibilidade — sem expor itens de infraestrutura — para quem precisar dele. Itens dependentes exigem que o item mestre esteja no mesmo host, então a árvore inteira (mestre + LLD + dependentes) vive nesse host dedicado.

**Por que uma interface passiva em vez de um agente ativo:** itens ativos ficam amarrados a um `Hostname` fixo do lado do agente. Se o seu container/host do Zabbix Agent 2 já atende outros templates em modo ativo sob um hostname diferente, adicionar um novo host ativo para este template significaria reconfigurar o agente inteiro. Uma interface passiva evita isso: qualquer host cuja interface aponte para `<IP>:10050` do agente responderá a `nfe.status.json`.

---

## Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$NFE.UF.MATCHES}` | `^(SP\|SVC-AN)$` | Regex dos autorizadores a descobrir. `SVC-AN` é o autorizador de contingência que serve como backup de SP. Para adicionar um estado: ex. `^(SP\|RJ\|SVC-AN)$`. Para todos os autorizadores: `^.*$` |
| `{$NFE.CONTINGENCIA.MATCHES}` | `^SVC-` | Regex dos autorizadores de contingência. Os alertas deles são rebaixados para WARNING/INFO |
| `{$NFE.FAIL.COUNT}` | `2` | Definida no template, mas nenhum trigger a usa hoje |

---

## Itens por Autorizador (LLD)

Chave base: `nfe.<serviço>[{#AUTORIZADOR}]`. Cada serviço corresponde a um web service da NF-e; a função de cada um também está no campo de descrição do item.

| Serviço | Web service | O que faz | Se ficar indisponível |
|---|---|---|---|
| `autorizacao` | NFeAutorizacao | Recebe as NF-e transmitidas e concede a autorização de uso. É o serviço que efetivamente emite a nota | Nenhuma nota é autorizada: a empresa não emite nem fatura. Emitir em contingência |
| `retorno_autorizacao` | NFeRetAutorizacao | Devolve o resultado das NF-e enviadas em lote no modo assíncrono | Quem emite em lote assíncrono não sabe se as notas foram autorizadas. O modo síncrono não é afetado |
| `recepcao_evento` | NFeRecepcaoEvento | Registra eventos de notas já emitidas: cancelamento, carta de correção, manifestação do destinatário | Não dá para cancelar nota nem enviar carta de correção. O cancelamento tem prazo legal curto |
| `consulta_protocolo` | NFeConsultaProtocolo | Consulta a situação de uma NF-e pela chave de acesso | Não dá para confirmar a situação de uma nota. A emissão continua |
| `status_servico` | NFeStatusServico | Informa se o autorizador está em operação; os emissores consultam antes de transmitir | Sistemas que checam o status podem recusar a emissão ou entrar em contingência sozinhos |
| `inutilizacao` | NFeInutilizacao | Inutiliza faixas de numeração puladas | Não dá para inutilizar numeração. Não afeta a emissão; o prazo é mensal |
| `consulta_cadastro` | NfeConsultaCadastro | Consulta o cadastro de contribuintes do ICMS do estado | Não dá para validar dados cadastrais de clientes e fornecedores. Não afeta a emissão |
| `tempo_medio` | — | Tempo médio de resposta informado na página (texto; "-" quando não informado) | Sem trigger |

Os sete primeiros são FLOAT com o value map de semáforo. Nem todo autorizador oferece todos os serviços: as contingências (`SVC-AN`, `SVC-RS`) não têm Consulta Cadastro, por exemplo. Nesses casos o item fica em `-1` (N/D).

---

## Value Map — Semáforo

| Valor | Texto |
|---|---|
| `1` | Disponível (verde) |
| `2` | Instável (amarelo) |
| `0` | Indisponível (vermelho) |
| `-1` | N/D (serviço não oferecido por este autorizador — sem trigger) |

---

## Triggers

### Item mestre

| Nome | Severidade | Condição |
|---|---|---|
| NFe: coleta da página da SEFAZ sem dados há 30 minutos | WARNING | `nodata(nfe.status.json,30m)=1` |

Cobre falha de coleta — o script sai com `exit 1` em caso de erro (problema de rede, mudança no layout da página, problema de certificado) e o item vira NOTSUPPORTED; sem esse trigger, um scrape quebrado passaria despercebido.

### Por autorizador descoberto (14 trigger prototypes — 7 serviços × 2 estados)

A severidade segue o impacto de cada serviço para quem emite nota. Semáforo amarelo (instável) fica um nível abaixo do vermelho (indisponível).

| Serviço | Indisponível (`=0`) | Instável (`=2`) | Motivo |
|---|---|---|---|
| Autorização | HIGH | WARNING | Para a emissão de notas |
| Retorno Autorização | AVERAGE | WARNING | Trava a emissão em lote assíncrono |
| Recepção Evento | AVERAGE | WARNING | Impede cancelamento e carta de correção |
| Consulta Protocolo | WARNING | INFO | Só consulta; a emissão continua |
| Status Serviço | WARNING | INFO | Não emite nada, mas alguns emissores dependem dele |
| Inutilização | WARNING | INFO | Sem urgência; prazo mensal |
| Consulta Cadastro | WARNING | INFO | Só consulta cadastral |

**Contingência**: nos autorizadores que casam com `{$NFE.CONTINGENCIA.MATCHES}` (padrão `^SVC-`), um override da LLD rebaixa tudo para WARNING (indisponível) e INFO (instável). A contingência só importa quando o autorizador normal do estado também está fora, e nesse caso o alerta HIGH do autorizador normal já estará aberto.

Limitação: não existe um alerta único para "autorizador normal **e** contingência fora ao mesmo tempo", que seria o pior caso. Cada autorizador é uma entidade separada da LLD.

`tempo_medio` não gera trigger (é texto). `-1` (N/D) também não dispara nada — é o estado esperado para serviços que o autorizador não oferece.

Cada trigger traz na descrição o que o serviço faz, o impacto e o que fazer.

---

## Arquivos

| Arquivo | Destino | Descrição |
|---|---|---|
| `template.json` | Importar no Zabbix | Template completo (itens, LLD, triggers, macro, value map) |
| `nfe.conf` | `/etc/zabbix/zabbix_agent2.d/` no container/host do agente | 2 UserParameters de chave fixa (sem `[*]`, sem `UnsafeUserParameters`) |
| `nfe_status.py` | ex. `/zbx_scripts/` no container/host do agente | Scraper Python — `--json` (item mestre) e `--discovery` (teste manual) |
| `Dockerfile` | referência | Trecho do Dockerfile customizado do Zabbix Agent 2 usado em produção — **não é standalone**, ver nota abaixo |
| `isrg-root-yr.crt` | referência | Raiz TLS "Gen Y" da Let's Encrypt, instalada no trust store da imagem customizada |

> **Sobre o Dockerfile:** diferente dos demais templates desta coleção (que rodam em hosts Windows/Linux já existentes), este exige uma **imagem customizada do Zabbix Agent 2** com Python + bibliotecas + a CA `ISRG Root YR`. O arquivo aqui é uma cópia de referência do Dockerfile real usado em um projeto separado de infraestrutura como código — a instrução `COPY` nele assume o build context daquele projeto, não desta pasta. Para reproduzir em outro ambiente, ajuste o path do `COPY` ou copie os dois arquivos (`Dockerfile` + `isrg-root-yr.crt`) para dentro do seu próprio build context.

---

## Instalação

### 1. Build da imagem customizada do Zabbix Agent 2

O container precisa de Python 3 + `requests` + `beautifulsoup4` + a raiz TLS Gen Y (ver Gotchas abaixo). Construa uma imagem em cima de `zabbix/zabbix-agent2:alpine-7.4-latest` usando o `Dockerfile` fornecido como referência.

### 2. Copiar o script e o UserParameter para o container/host do agente

```bash
# Script
cp nfe_status.py <destino>/zbx_scripts/nfe_status.py

# UserParameter
cp nfe.conf <destino>/etc/zabbix/zabbix_agent2.d/nfe.conf
```

`UnsafeUserParameters` **não** é necessário aqui — as duas chaves (`nfe.status.json`, `nfe.status.discovery`) são fixas, sem `[*]`.

### 3. Reiniciar o agente

```bash
# Em um container:
docker compose restart zabbix-agent2
# Ou em um host sem container:
systemctl restart zabbix-agent2
```

### 4. Importar o template

1. **Data collection → Templates → Import**
2. Selecionar `template.json`
3. Marcar: **Create new** + **Update existing**
4. Clicar em **Import**

### 5. Criar o host dedicado

Não aplique este template a um host de infraestrutura existente — crie um **host dedicado** (ver Arquitetura acima):

1. **Data collection → Hosts → Create host**
2. Nome: ex. `NFe SEFAZ - Disponibilidade`
3. Host group: um grupo dedicado (ex. `NFe SEFAZ`) — não reaproveite um grupo de infraestrutura; é essa separação que permite conceder acesso somente-leitura só a esse dado
4. Interface: **Agent**, IP/porta do container que roda o `nfe_status.py` (ex. `<agent-container-ip>:10050`)
5. Template: **Template Zabbix NFe Monitor**
6. Ajustar `{$NFE.UF.MATCHES}` se precisar monitorar estados além de SP/SVC-AN

### 6. Verificar a coleta

```bash
# Diretamente no container/host do agente
zabbix_agent2 -t nfe.status.json
python3 /zbx_scripts/nfe_status.py --json

# A partir do servidor Zabbix (item passivo — qualquer host apontado para essa interface responde)
zabbix_get -s <AGENT-IP> -k nfe.status.json

# Forçar uma coleta imediata sem esperar o intervalo de 5m
# (itens passivos aceitam task.create type=6, ao contrário de LLD de item ativo):
# 1. item.get hostids=[<hostid>] filter key_=nfe.status.json → pegar o itemid
# 2. task.create {"type": 6, "request": {"itemid": "<id>"}}
```

---

## Gotchas do Parser (descobertos empiricamente)

1. **A imagem da bola vermelha é `bola_vermelho_P.png`** (forma masculina em português) — o script casa pelo prefixo `vermelh`, não `vermelha`. Verde/amarela seguem a forma feminina normal (`verde`, `amarela`).
2. **A coluna "Tempo Médio" é texto** (`"-"` ou um valor), não imagem — tratada separadamente no parser, sem lógica de semáforo.
3. **TLS Gen Y:** a SEFAZ usa a hierarquia **Gen Y** da Let's Encrypt (raiz `ISRG Root YR`), ausente dos trust stores padrão (em meados de 2026) e sem cross-sign na cadeia servida. A raiz precisa estar instalada na imagem (ver `isrg-root-yr.crt`) para o script rodar com `verify=True`. Se a coleta quebrar com erro de certificado, verifique se a SEFAZ rotacionou sua CA.
4. **`pip3 install` falha no Alpine ≥ 3.19** (PEP 668, "externally-managed-environment") — a imagem usa `apk add py3-requests py3-beautifulsoup4` em vez de pip.
5. **Se o layout da página da SEFAZ mudar:** ajuste a função `scrape_nfe()` do `nfe_status.py` — o parser depende da classe CSS `tabelaListagemDados` e da ordem fixa das colunas (`SERVICOS` no topo do script).

---

## Export do template

O arquivo deste diretório é o `configuration.export` do template em produção, sem edição manual. Os triggers ficam **aninhados**: o `nodata` dentro do item mestre (`items[].triggers`) e os 14 protótipos dentro de cada protótipo de item (`discovery_rules[].item_prototypes[].trigger_prototypes`). Não aparecem em `.triggers` no topo nem em `discovery_rules[].trigger_prototypes`, porque cada um referencia um único item.

Até a versão 1.0 este README dizia que o export "omitia" os triggers; eles estavam lá, só que aninhados. O arquivo antigo tinha sido reconstruído à mão e trazia cada trigger duas vezes.

---

## Manutenção

```bash
# Mudar os estados monitorados: editar a macro {$NFE.UF.MATCHES} no template (ou override por host)
# Se o layout da página da SEFAZ mudar: ajustar nfe_status.py (a tabela 'tabelaListagemDados')

# Conceder acesso de leitura a um novo grupo de usuários Zabbix
# usergroup.update usrgrpid=<id> hostgroup_rights=[..., {"id": "<nfe-hostgroup-id>", "permission": 2}]

# Rebuild da imagem customizada do agente após uma mudança no Dockerfile/script
docker compose up -d --build zabbix-agent2
```

---

## Fontes

- [Portal da NF-e — Disponibilidade](https://www.nfe.fazenda.gov.br/portal/disponibilidade.aspx): a página monitorada.
- [SEFAZ-SP — URL dos web services](https://portal.fazenda.sp.gov.br/servicos/nfe/Paginas/URL-WEBSERVICES.aspx) e [SEFAZ-PE — web services 4.00](https://www.sefaz.pe.gov.br/Servicos/nota-fiscal-eletronica/Paginas/url-web-services-prod-homolog.aspx): nomes oficiais dos web services.

A função de cada web service segue o Manual de Orientação do Contribuinte da NF-e. O manual não pôde ser consultado diretamente na revisão de out/2026; as páginas acima confirmam apenas os nomes dos serviços.

---

## Changelog

| Versão | Mudanças |
|---|---|
| 1.1 | Severidade por impacto do serviço (Autorização HIGH; Retorno Autorização e Recepção Evento AVERAGE; demais WARNING; instável um nível abaixo), override que rebaixa os alertas da contingência, descrição da função em todos os itens e triggers, macro `{$NFE.CONTINGENCIA.MATCHES}`. Arquivo passa a ser o export direto do Zabbix |
| 1.0 | Versão inicial: item mestre + LLD dependente por autorizador (8 itens/autorizador), 1 trigger nodata + 14 trigger prototypes (HIGH/WARNING), macro `{$NFE.UF.MATCHES}`, value map de semáforo |

---

<a id="en-us"></a>
## 🇺🇸 English

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
| `{$NFE.CONTINGENCIA.MATCHES}` | `^SVC-` | Regex of contingency authorizers. Their alerts are lowered to WARNING/INFO |
| `{$NFE.FAIL.COUNT}` | `2` | Defined on the template, but no trigger uses it today |

---

## Items per Authorizer (LLD)

Base key: `nfe.<service>[{#AUTORIZADOR}]`. Each service maps to an NF-e web service; the same explanation is in each item's description field (in Portuguese).

| Service | Web service | What it does | If unavailable |
|---|---|---|---|
| `autorizacao` | NFeAutorizacao | Receives transmitted invoices and grants authorization. This is the service that actually issues the invoice | No invoice is authorized: the company cannot issue or bill. Issue in contingency mode |
| `retorno_autorizacao` | NFeRetAutorizacao | Returns the result for invoices sent as an asynchronous batch | Asynchronous batch senders cannot tell whether invoices were authorized. Synchronous mode is unaffected |
| `recepcao_evento` | NFeRecepcaoEvento | Registers events on issued invoices: cancellation, correction letter, recipient acknowledgement | Invoices cannot be cancelled or corrected. Cancellation has a short legal deadline |
| `consulta_protocolo` | NFeConsultaProtocolo | Looks up an invoice's status by access key | An invoice's status cannot be confirmed. Issuing continues |
| `status_servico` | NFeStatusServico | Reports whether the authorizer is operating; issuing software checks it before transmitting | Software that checks status may refuse to issue or switch to contingency on its own |
| `inutilizacao` | NFeInutilizacao | Voids skipped number ranges | Number ranges cannot be voided. Issuing is unaffected; the deadline is monthly |
| `consulta_cadastro` | NfeConsultaCadastro | Looks up the state ICMS taxpayer registry | Customer and supplier registry data cannot be validated. Issuing is unaffected |
| `tempo_medio` | — | Average response time shown on the page (text; "-" when not reported) | No trigger |

The first seven are FLOAT with the traffic-light value map. Not every authorizer offers every service: the contingency ones (`SVC-AN`, `SVC-RS`) have no Consulta Cadastro, for example. Those items stay at `-1` (N/A).

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

### Per discovered authorizer (14 trigger prototypes — 7 services × 2 states)

Severity follows each service's impact on whoever issues invoices. Yellow (unstable) sits one level below red (unavailable).

| Service | Unavailable (`=0`) | Unstable (`=2`) | Why |
|---|---|---|---|
| Autorização | HIGH | WARNING | Stops invoice issuing |
| Retorno Autorização | AVERAGE | WARNING | Blocks asynchronous batch issuing |
| Recepção Evento | AVERAGE | WARNING | Blocks cancellation and correction letters |
| Consulta Protocolo | WARNING | INFO | Lookup only; issuing continues |
| Status Serviço | WARNING | INFO | Issues nothing, but some software depends on it |
| Inutilização | WARNING | INFO | Not urgent; monthly deadline |
| Consulta Cadastro | WARNING | INFO | Registry lookup only |

**Contingency**: for authorizers matching `{$NFE.CONTINGENCIA.MATCHES}` (default `^SVC-`), an LLD override lowers everything to WARNING (unavailable) and INFO (unstable). Contingency only matters when the state's regular authorizer is also down, and in that case the regular authorizer's HIGH alert is already open.

Limitation: there is no single alert for "regular authorizer **and** contingency down at the same time", which would be the worst case. Each authorizer is a separate LLD entity.

`tempo_medio` never fires a trigger (it's text). `-1` (N/A) also never fires — it's the expected state for services an authorizer doesn't offer.

Each trigger's description states what the service does, the impact and what to do.

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

## Template Export

The file in this directory is the raw `configuration.export` of the production template. Triggers are **nested**: the `nodata` one inside the master item (`items[].triggers`) and the 14 prototypes inside each item prototype (`discovery_rules[].item_prototypes[].trigger_prototypes`). They do not appear under top-level `.triggers` or `discovery_rules[].trigger_prototypes`, because each references a single item.

Up to version 1.0 this README said the export "dropped" the triggers; they were there, just nested. The old file had been rebuilt by hand and carried each trigger twice.

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

## Sources

- [NF-e Portal — Availability](https://www.nfe.fazenda.gov.br/portal/disponibilidade.aspx): the monitored page.
- [SEFAZ-SP — web service URLs](https://portal.fazenda.sp.gov.br/servicos/nfe/Paginas/URL-WEBSERVICES.aspx) and [SEFAZ-PE — web services 4.00](https://www.sefaz.pe.gov.br/Servicos/nota-fiscal-eletronica/Paginas/url-web-services-prod-homolog.aspx): official web service names.

Each web service's function follows the NF-e taxpayer manual (Manual de Orientação do Contribuinte). The manual could not be consulted directly in the Oct 2026 review; the pages above confirm the service names only.

---

## Changelog

| Version | Changes |
|---|---|
| 1.1 | Severity by service impact (Autorização HIGH; Retorno Autorização and Recepção Evento AVERAGE; others WARNING; unstable one level lower), override lowering contingency alerts, function description on every item and trigger, `{$NFE.CONTINGENCIA.MATCHES}` macro. File is now the raw Zabbix export |
| 1.0 | Initial release: master item + dependent LLD per authorizer (8 items/authorizer), 1 nodata trigger + 14 trigger prototypes (HIGH/WARNING), `{$NFE.UF.MATCHES}` macro, traffic-light value map |

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

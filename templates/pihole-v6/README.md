# Pi-hole v6 by HTTP

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-SCRIPT_(REST_API_v6)-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

Template Zabbix para **Pi-hole v6** (core 6.x / FTL 6.x) pela API REST nova. Não funciona com Pi-hole v5 (`api.php`).

**Coleta:** um item mestre do tipo Script, a cada 2 min, que abre uma sessão na API com a senha de aplicativo, lê `/stats/summary`, `/dns/blocking`, `/info/version`, `/info/messages`, `/info/ftl` e `/stats/upstreams` e encerra a sessão; 20 itens dependentes; e checagem simples da porta TCP 53. Roda no server ou num proxy — o proxy precisa alcançar a interface web do Pi-hole.

### Pré-requisitos

1. No Pi-hole: **Settings → Web interface / API → Configure app password** (modo Expert). Copie a senha mostrada — ela não aparece de novo.
2. No Zabbix: host com interface (qualquer tipo) no IP do Pi-hole, template vinculado e a macro `{$PIHOLE.PASSWORD}` como **texto secreto** no host.

### Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$PIHOLE.PASSWORD}` | — | Senha de aplicativo (secreta) |
| `{$PIHOLE.SCHEME}` | `http` | `http` ou `https` |
| `{$PIHOLE.PORT}` | `20720` | Porta da interface web (no container oficial, `80`) |
| `{$PIHOLE.GRAVITY.MAXAGE}` | `8d` | Idade máxima da lista de bloqueio (gravity) |
| `{$PIHOLE.GRAVITY.MIN}` | `1000` | Mínimo de domínios na lista de bloqueio |
| `{$PIHOLE.UPSTREAM.RESPONSE.MAX}` | `0.5` | Tempo médio aceitável dos servidores de saída (s) |

### Triggers

| Trigger | Severidade |
|---|---|
| DNS não responde na porta 53 (3 checagens) | Alta |
| API sem dados há 10 minutos | Média |
| Bloqueio desativado | Média |
| Lista de bloqueio desatualizada / com poucos domínios | Aviso |
| Avisos de diagnóstico do Pi-hole | Aviso |
| Servidores de saída lentos (média de 15 min) | Aviso |
| Atualização disponível / FTL reiniciado | Informação |

**Dica para pares sincronizados** (nebula-sync, Orbital Sync): no secundário, baixe `{$PIHOLE.GRAVITY.MAXAGE}` para pouco mais que o intervalo da sincronização — a lista velha passa a indicar sincronização parada.

---

<a id="en-us"></a>
## 🇺🇸 English

Zabbix template for **Pi-hole v6** (core 6.x / FTL 6.x) through the new REST API. Does not work with Pi-hole v5 (`api.php`).

**Collection:** one Script master item every 2 min that opens an API session with an app password, reads `/stats/summary`, `/dns/blocking`, `/info/version`, `/info/messages`, `/info/ftl` and `/stats/upstreams`, then logs out; 20 dependent items; and a simple check on TCP port 53. Runs on the server or a proxy — it must reach the Pi-hole web interface.

### Requirements

1. In Pi-hole: **Settings → Web interface / API → Configure app password** (Expert mode). Copy the password — it is shown only once.
2. In Zabbix: a host with an interface (any type) on the Pi-hole IP, the template linked, and `{$PIHOLE.PASSWORD}` as a **secret text** macro on the host.

### Macros

| Macro | Default | Description |
|---|---|---|
| `{$PIHOLE.PASSWORD}` | — | App password (secret) |
| `{$PIHOLE.SCHEME}` | `http` | `http` or `https` |
| `{$PIHOLE.PORT}` | `20720` | Web interface port (`80` in the official container) |
| `{$PIHOLE.GRAVITY.MAXAGE}` | `8d` | Maximum blocklist (gravity) age |
| `{$PIHOLE.GRAVITY.MIN}` | `1000` | Minimum domains on the blocklist |
| `{$PIHOLE.UPSTREAM.RESPONSE.MAX}` | `0.5` | Acceptable average upstream response time (s) |

### Triggers

| Trigger | Severity |
|---|---|
| DNS not answering on port 53 (3 checks) | High |
| API without data for 10 minutes | Average |
| Blocking disabled | Average |
| Blocklist outdated / with too few domains | Warning |
| Pi-hole diagnosis messages | Warning |
| Slow upstream servers (15 min average) | Warning |
| Update available / FTL restarted | Information |

**Tip for synced pairs** (nebula-sync, Orbital Sync): on the secondary, lower `{$PIHOLE.GRAVITY.MAXAGE}` to slightly more than the sync interval — an old blocklist then means the sync stopped.

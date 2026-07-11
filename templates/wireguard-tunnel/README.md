# WireGuard Tunnel by Zabbix agent

![Zabbix](https://img.shields.io/badge/Zabbix-7.4+-D40000?style=flat-square&logoColor=white)
![Collection method](https://img.shields.io/badge/Collection_method-Zabbix_Agent_active-7F13EC?style=flat-square)
![WireGuard](https://img.shields.io/badge/WireGuard-VPN-88171A?style=flat-square&logo=wireguard&logoColor=white)
![OS](https://img.shields.io/badge/Linux_%7C_Windows-333333?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

| | |
|---|---|
| **Categoria** | Rede / VPN |
| **Método de coleta** | Zabbix Agent (ativo) |
| **Itens** | 7 |
| **Versão do Zabbix** | 7.4+ |

## Descrição

Template Zabbix para monitoramento de um túnel VPN WireGuard via agente Zabbix ativo. **Funciona em Linux e Windows Server** — um único template JSON, combinado com dois arquivos de UserParameters separados (um para cada SO).

Cobre estado da interface, contagem de peers configurados/online, atualidade do handshake, throughput de RX/TX e latência ICMP até um peer de referência.

## Requisitos

- Zabbix Server 7.4+
- Zabbix Agent 2 (ativo) configurado no host monitorado
- Linux: pacote `wireguard-tools` (comando `wg`) e acesso sudo para o usuário `zabbix`
- Windows: WireGuard for Windows instalado (`wg.exe`)

## Arquivos

| Arquivo | Descrição |
|---|---|
| `template.json` | Template para importar no Zabbix |
| `user_parameters_wireguard_linux.conf` | UserParameters para hosts Linux |
| `user_parameters_wireguard_windows.conf` | UserParameters para hosts Windows Server |

## Itens

| Item key | Nome | Tipo | Intervalo | Unidade | Preprocessing |
|---|---|---|---|---|---|
| `wireguard.interface.up[{$WG.INTERFACE}]` | Interface ativa | UINT64 | 1m | — | DISCARD 6h |
| `wireguard.peers.total[{$WG.INTERFACE}]` | Peers configurados | UINT64 | 10m | — | DISCARD 1h |
| `wireguard.peers.online[{$WG.INTERFACE},{$WG.HANDSHAKE.MAX_AGE}]` | Peers online | UINT64 | 1m | — | — |
| `wireguard.handshake.age[{$WG.INTERFACE}]` | Idade do último handshake | UINT64 | 1m | s | — |
| `wireguard.transfer.rx[{$WG.INTERFACE}]` | Tráfego RX | FLOAT | 5m | Bps | CHANGE_PER_SECOND |
| `wireguard.transfer.tx[{$WG.INTERFACE}]` | Tráfego TX | FLOAT | 5m | Bps | CHANGE_PER_SECOND |
| `wireguard.latency[{$WG.PEER.IP}]` | Latência ICMP até o peer | FLOAT | 5m | ms | — |

> **`peers.online`** recebe o limiar de handshake como segundo parâmetro (`$2`) para que o UserParameter
> use o mesmo valor da macro — evita fixar `300` diretamente no script.

> **`transfer.rx/tx`** armazenam os contadores cumulativos brutos de `wg show transfer`. O Zabbix calcula a
> taxa (Bps) via `CHANGE_PER_SECOND`. Os contadores são zerados sempre que o WireGuard é reiniciado.

## Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$WG.HANDSHAKE.MAX_AGE}` | `300` | Idade máxima do handshake em segundos antes de alertar (o WireGuard renegocia a cada ~3 min) |
| `{$WG.INTERFACE}` | `wg0` | Nome da interface WireGuard no host |
| `{$WG.LATENCY.WARN}` | `50` | Limiar de latência (ms) para o trigger WARNING |
| `{$WG.PEER.IP}` | `10.0.0.1` | IP do peer usado para medir a latência ICMP |
| `{$WG.PEERS.MIN}` | `1` | Número mínimo de peers online esperado |

## Triggers

| Nome | Severidade | Condição | Dependência |
|---|---|---|---|
| Interface {$WG.INTERFACE} DOWN | DISASTER | `interface.up = 0` | — |
| Menos de {$WG.PEERS.MIN} peer(s) online | HIGH | `peers.online < {$WG.PEERS.MIN}` | Interface DOWN |
| Handshake desatualizado (> {$WG.HANDSHAKE.MAX_AGE}s) | WARNING | `handshake.age > MAX_AGE` | Interface DOWN |
| Latência alta (> {$WG.LATENCY.WARN}ms) | WARNING | `latency > LATENCY.WARN` | — |
| Peer {$WG.PEER.IP} sem resposta a ICMP | HIGH | `latency = -1` | Interface DOWN |

## Exemplo de configuração por host

O template é genérico — todo valor específico do host (nome da interface, IP do peer de referência,
número mínimo de peers) é controlado por macros sobrescritas no nível do host. Abaixo, uma configuração
ilustrativa cobrindo os três cenários para os quais este template foi projetado:

| Papel do host | SO | Interface (`{$WG.INTERFACE}`) | IP do peer (`{$WG.PEER.IP}`) | Peers mínimos (`{$WG.PEERS.MIN}`) | UserParameters |
|---|---|---|---|---|---|
| Gateway Linux com múltiplos peers | Linux | `wg0` | *(desabilitar o item de latência¹)* | `3` | `_linux.conf` |
| Gateway Linux com um único peer | Linux | `systrix_wg0` | `10.0.0.1` | `1` | `_linux.conf` |
| Gateway Windows com um único peer | Windows | *(nome da interface WireGuard)* | `10.0.0.1` | `1` | `_windows.conf` |

> ¹ Em um gateway com múltiplos peers, o item `wireguard.latency` mede apenas um peer via
> `{$WG.PEER.IP}`. Para monitorar a latência de cada peer individualmente, adicione itens ICMP simples
> (`icmpping`, `icmppingsec`) diretamente no host para cada IP de peer, por exemplo `10.0.0.2`, `10.0.0.4`, `10.0.0.5`.

## Instalação — Linux

### 1. Dependências

```bash
# wireguard-tools (fornece o comando 'wg')
sudo apt install wireguard-tools iputils-ping
```

### 2. Permissão sudo para o Zabbix agent

`wg show` requer root. Adicione ao `/etc/sudoers.d/zabbix-wireguard`:

```bash
echo 'zabbix ALL=(ALL) NOPASSWD: /usr/bin/wg show *' | sudo tee /etc/sudoers.d/zabbix-wireguard
sudo chmod 440 /etc/sudoers.d/zabbix-wireguard
```

### 3. Instalar os UserParameters

```bash
sudo cp user_parameters_wireguard_linux.conf /etc/zabbix/zabbix_agent2.d/
sudo systemctl restart zabbix-agent2
```

### 4. Testar

```bash
# Substitua wg0 pelo nome real da interface
zabbix_agent2 -t 'wireguard.interface.up[wg0]'
zabbix_agent2 -t 'wireguard.peers.total[wg0]'
zabbix_agent2 -t 'wireguard.peers.online[wg0,300]'
zabbix_agent2 -t 'wireguard.handshake.age[wg0]'
zabbix_agent2 -t 'wireguard.transfer.rx[wg0]'
zabbix_agent2 -t 'wireguard.latency[10.0.0.1]'
```

## Instalação — Windows Server

### 1. Dependências

O WireGuard for Windows deve estar instalado. O `wg.exe` fica em `C:\Program Files\WireGuard\`.

### 2. Permissão do serviço Zabbix Agent

O serviço Zabbix Agent 2 deve rodar como **LocalSystem** (padrão) ou com uma conta que tenha permissão
para executar `wg.exe`. Ajuste via `services.msc` se necessário.

### 3. Instalar os UserParameters

```powershell
Copy-Item user_parameters_wireguard_windows.conf "C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\"
Restart-Service "Zabbix Agent 2"
```

### 4. Testar

```powershell
# Substitua pelo nome real da interface WireGuard no Windows
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -t "wireguard.interface.up[wg0]"
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -t "wireguard.peers.online[wg0,300]"
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -t "wireguard.latency[10.0.0.1]"
```

## Excluindo `wg0` da descoberta de rede de outros templates

Templates como **Linux by Zabbix agent** descobrem interfaces de rede automaticamente. A interface
WireGuard (`wg0`, `systrix_wg0`) seria descoberta e geraria itens/gráficos redundantes.

**Solução:** sobrescreva a macro `{$NET.IF.IFNAME.NOT_MATCHES}` **no nível do host** (não no template),
acrescentando `|wg` ao valor existente.

O padrão `wg` sem âncora `^` cobre tanto `wg0` quanto variantes sem o prefixo `wg`, como `systrix_wg0`,
já que a correspondência não é ancorada ao início da string.

Exemplo de valor para definir na macro do host:

```
(^Software Loopback Interface\|^NULL[0-9.]*$\|^[Ll]o[0-9.]*$\|^[Ss]ystem$\|^Nu[0-9.]*$\|^veth[0-9A-z]+$\|docker[0-9]+\|br-[a-z0-9]{12}\|wg)
```

Caminho no Zabbix: **Configuration → Hosts → [host] → Macros → Add macro**.

> Não é necessário modificar o template — sobrescrever a macro no nível do host é a abordagem correta
> do Zabbix para personalização por host; a macro do host tem precedência sobre o padrão do template.

## Nota sobre `$N` em UserParameters e awk

O Zabbix substitui `$1`–`$9` no comando do UserParameter **antes** de repassá-lo ao shell. Isso significa
que referências a campos do awk como `$2`, `$3` seriam substituídas incorretamente.

Para evitar isso, os scripts Linux deste template usam:
- `$NF` (último campo) em vez de `$2` ou `$3` no awk
- `$(NF-1)` (penúltimo campo) para bytes de RX
- `split($0, a, "/")` em vez de `$5` ao analisar a saída do ping

Os scripts do Windows não têm esse problema, pois usam PowerShell com variáveis nomeadas (`$wg`,
`$now`, etc.) — o Zabbix só substitui `$1`–`$9`, não `$wg`.

---

<a id="en-us"></a>
## 🇺🇸 English

| | |
|---|---|
| **Category** | Network / VPN |
| **Collection method** | Zabbix Agent (active) |
| **Items** | 7 |
| **Zabbix version** | 7.4+ |

## Description

Zabbix template for monitoring a WireGuard VPN tunnel via active Zabbix agent. **Works on both Linux and Windows Server** — a single template JSON, paired with two separate UserParameter files (one per OS).

Covers interface state, configured/online peer counts, handshake freshness, RX/TX throughput and ICMP latency to a reference peer.

## Requirements

- Zabbix Server 7.4+
- Zabbix Agent 2 (active) configured on the monitored host
- Linux: `wireguard-tools` package (`wg` command) and sudo access for the `zabbix` user
- Windows: WireGuard for Windows installed (`wg.exe`)

## Files

| File | Description |
|---|---|
| `template.json` | Template to import into Zabbix |
| `user_parameters_wireguard_linux.conf` | UserParameters for Linux hosts |
| `user_parameters_wireguard_windows.conf` | UserParameters for Windows Server hosts |

## Items

| Item key | Name | Type | Interval | Unit | Preprocessing |
|---|---|---|---|---|---|
| `wireguard.interface.up[{$WG.INTERFACE}]` | Interface up | UINT64 | 1m | — | DISCARD 6h |
| `wireguard.peers.total[{$WG.INTERFACE}]` | Configured peers | UINT64 | 10m | — | DISCARD 1h |
| `wireguard.peers.online[{$WG.INTERFACE},{$WG.HANDSHAKE.MAX_AGE}]` | Online peers | UINT64 | 1m | — | — |
| `wireguard.handshake.age[{$WG.INTERFACE}]` | Latest handshake age | UINT64 | 1m | s | — |
| `wireguard.transfer.rx[{$WG.INTERFACE}]` | RX traffic | FLOAT | 5m | Bps | CHANGE_PER_SECOND |
| `wireguard.transfer.tx[{$WG.INTERFACE}]` | TX traffic | FLOAT | 5m | Bps | CHANGE_PER_SECOND |
| `wireguard.latency[{$WG.PEER.IP}]` | ICMP latency to peer | FLOAT | 5m | ms | — |

> **`peers.online`** receives the handshake threshold as its second parameter (`$2`) so the UserParameter
> uses the same value as the macro — this avoids hardcoding `300` in the script.

> **`transfer.rx/tx`** store the raw cumulative counters from `wg show transfer`. Zabbix computes the
> rate (Bps) via `CHANGE_PER_SECOND`. The counters reset whenever WireGuard is restarted.

## Macros

| Macro | Default | Description |
|---|---|---|
| `{$WG.HANDSHAKE.MAX_AGE}` | `300` | Maximum handshake age in seconds before alerting (WireGuard renegotiates roughly every ~3 min) |
| `{$WG.INTERFACE}` | `wg0` | Name of the WireGuard interface on the host |
| `{$WG.LATENCY.WARN}` | `50` | Latency (ms) threshold for the WARNING trigger |
| `{$WG.PEER.IP}` | `10.0.0.1` | Peer IP used to measure ICMP latency |
| `{$WG.PEERS.MIN}` | `1` | Minimum number of expected online peers |

## Triggers

| Name | Severity | Condition | Dependency |
|---|---|---|---|
| Interface {$WG.INTERFACE} DOWN | DISASTER | `interface.up = 0` | — |
| Fewer than {$WG.PEERS.MIN} peer(s) online | HIGH | `peers.online < {$WG.PEERS.MIN}` | Interface DOWN |
| Stale handshake (> {$WG.HANDSHAKE.MAX_AGE}s) | WARNING | `handshake.age > MAX_AGE` | Interface DOWN |
| High latency (> {$WG.LATENCY.WARN}ms) | WARNING | `latency > LATENCY.WARN` | — |
| Peer {$WG.PEER.IP} not responding to ICMP | HIGH | `latency = -1` | Interface DOWN |

## Per-host configuration example

The template is generic — every host-specific value (interface name, reference peer IP, minimum peer
count) is driven by macros overridden at the host level. Below is an illustrative setup covering the
three scenarios this template is designed for:

| Host role | OS | Interface (`{$WG.INTERFACE}`) | Peer IP (`{$WG.PEER.IP}`) | Peers Min (`{$WG.PEERS.MIN}`) | UserParameters |
|---|---|---|---|---|---|
| Linux gateway with multiple peers | Linux | `wg0` | *(disable the latency item¹)* | `3` | `_linux.conf` |
| Linux gateway with a single peer | Linux | `systrix_wg0` | `10.0.0.1` | `1` | `_linux.conf` |
| Windows gateway with a single peer | Windows | *(name of the WireGuard interface)* | `10.0.0.1` | `1` | `_windows.conf` |

> ¹ On a gateway with multiple peers, the `wireguard.latency` item only measures one peer via
> `{$WG.PEER.IP}`. To monitor latency to every peer individually, add plain ICMP items
> (`icmpping`, `icmppingsec`) directly on the host for each peer IP, e.g. `10.0.0.2`, `10.0.0.4`, `10.0.0.5`.

## Installation — Linux

### 1. Dependencies

```bash
# wireguard-tools (provides the 'wg' command)
sudo apt install wireguard-tools iputils-ping
```

### 2. Sudo permission for the Zabbix agent

`wg show` requires root. Add to `/etc/sudoers.d/zabbix-wireguard`:

```bash
echo 'zabbix ALL=(ALL) NOPASSWD: /usr/bin/wg show *' | sudo tee /etc/sudoers.d/zabbix-wireguard
sudo chmod 440 /etc/sudoers.d/zabbix-wireguard
```

### 3. Install the UserParameters

```bash
sudo cp user_parameters_wireguard_linux.conf /etc/zabbix/zabbix_agent2.d/
sudo systemctl restart zabbix-agent2
```

### 4. Test

```bash
# Replace wg0 with the real interface name
zabbix_agent2 -t 'wireguard.interface.up[wg0]'
zabbix_agent2 -t 'wireguard.peers.total[wg0]'
zabbix_agent2 -t 'wireguard.peers.online[wg0,300]'
zabbix_agent2 -t 'wireguard.handshake.age[wg0]'
zabbix_agent2 -t 'wireguard.transfer.rx[wg0]'
zabbix_agent2 -t 'wireguard.latency[10.0.0.1]'
```

## Installation — Windows Server

### 1. Dependencies

WireGuard for Windows must be installed. `wg.exe` is located at `C:\Program Files\WireGuard\`.

### 2. Zabbix Agent service permission

The Zabbix Agent 2 service must run as **LocalSystem** (default) or an account with permission to
execute `wg.exe`. Adjust via `services.msc` if needed.

### 3. Install the UserParameters

```powershell
Copy-Item user_parameters_wireguard_windows.conf "C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\"
Restart-Service "Zabbix Agent 2"
```

### 4. Test

```powershell
# Replace with the real WireGuard interface name on Windows
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -t "wireguard.interface.up[wg0]"
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -t "wireguard.peers.online[wg0,300]"
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -t "wireguard.latency[10.0.0.1]"
```

## Excluding `wg0` from other templates' network discovery

Templates such as **Linux by Zabbix agent** auto-discover network interfaces. The WireGuard interface
(`wg0`, `systrix_wg0`) would get discovered and generate redundant items/graphs.

**Solution:** override the `{$NET.IF.IFNAME.NOT_MATCHES}` macro **at the host level** (not on the
template), appending `|wg` to the existing value.

The `wg` pattern without a `^` anchor covers both `wg0` and non-`wg`-prefixed variants like
`systrix_wg0`, since the match isn't anchored to the start of the string.

Example value to set on the host macro:

```
(^Software Loopback Interface\|^NULL[0-9.]*$\|^[Ll]o[0-9.]*$\|^[Ss]ystem$\|^Nu[0-9.]*$\|^veth[0-9A-z]+$\|docker[0-9]+\|br-[a-z0-9]{12}\|wg)
```

Path in Zabbix: **Configuration → Hosts → [host] → Macros → Add macro**.

> There's no need to modify the template — overriding the macro at the host level is the correct
> Zabbix approach for per-host customization; the host macro takes precedence over the template default.

## Note on `$N` in UserParameters and awk

Zabbix substitutes `$1`–`$9` in the UserParameter command **before** passing it to the shell. This
means references to awk fields like `$2`, `$3` would be incorrectly substituted.

To avoid this, the Linux scripts in this template use:
- `$NF` (last field) instead of `$2` or `$3` in awk
- `$(NF-1)` (second-to-last field) for RX bytes
- `split($0, a, "/")` instead of `$5` when parsing ping output

The Windows scripts don't have this problem since they use PowerShell with named variables (`$wg`,
`$now`, etc.) — Zabbix only substitutes `$1`–`$9`, not `$wg`.

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

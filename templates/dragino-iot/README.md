# Dragino IOT

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-SSH-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![LoRaWAN](https://img.shields.io/badge/LoRaWAN-FF6B00?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

Template Zabbix para monitoramento de **gateways LoRaWAN Dragino** via SSH.

**Versão do Zabbix:** 7.4
**Tipo de coleta:** SSH (itens mestres) + DEPENDENT (itens derivados)
**Grupo do template:** Templates/IOT
**Autor:** Luis Gustavo Ferras — Systrix

---

### Descrição

O template se conecta ao gateway Dragino via SSH (`ssh.run[...]`) e executa um pequeno conjunto de comandos shell (`logread`, `cat /proc/...`, `df`, `free`, `uci show`, `cat /etc/lora/local_conf.json`). Um pequeno grupo de **itens mestres** captura a saída bruta, e um conjunto maior de **itens dependentes** parseia essa saída com pré-processamento JSONPATH, JavaScript e REGEX para extrair métricas individuais — qualidade do pacote RX, configuração do gateway/beacon, CPU/memória/carga, uso de sistema de arquivos e contadores de interface de rede.

| Categoria | Itens | Notas |
|---|---|---|
| Configuração do gateway e LoRa | 24 | Beacon (largura de banda, taxa de dados, frequência, período, potência), encaminhamento de CRC, LBT, watchdog, ghost stream, ID/descrição/plataforma/região do gateway, configurações do network server (endereço, keep-alive, nome, portas, timeouts, tipo) |
| Métricas de pacotes RX | 7 | Contagem de pacotes, taxa de dados, frequência, SNR, RSSI, tamanho, status |
| Posição e hardware | 4 | Latitude, longitude, altitude, plataforma do concentrador |
| CPU e load average | 7 | Utilização de CPU, tempo ocioso de CPU, número de CPUs, load average (1m/5m/15m), contagem de processos |
| Sistema / diversos | 16 | Utilização de memória, uptime, hostname, modelo, descoberta de disco e interface, parsing de log (erros/avisos/LoRaWAN), dump de configuração bruta |
| **Total** | **58** | |

As regras de descoberta adicionam itens por interface e por sistema de arquivos além destes (veja abaixo).

> **Otimização de conexões SSH (2026-08):** o gateway Dragino roda em hardware bem limitado (Atheros AR9330, 1 núcleo MIPS ~400MHz, 60MB RAM). Cada handshake SSH via dropbear custa 1.5-3s de CPU nesse hardware, e o template original abria uma conexão independente por item — cerca de 160-200 conexões/hora, incluindo um item (`System Load Average`) que ficou sem `delay` explícito e por isso herdava o intervalo padrão de 1 minuto. Consolidei os 6 itens que liam `logread` de forma redundante (`Lora Last Error`, `Logread Errors`, `Logread LoRaWAN`, `Logread Warnings`, `Lora Errors Count`, `LoRa RX`) em um único item mestre `Logread Snapshot` — os 6 viraram itens `DEPENDENT` que extraem sua seção via REGEX a partir dessa captura única — e corrigi o `delay` do `System Load Average` para `5m`. Resultado medido em produção: **~204 → ~107 conexões SSH/hora (-48%)**, sem alterar nenhum dado coletado.
>
> **v2.0 (2026-08):** três ajustes adicionais, focados em reduzir tanto conexões quanto tempo de CPU por conexão:
> - `CPU Idle Time` fazia `(grep /proc/stat; sleep 1; grep /proc/stat)` dentro da própria sessão SSH — segurava um dos 3 slots concorrentes do dropbear (`-T 3`) por 1s+ extra a cada ciclo só para tirar uma amostra instantânea. Agora faz uma única leitura de `/proc/stat` e o percentual de CPU busy é calculado no lado do Zabbix via preprocessing `CHANGE_PER_SECOND` (delta entre ciclos de coleta) — sem segurar a conexão, ao custo de o valor passar a representar a média do intervalo de 5 minutos em vez de uma amostra instantânea de 1 segundo (mudança de semântica esperada e documentada).
> - `JSON Local Conf` (configuração LoRa, que raramente muda em runtime) passou de `10m` para `1h`.
> - `Interface {#IFNAME}: Bits Received` e `Bits Sent` liam `/proc/net/dev` cada um na sua própria conexão SSH; agora derivam via `DEPENDENT` de um único item mestre `Interface {#IFNAME}: Net Stats`.
>
> Comandos validados diretamente no gateway antes do import; após aplicar, os valores em produção foram conferidos via API do Zabbix (histórico de `CPU Idle Time`, `Bits Received/Sent` e `Net Stats`) para confirmar que nenhum item ficou "not supported". Redução adicional estimada: **~85 → ~68 conexões SSH/hora**.

---

### Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$CPU.UTIL.CRIT}` | `90` | Limite crítico de utilização de memória (%) usado pelo trigger *High Memory Utilization* |
| `{$HOST.SSH_PORT}` | `2222` | Porta SSH do gateway Dragino |
| `{$LOAD_AVG_PER_CPU.MAX.WARN}` | `2` | Load average máximo por CPU (reservado para um futuro trigger de carga) |
| `{$USER.NAME}` | *(vazio)* | Usuário SSH usado para conectar ao gateway — definido por host, sem valor padrão de propósito |
| `{$USER.PASSWORD}` | *(vazio)* | Senha SSH usada para conectar ao gateway — definida por host, sem valor padrão de propósito |

---

### Triggers

| Nome | Severidade | Expressão |
|---|---|---|
| High Memory Utilization | Média | `avg(/Dragino IOT/ssh.run[lorawan.memused,...],5m) >= {$CPU.UTIL.CRIT}` |
| {HOST.NAME} has been restarted | Aviso | `last(/Dragino IOT/ssh.run[lorawan.system.uptime,...]) < 10` (uptime abaixo de 10 minutos) |

---

### Itens

#### Itens mestres (SSH)

| Nome | Prefixo da chave | Intervalo | Descrição |
|---|---|---|---|
| CPU Idle Time | `ssh.run[lorawan.cpu.idle.time,...]` | 5m | Percentual de CPU ocupada (busy), média do intervalo de coleta — leitura única de `/proc/stat`, delta calculado no Zabbix via `CHANGE_PER_SECOND` |
| Number of CPUs | `ssh.run[lorawan.cpu.number,...]` | 4h | Quantidade de núcleos de CPU |
| System Disk Discovery | `ssh.run[lorawan.disk.discovery,...]` | 12h | Alimenta a regra de descoberta de sistema de arquivos |
| System name | `ssh.run[lorawan.hostname,...]` | 12h | Hostname do gateway (vinculado ao inventário do host) |
| JSON Local Conf | `ssh.run[lorawan.local_conf,...]` | 1h | Dump bruto de `/etc/lora/local_conf.json`, usado como item mestre para a maioria dos itens de configuração LoRa — configuração estática, não precisa de polling frequente |
| Logread Snapshot | `ssh.run[lorawan.logread.snapshot,...]` | 10m | Captura única de `logread`, dividida em seções marcadas (erros, avisos, status LoRaWAN, pacotes RX); item mestre para `Lora Last Error`, `Logread Errors`, `Logread LoRaWAN`, `Logread Warnings`, `Lora Errors Count` e `LoRa RX`, que agora são `DEPENDENT` — evita 6 conexões SSH redundantes por ciclo |
| Memory utilization | `ssh.run[lorawan.memused,...]` | 5m | Percentual de uso de memória |
| System Net if Discovery | `ssh.run[lorawan.net.if.discovery,...]` | 1h | Alimenta a regra de descoberta de interfaces de rede |
| System Load Average | `ssh.run[lorawan.system.loadavg,...]` | 5m | Conteúdo bruto de `/proc/loadavg`, usado como item mestre para as métricas de carga |
| System model | `ssh.run[lorawan.system.model,...]` | 12h | Modelo de hardware do gateway |
| System Uptime | `ssh.run[lorawan.system.uptime,...]` | 10m | Uptime em segundos |

Todos os itens SSH se conectam com `HostkeyAlgorithms=ssh-rsa` (exigido pelo servidor SSH dropbear presente na maioria dos firmwares Dragino/OpenWrt) e timeout de 30s.

#### Itens dependentes (derivados)

Os 47 itens restantes são itens `DEPENDENT` que parseiam os itens mestres acima usando pré-processamento REGEX, JSONPATH e JavaScript — nenhuma chamada SSH adicional é feita. Seis deles (`Lora Last Error`, `Logread Errors`, `Logread LoRaWAN`, `Logread Warnings`, `Lora Errors Count`, `LoRa RX`) derivam do `Logread Snapshot` extraindo sua seção por REGEX antes de aplicar o parsing próprio; os demais itens que já dependiam de `Logread LoRaWAN`/`LoRa RX` (ex.: `Lora Gateway Altitude`, `LoRa RX Packet RSSI`) continuam funcionando normalmente, agora numa cadeia de dependência de dois níveis. Outros exemplos: `Lora Beacon Frequency`, `Lora Gateway ID`, `Load average (5m avg)`, `Lora Last Warning`.

---

### Regras de Descoberta

#### Discovery net.if.discovery

Descobre interfaces de rede que correspondem a `^(eth1).*` e cria, para cada interface:

- **Interface {#IFNAME}: Net Stats** — item mestre SSH (`cat /proc/net/dev | grep -w '{#IFNAME}'`), lido uma única vez por ciclo
- **Interface {#IFNAME}: Bits Received / Bits Sent** — itens `DEPENDENT` de Net Stats, extraem o campo correspondente via JavaScript e convertem para bps via `CHANGE_PER_SECOND` + `MULTIPLIER(8)`
- **Interface {#IFNAME}: MAC** — a partir de `/sys/class/net/{#IFNAME}/address`
- **Gráfico:** *Interface {#IFNAME}: Network traffic*

#### Discovery vfs.fs.discovery

Descobre sistemas de arquivos que correspondem a `{#FSNAME}=/overlay` e `{#MOUNTPOINT}=/` e cria, para cada sistema de arquivos:

- **File System: {#MOUNTPOINT} Used in %** — a partir de `df -P`
- **Gráfico:** *FS [{#MOUNTPOINT}]: Space usage graph*

---

### Gráficos

O template inclui três gráficos em nível de host:

- **{HOST.NAME}: Memory utilization**
- **{HOST.NAME}: System load** (load average de 1m/5m/15m mais a contagem de CPUs no eixo direito)
- **{HOST.NAME} CPU utilization**

---

### Arquitetura

```
Zabbix Server
    |
    +-- ssh.run[lorawan.logread.lorawan, {HOST.IP}, {$HOST.SSH_PORT}, , HostkeyAlgorithms=ssh-rsa]
                            (item mestre -- JSON bruto coletado do gateway)
                                |
                    +-----------+-----------+
                    |           |           |
              JSONPATH      JSONPATH    JSONPATH + JS
             altitude      beacon.bw    último elemento do array
                ...            ...            ...
        (itens DEPENDENT -- extraem campos individuais do JSON)
```

---

### Instalação

#### Pré-requisitos no servidor Zabbix

O Zabbix Server (ou proxy) precisa ter o suporte a itens SSH habilitado:

```bash
# Verificar se o suporte a chave SSH está habilitado no Zabbix
grep -i "SSHKeyLocation\|AllowKey" /etc/zabbix/zabbix_server.conf
```

#### Configurar credenciais

No host ou no template, defina as seguintes macros:

- `{$HOST.SSH_PORT}`: porta SSH do gateway Dragino (o padrão neste template é `2222`)
- `{$USER.NAME}`: usuário SSH (geralmente `root`)
- `{$USER.PASSWORD}`: senha SSH do gateway

#### Importar e aplicar

1. **Configuration → Templates → Import** → `template.json`
2. Anexe o template ao host com o IP do gateway
3. Configure as macros de SSH acima

---

### Solução de Problemas

- **Itens ficam "not supported" / "Connection refused"** — verifique se `{$HOST.SSH_PORT}` corresponde à porta em que o dropbear/sshd está realmente escutando, e se o Zabbix server/proxy consegue alcançá-la (firewall, NAT).
- **Erros de "Bad key types" ou de handshake** — o parâmetro `HostkeyAlgorithms=ssh-rsa` é necessário porque a maioria dos firmwares Dragino/OpenWrt só oferece chaves de host `ssh-rsa` legadas; se o cliente SSH do seu Zabbix server tiver o `ssh-rsa` desabilitado, ele precisa ser reabilitado para esse host.
- **Itens dependentes não retornam dados** — seus itens mestres (`lorawan.local_conf`, `lorawan.logread.snapshot`, `lorawan.system.loadavg`) precisam retornar com sucesso primeiro; verifique esses itens individualmente em *Latest data*. `Logread LoRaWAN` e `LoRa RX` agora são eles mesmos itens `DEPENDENT` (derivados de `lorawan.logread.snapshot`), então uma falha no `Logread Snapshot` se propaga para toda a cadeia.
- **Lora Last Error / Logread Errors sempre mostram "OK" ou "No Errors"** — isso é esperado quando o log do gateway não tem linhas correspondentes; não é uma falha de coleta.
- **Posição (lat/long/altitude) ou métricas de RX ausentes** — esses valores são extraídos do *último* frame de status visto na janela de log; se o gateway não enviou um frame `stat`/`rxpk` recentemente, a saída do item mestre pode ficar vazia e os itens dependentes ficarão sem valor até a chegada do próximo frame.
- **Erros de parsing de JSON nos itens de `local_conf`** — as expressões JSONPATH assumem o layout padrão de fábrica do `/etc/lora/local_conf.json`; uma atualização de firmware que altere a estrutura desse arquivo vai quebrar os itens dependentes afetados.

---

<a id="en-us"></a>
## 🇺🇸 English

Zabbix template for monitoring **Dragino LoRaWAN gateways** over SSH.

**Zabbix version:** 7.4
**Collection type:** SSH (master items) + DEPENDENT (derived items)
**Template group:** Templates/IOT
**Author:** Luis Gustavo Ferras — Systrix

---

### Description

The template connects to the Dragino gateway via SSH (`ssh.run[...]`) and runs a small set of shell commands (`logread`, `cat /proc/...`, `df`, `free`, `uci show`, `cat /etc/lora/local_conf.json`). A handful of **master items** capture the raw output, and a larger set of **dependent items** parse that output with JSONPATH, JavaScript and REGEX preprocessing to extract individual metrics — RX packet quality, gateway/beacon configuration, CPU/memory/load, filesystem usage and network interface counters.

| Category | Items | Notes |
|---|---|---|
| Gateway & LoRa configuration | 24 | Beacon (bandwidth, data rate, frequency, period, power), CRC forwarding, LBT, watchdog, ghost stream, gateway ID/description/platform/region, network server settings (address, keep-alive, name, ports, timeouts, type) |
| RX packet metrics | 7 | Packet count, data rate, frequency, SNR, RSSI, size, status |
| Position & hardware | 4 | Latitude, longitude, altitude, concentrator platform |
| CPU & load average | 7 | CPU utilization, CPU idle time, number of CPUs, load average (1m/5m/15m), process count |
| System / misc | 16 | Memory utilization, uptime, hostname, model, disk & interface discovery, log parsing (errors/warnings/LoRaWAN), raw config dump |
| **Total** | **58** | |

Discovery rules add per-interface and per-filesystem items on top of this (see below).

> **SSH connection optimization (2026-08):** the Dragino gateway runs on quite limited hardware (Atheros AR9330, 1 MIPS core ~400MHz, 60MB RAM). Each dropbear SSH handshake costs 1.5-3s of CPU on that hardware, and the original template opened one independent connection per item — roughly 160-200 connections/hour, including one item (`System Load Average`) that shipped without an explicit `delay` and therefore inherited the 1-minute default interval. I consolidated the 6 items that redundantly read `logread` (`Lora Last Error`, `Logread Errors`, `Logread LoRaWAN`, `Logread Warnings`, `Lora Errors Count`, `LoRa RX`) into a single master item `Logread Snapshot` — the 6 became `DEPENDENT` items that extract their section via REGEX from that single capture — and fixed `System Load Average`'s `delay` to `5m`. Measured result in production: **~204 → ~107 SSH connections/hour (-48%)**, with no change to any collected data.
>
> **v2.0 (2026-08):** three further tweaks, aimed at both connection count and per-connection CPU cost:
> - `CPU Idle Time` used to run `(grep /proc/stat; sleep 1; grep /proc/stat)` inside the SSH session itself — holding one of dropbear's 3 concurrent slots (`-T 3`) open for an extra 1s+ per cycle just to take one instant sample. It now does a single `/proc/stat` read, and the busy-CPU percentage is computed Zabbix-side via `CHANGE_PER_SECOND` preprocessing (delta between polling cycles) — no more held-open connection, at the cost of the value now representing a 5-minute interval average instead of an instantaneous 1-second sample (an expected, documented semantic change).
> - `JSON Local Conf` (LoRa configuration, which rarely changes at runtime) went from `10m` to `1h`.
> - `Interface {#IFNAME}: Bits Received` and `Bits Sent` each read `/proc/net/dev` on their own SSH connection; they now derive as `DEPENDENT` items from a single master item `Interface {#IFNAME}: Net Stats`.
>
> Commands validated directly on the gateway before import; after applying, production values were checked via the Zabbix API (history for `CPU Idle Time`, `Bits Received/Sent` and `Net Stats`) to confirm no item went "not supported". Estimated further reduction: **~85 → ~68 SSH connections/hour**.

---

### Macros

| Macro | Default | Description |
|---|---|---|
| `{$CPU.UTIL.CRIT}` | `90` | Critical memory utilization threshold (%) used by the *High Memory Utilization* trigger |
| `{$HOST.SSH_PORT}` | `2222` | SSH port of the Dragino gateway |
| `{$LOAD_AVG_PER_CPU.MAX.WARN}` | `2` | Maximum load average per CPU (reserved for future load trigger) |
| `{$USER.NAME}` | *(empty)* | SSH username used to connect to the gateway — set per host, no default on purpose |
| `{$USER.PASSWORD}` | *(empty)* | SSH password used to connect to the gateway — set per host, no default on purpose |

---

### Triggers

| Name | Severity | Expression |
|---|---|---|
| High Memory Utilization | Average | `avg(/Dragino IOT/ssh.run[lorawan.memused,...],5m) >= {$CPU.UTIL.CRIT}` |
| {HOST.NAME} has been restarted | Warning | `last(/Dragino IOT/ssh.run[lorawan.system.uptime,...]) < 10` (uptime under 10 minutes) |

---

### Items

#### Master items (SSH)

| Name | Key prefix | Interval | Description |
|---|---|---|---|
| CPU Idle Time | `ssh.run[lorawan.cpu.idle.time,...]` | 5m | CPU busy percentage, averaged over the polling interval — single `/proc/stat` read, delta computed Zabbix-side via `CHANGE_PER_SECOND` |
| Number of CPUs | `ssh.run[lorawan.cpu.number,...]` | 4h | CPU core count |
| System Disk Discovery | `ssh.run[lorawan.disk.discovery,...]` | 12h | Feeds the filesystem discovery rule |
| System name | `ssh.run[lorawan.hostname,...]` | 12h | Gateway hostname (linked to host inventory) |
| JSON Local Conf | `ssh.run[lorawan.local_conf,...]` | 1h | Raw dump of `/etc/lora/local_conf.json`, used as master item for most LoRa config items — static configuration, doesn't need frequent polling |
| Logread Snapshot | `ssh.run[lorawan.logread.snapshot,...]` | 10m | Single `logread` capture, split into marked sections (errors, warnings, LoRaWAN status, RX packets); master item for `Lora Last Error`, `Logread Errors`, `Logread LoRaWAN`, `Logread Warnings`, `Lora Errors Count` and `LoRa RX`, which are now `DEPENDENT` — avoids 6 redundant SSH connections per cycle |
| Memory utilization | `ssh.run[lorawan.memused,...]` | 5m | Memory usage percentage |
| System Net if Discovery | `ssh.run[lorawan.net.if.discovery,...]` | 1h | Feeds the network interface discovery rule |
| System Load Average | `ssh.run[lorawan.system.loadavg,...]` | 5m | Raw content of `/proc/loadavg`, used as master item for load metrics |
| System model | `ssh.run[lorawan.system.model,...]` | 12h | Gateway hardware model |
| System Uptime | `ssh.run[lorawan.system.uptime,...]` | 10m | Uptime in seconds |

All SSH items connect with `HostkeyAlgorithms=ssh-rsa` (required by the dropbear SSH server on most Dragino/OpenWrt firmware) and a 30s timeout.

#### Dependent items (derived)

The remaining 47 items are `DEPENDENT` items that parse the master items above using REGEX, JSONPATH and JavaScript preprocessing — no extra SSH calls are made. Six of them (`Lora Last Error`, `Logread Errors`, `Logread LoRaWAN`, `Logread Warnings`, `Lora Errors Count`, `LoRa RX`) derive from `Logread Snapshot`, extracting their section via REGEX before applying their own parsing; the items that already depended on `Logread LoRaWAN`/`LoRa RX` (e.g. `Lora Gateway Altitude`, `LoRa RX Packet RSSI`) keep working unchanged, now through a two-level dependency chain. Other examples: `Lora Beacon Frequency`, `Lora Gateway ID`, `Load average (5m avg)`, `Lora Last Warning`.

---

### Discovery Rules

#### Discovery net.if.discovery

Discovers network interfaces matching `^(eth1).*` and creates, per interface:

- **Interface {#IFNAME}: Net Stats** — SSH master item (`cat /proc/net/dev | grep -w '{#IFNAME}'`), read once per cycle
- **Interface {#IFNAME}: Bits Received / Bits Sent** — `DEPENDENT` items on Net Stats, extract their field via JavaScript and convert to bps via `CHANGE_PER_SECOND` + `MULTIPLIER(8)`
- **Interface {#IFNAME}: MAC** — from `/sys/class/net/{#IFNAME}/address`
- **Graph:** *Interface {#IFNAME}: Network traffic*

#### Discovery vfs.fs.discovery

Discovers filesystems matching `{#FSNAME}=/overlay` and `{#MOUNTPOINT}=/` and creates, per filesystem:

- **File System: {#MOUNTPOINT} Used in %** — from `df -P`
- **Graph:** *FS [{#MOUNTPOINT}]: Space usage graph*

---

### Graphs

Three host-level graphs ship with the template:

- **{HOST.NAME}: Memory utilization**
- **{HOST.NAME}: System load** (1m/5m/15m load average plus CPU count on the right axis)
- **{HOST.NAME} CPU utilization**

---

### Architecture

```
Zabbix Server
    |
    +-- ssh.run[lorawan.logread.lorawan, {HOST.IP}, {$HOST.SSH_PORT}, , HostkeyAlgorithms=ssh-rsa]
                            (master item -- raw JSON collected from the gateway)
                                |
                    +-----------+-----------+
                    |           |           |
              JSONPATH      JSONPATH    JSONPATH + JS
             altitude      beacon.bw    last array element
                ...            ...            ...
        (DEPENDENT items -- extract individual fields from the JSON)
```

---

### Installation

#### Prerequisites on the Zabbix server

The Zabbix Server (or proxy) needs SSH item support enabled:

```bash
# Check whether SSH key support is enabled in Zabbix
grep -i "SSHKeyLocation\|AllowKey" /etc/zabbix/zabbix_server.conf
```

#### Configure credentials

On the host or template, set the following macros:

- `{$HOST.SSH_PORT}`: SSH port of the Dragino gateway (default in this template is `2222`)
- `{$USER.NAME}`: SSH username (commonly `root`)
- `{$USER.PASSWORD}`: SSH password for the gateway

#### Import and apply

1. **Configuration → Templates → Import** → `template.json`
2. Attach the template to the host with the gateway's IP
3. Configure the SSH macros above

---

### Troubleshooting

- **Items stay unsupported / "Connection refused"** — verify `{$HOST.SSH_PORT}` matches the port dropbear/sshd is actually listening on, and that the Zabbix server/proxy can reach it (firewall, NAT).
- **"Bad key types" or handshake errors** — the `HostkeyAlgorithms=ssh-rsa` parameter is required because most Dragino/OpenWrt firmware only offers legacy `ssh-rsa` host keys; if your Zabbix server's SSH client has `ssh-rsa` disabled, it must be re-enabled for this host.
- **Dependent items return no data** — their master items (`lorawan.local_conf`, `lorawan.logread.snapshot`, `lorawan.system.loadavg`) must return successfully first; check those items individually in *Latest data*. `Logread LoRaWAN` and `LoRa RX` are themselves `DEPENDENT` items now (derived from `lorawan.logread.snapshot`), so a failure in `Logread Snapshot` propagates through the whole chain.
- **Lora Last Error / Logread Errors always show "OK" or "No Errors"** — this is expected when the gateway log has no matching lines; it is not a collection failure.
- **Position (lat/long/altitude) or RX metrics missing** — these are parsed from the *last* status frame seen in the log window; if the gateway hasn't sent a `stat`/`rxpk` frame recently, the master item output can be empty and the dependent items will have no value until the next frame arrives.
- **JSON parsing errors on `local_conf` items** — the JSONPATH expressions assume the stock `/etc/lora/local_conf.json` layout; a firmware update that changes this file's structure will break the affected dependent items.

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

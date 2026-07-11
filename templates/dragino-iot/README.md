# Dragino IOT

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-SSH-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![LoRaWAN](https://img.shields.io/badge/LoRaWAN-FF6B00?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

Zabbix template for monitoring **Dragino LoRaWAN gateways** over SSH.

**Zabbix version:** 7.4
**Collection type:** SSH (master items) + DEPENDENT (derived items)
**Template group:** Templates/IOT
**Author:** Luis Gustavo Ferras — Systrix

---

## Description

The template connects to the Dragino gateway via SSH (`ssh.run[...]`) and runs a small set of shell commands (`logread`, `cat /proc/...`, `df`, `free`, `uci show`, `cat /etc/lora/local_conf.json`). A handful of **master items** capture the raw output, and a larger set of **dependent items** parse that output with JSONPATH, JavaScript and REGEX preprocessing to extract individual metrics — RX packet quality, gateway/beacon configuration, CPU/memory/load, filesystem usage and network interface counters.

| Category | Items | Notes |
|---|---|---|
| Gateway & LoRa configuration | 24 | Beacon (bandwidth, data rate, frequency, period, power), CRC forwarding, LBT, watchdog, ghost stream, gateway ID/description/platform/region, network server settings (address, keep-alive, name, ports, timeouts, type) |
| RX packet metrics | 7 | Packet count, data rate, frequency, SNR, RSSI, size, status |
| Position & hardware | 4 | Latitude, longitude, altitude, concentrator platform |
| CPU & load average | 7 | CPU utilization, CPU idle time, number of CPUs, load average (1m/5m/15m), process count |
| System / misc | 15 | Memory utilization, uptime, hostname, model, disk & interface discovery, log parsing (errors/warnings/LoRaWAN), raw config dump |
| **Total** | **57** | |

Discovery rules add per-interface and per-filesystem items on top of this (see below).

---

## Macros

| Macro | Default | Description |
|---|---|---|
| `{$CPU.UTIL.CRIT}` | `90` | Critical memory utilization threshold (%) used by the *High Memory Utilization* trigger |
| `{$HOST.SSH_PORT}` | `2222` | SSH port of the Dragino gateway |
| `{$LOAD_AVG_PER_CPU.MAX.WARN}` | `2` | Maximum load average per CPU (reserved for future load trigger) |
| `{$USER.NAME}` | *(empty)* | SSH username used to connect to the gateway — set per host, no default on purpose |
| `{$USER.PASSWORD}` | *(empty)* | SSH password used to connect to the gateway — set per host, no default on purpose |

---

## Triggers

| Name | Severity | Expression |
|---|---|---|
| High Memory Utilization | Average | `avg(/Dragino IOT/ssh.run[lorawan.memused,...],5m) >= {$CPU.UTIL.CRIT}` |
| {HOST.NAME} has been restarted | Warning | `last(/Dragino IOT/ssh.run[lorawan.system.uptime,...]) < 10` (uptime under 10 minutes) |

---

## Items

### Master items (SSH)

| Name | Key prefix | Interval | Description |
|---|---|---|---|
| CPU Idle Time | `ssh.run[lorawan.cpu.idle.time,...]` | 5m | CPU idle percentage, sampled from `/proc/stat` |
| Number of CPUs | `ssh.run[lorawan.cpu.number,...]` | 4h | CPU core count |
| System Disk Discovery | `ssh.run[lorawan.disk.discovery,...]` | 12h | Feeds the filesystem discovery rule |
| Lora Last Error | `ssh.run[lorawan.error.last,...]` | 10m | Last `error` line from `logread` |
| System name | `ssh.run[lorawan.hostname,...]` | 12h | Gateway hostname (linked to host inventory) |
| JSON Local Conf | `ssh.run[lorawan.local_conf,...]` | 10m | Raw dump of `/etc/lora/local_conf.json`, used as master item for most LoRa config items |
| Logread Errors | `ssh.run[lorawan.logread.errors,...]` | 10m | All `error` lines from the log |
| Logread LoRaWAN | `ssh.run[lorawan.logread.lorawan,...]` | 10m | LoRaWAN status JSON extracted from the log |
| Logread Warnings | `ssh.run[lorawan.logread.warnings,...]` | 10m | All `WARNING` lines from the log |
| Lora Errors Count | `ssh.run[lorawan.logread_error_count,...]` | 30m | Last error line, or `0` if none |
| LoRa RX | `ssh.run[lorawan.lora.rx,...]` | 10m | RX packet JSON extracted from the log, used as master item for RX metrics |
| Memory utilization | `ssh.run[lorawan.memused,...]` | 5m | Memory usage percentage |
| System Net if Discovery | `ssh.run[lorawan.net.if.discovery,...]` | 1h | Feeds the network interface discovery rule |
| System Load Average | `ssh.run[lorawan.system.loadavg,...]` | — | Raw content of `/proc/loadavg`, used as master item for load metrics |
| System model | `ssh.run[lorawan.system.model,...]` | 12h | Gateway hardware model |
| System Uptime | `ssh.run[lorawan.system.uptime,...]` | 10m | Uptime in seconds |

All SSH items connect with `HostkeyAlgorithms=ssh-rsa` (required by the dropbear SSH server on most Dragino/OpenWrt firmware) and a 30s timeout.

### Dependent items (derived)

The remaining 41 items are `DEPENDENT` items that parse the master items above using JSONPATH, JavaScript and REGEX preprocessing — no extra SSH calls are made. Examples: `Lora Beacon Frequency`, `Lora Gateway ID`, `LoRa RX Packet RSSI`, `Load average (5m avg)`, `Lora Last Warning`.

---

## Discovery Rules

### Discovery net.if.discovery

Discovers network interfaces matching `^(eth1).*` and creates, per interface:

- **Interface {#IFNAME}: Bits Received / Bits Sent** — from `/proc/net/dev`, converted to bps via `CHANGE_PER_SECOND` + `MULTIPLIER(8)`
- **Interface {#IFNAME}: MAC** — from `/sys/class/net/{#IFNAME}/address`
- **Graph:** *Interface {#IFNAME}: Network traffic*

### Discovery vfs.fs.discovery

Discovers filesystems matching `{#FSNAME}=/overlay` and `{#MOUNTPOINT}=/` and creates, per filesystem:

- **File System: {#MOUNTPOINT} Used in %** — from `df -P`
- **Graph:** *FS [{#MOUNTPOINT}]: Space usage graph*

---

## Graphs

Three host-level graphs ship with the template:

- **{HOST.NAME}: Memory utilization**
- **{HOST.NAME}: System load** (1m/5m/15m load average plus CPU count on the right axis)
- **{HOST.NAME} CPU utilization**

---

## Architecture

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

## Installation

### Prerequisites on the Zabbix server

The Zabbix Server (or proxy) needs SSH item support enabled:

```bash
# Check whether SSH key support is enabled in Zabbix
grep -i "SSHKeyLocation\|AllowKey" /etc/zabbix/zabbix_server.conf
```

### Configure credentials

On the host or template, set the following macros:

- `{$HOST.SSH_PORT}`: SSH port of the Dragino gateway (default in this template is `2222`)
- `{$USER.NAME}`: SSH username (commonly `root`)
- `{$USER.PASSWORD}`: SSH password for the gateway

### Import and apply

1. **Configuration → Templates → Import** → `template.json`
2. Attach the template to the host with the gateway's IP
3. Configure the SSH macros above

---

## Troubleshooting

- **Items stay unsupported / "Connection refused"** — verify `{$HOST.SSH_PORT}` matches the port dropbear/sshd is actually listening on, and that the Zabbix server/proxy can reach it (firewall, NAT).
- **"Bad key types" or handshake errors** — the `HostkeyAlgorithms=ssh-rsa` parameter is required because most Dragino/OpenWrt firmware only offers legacy `ssh-rsa` host keys; if your Zabbix server's SSH client has `ssh-rsa` disabled, it must be re-enabled for this host.
- **Dependent items return no data** — their master items (`lorawan.local_conf`, `lorawan.lora.rx`, `lorawan.logread.lorawan`, `lorawan.system.loadavg`) must return successfully first; check those items individually in *Latest data*.
- **Lora Last Error / Logread Errors always show "OK" or "No Errors"** — this is expected when the gateway log has no matching lines; it is not a collection failure.
- **Position (lat/long/altitude) or RX metrics missing** — these are parsed from the *last* status frame seen in the log window; if the gateway hasn't sent a `stat`/`rxpk` frame recently, the master item output can be empty and the dependent items will have no value until the next frame arrives.
- **JSON parsing errors on `local_conf` items** — the JSONPATH expressions assume the stock `/etc/lora/local_conf.json` layout; a firmware update that changes this file's structure will break the affected dependent items.

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

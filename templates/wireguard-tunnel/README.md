# WireGuard Tunnel by Zabbix agent

![Zabbix](https://img.shields.io/badge/Zabbix-7.4+-D40000?style=flat-square&logoColor=white)
![Collection method](https://img.shields.io/badge/Collection_method-Zabbix_Agent_active-7F13EC?style=flat-square)
![WireGuard](https://img.shields.io/badge/WireGuard-VPN-88171A?style=flat-square&logo=wireguard&logoColor=white)
![OS](https://img.shields.io/badge/Linux_%7C_Windows-333333?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

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

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

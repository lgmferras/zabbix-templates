# Dual WAN Backup Link

![Zabbix](https://img.shields.io/badge/Zabbix-7.4%2B-D40000?style=flat-square&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-Simple_Checks-7F13EC?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

| | |
|---|---|
| **Category** | Network / Availability |
| **Collection method** | Simple checks (server-side, no Zabbix Agent required) |
| **Items** | 4 |
| **Zabbix version** | 7.4+ |

## Description

Monitors the availability and quality of the backup WAN link via ICMP and TCP/HTTPS service checks.

Apply this template to a host named `<site> - WAN2`, configured with the firewall's public backup IP. No Zabbix Agent is required — all checks are simple checks executed directly by the Zabbix server, so monitoring keeps working even if the primary link (and its agent connectivity) is down.

Designed to run alongside the [Dual WAN Primary Link](../dual-wan-primary/) and [Sophos Firewall](../sophos-firewall/) templates as part of a 3-host dual-WAN monitoring architecture: WAN1, WAN2 and the firewall itself (via SNMP) are monitored independently, so visibility is preserved even during a primary-link failure.

## Why a separate host for the backup link

During a WAN1 outage, SNMP polling and any check that depends on the primary public IP become unreachable. Because the WAN1 and WAN2 hosts use simple checks against independent public IPs, they keep reporting through the outage. The firewall host (SNMP) loses connectivity temporarily, but once it reconnects it records that the backup gateway was active during the incident.

## Items

| Key | Name | Interval | History | Unit |
|---|---|---|---|---|
| `icmpping` | WAN: ICMP ping | 3m | 7d | Up/Down |
| `icmppingloss` | WAN: ICMP packet loss | 3m | 30d | % |
| `icmppingsec` | WAN: ICMP latency (RTT) | 3m | 30d | ms |
| `net.tcp.service[tcp,,{$WAN.HTTP.PORT}]` | WAN: TCP service on port `{$WAN.HTTP.PORT}` | 5m | 7d | Up/Down |

`icmpping` and the TCP service check use `DISCARD_UNCHANGED_HEARTBEAT` (1h) to avoid storing repeated unchanged values.

### Web scenario — HTTPS:{$WAN.HTTP.PORT}

In addition to the simple checks above, the template includes a **web scenario** that performs a real HTTP(S) request against the firewall's management interface — catching cases where the TCP port is open but the HTTP service itself is hung or erroring.

| Parameter | Value |
|---|---|
| Name | `HTTPS:{$WAN.HTTP.PORT}` |
| Interval | 5m |
| Attempts | 3 |
| Step URL | `https://{HOST.CONN}:{$WAN.HTTP.PORT}/` |
| Step timeout | 60s |
| Accepted status codes | `200, 301, 302, 401, 403` |
| SSL verification | Disabled (self-signed certificates) |

`401` and `403` are accepted because most firewall management UIs (including Sophos) return one of these when hit unauthenticated at `/` — that's expected behavior and proves the service is up. Rejecting those codes would produce false positives.

Zabbix automatically creates `web.test.*` items for this scenario (response time, HTTP status code, error message, failed-step count), visible under **Monitoring → Hosts → Web** or by filtering **Latest data** for `web.test`.

The template does not ship a trigger for web-scenario failure by default. To add one:

```
last(/Dual WAN Backup Link by Zabbix/web.test.fail[HTTPS:{$WAN.HTTP.PORT}])>0
```

Recommended settings: severity **WARNING**, `manual_close` enabled, and a dependency on the **WAN2: ICMP unavailable** trigger — otherwise a full link outage triggers both the ICMP alert and a redundant web-scenario alert.

The `{$WAN.HTTP.PORT}` macro can be overridden per host (e.g. `8443`, `443`) without touching the template; the web scenario URL and the TCP item update automatically.

## Triggers

| Name | Severity | Expression | Notes |
|---|---|---|---|
| WAN2: ICMP unavailable | **HIGH** | `max(icmpping,3m)=0` | No ICMP response for 3 consecutive minutes. |
| WAN2: High ICMP packet loss | WARNING | `min(icmppingloss,5m) > {$WAN.ICMP.LOSS.HIGH}` | Packet loss above threshold; may indicate link degradation. |
| WAN2: High ICMP latency | WARNING | `avg(icmppingsec,5m) > {$WAN.ICMP.RTT.WARN}` | Average RTT above threshold over the last 5 minutes. |
| WAN2: HTTPS:{$WAN.HTTP.PORT} service unavailable | WARNING | `max(net.tcp.service[tcp,,{$WAN.HTTP.PORT}],10m)=0` | Management port not responding. Depends on the ICMP trigger to avoid duplicate alerts. |

All triggers require manual close and are tagged `scope: availability` or `scope: performance`.

### Severity rationale — backup vs. primary

| Event | Primary link | Backup link |
|---|---|---|
| ICMP unavailable | DISASTER | **HIGH** |
| TCP/HTTPS service unavailable | HIGH | WARNING |

The backup link going down on its own is concerning (no contingency route left) but not an immediate emergency — hence HIGH instead of DISASTER. If both links go down, the primary link's DISASTER trigger takes precedence.

## Macros

| Macro | Default | Description |
|---|---|---|
| `{$WAN.HTTP.PORT}` | `4444` | HTTPS management service port on the firewall |
| `{$WAN.ICMP.LOSS.HIGH}` | `50` | ICMP packet loss (%) threshold for the WARNING trigger |
| `{$WAN.ICMP.RTT.WARN}` | `200` | Average ICMP RTT (ms) threshold for the WARNING trigger |

## Graphs

- **WAN: ICMP latency (RTT)** — RTT history in ms
- **WAN: ICMP packet loss (%)** — packet loss history

## Requirements

- Zabbix Server 7.4+
- No Zabbix Agent needed — all checks run server-side
- Network line of sight from the Zabbix server to the backup WAN public IP (ICMP + the configured TCP/HTTPS port)

## Installation

1. Create a host named `<site> - WAN2` with an interface (any type — simple checks work regardless of interface type) pointing to the backup link's public IP
2. Go to **Data collection → Templates → Import** and select `template.json`
3. Link the **Dual WAN Backup Link by Zabbix** template to the host
4. Override `{$WAN.HTTP.PORT}` (and the loss/RTT thresholds if needed) as host-level macros if your environment differs from the defaults

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

# Dual WAN Primary Link by Zabbix

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-Simple_Checks-7F13EC?style=flat-square)
![Agent](https://img.shields.io/badge/Agent-Not_Required-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

**Category:** Network / Availability
**Collection method:** Simple checks (server-side, no Zabbix Agent)
**Items:** 4 + 1 web scenario
**Zabbix version:** 7.4+

## Description

Monitors the availability and quality of the primary WAN link via ICMP and a TCP/HTTPS service check.

Apply this template to a host named `<SITE> - WAN1`, configured with the firewall's **primary public IP**. No Zabbix Agent is required — every check is a Simple Check executed directly by the Zabbix server, so the host's interface can be of any type (Agent, SNMP, etc.) as long as it points to the correct public IP.

### Why a dedicated host for the primary link?

In a dual-WAN architecture, if monitoring relied only on SNMP through the primary IP, a failure of the primary link itself would blind the monitoring system at the exact moment it matters most. Because the checks in this template run from the Zabbix server against the WAN1 public IP directly — independent of any agent and of the secondary link — a primary-link outage is what actually gets detected and alerted on, rather than silently dropping monitoring coverage.

This template is designed to be paired with a **Dual WAN Backup Link** template (same checks, adjusted severities) and a firewall SNMP template, giving three independent monitoring paths per site.

## Items

| Key | Name | Type | Interval | History | Value |
|---|---|---|---|---|---|
| `icmpping` | WAN: ICMP ping | Simple check | 3m | 7d | Up / Down |
| `icmppingloss` | WAN: ICMP packet loss | Simple check | 3m | 30d | % (float) |
| `icmppingsec` | WAN: ICMP latency (RTT) | Simple check | 3m | 30d | ms (float) |
| `net.tcp.service[tcp,,{$WAN.HTTP.PORT}]` | WAN: TCP service on port {$WAN.HTTP.PORT} | Simple check | 5m | 7d | Up / Down |

`icmpping` and the TCP service check use `DISCARD_UNCHANGED_HEARTBEAT` (1h) preprocessing to avoid storing redundant "still up" / "still down" values.

## Web Scenario — HTTPS:{$WAN.HTTP.PORT}

In addition to the Simple Checks above, the template includes a **Web Scenario** that performs a real HTTPS request against the firewall's management interface, rather than only checking that the TCP port accepts a connection. This catches cases where the port is open but the HTTP service itself is hung or erroring.

| Parameter | Value |
|---|---|
| Scenario name | `HTTPS:{$WAN.HTTP.PORT}` |
| Interval | 5m |
| Attempts | 3 |
| Step URL | `https://{HOST.CONN}:{$WAN.HTTP.PORT}/` |
| Step timeout | 60s |
| Accepted status codes | `200, 301, 302, 401, 403` |
| SSL verification | Disabled (self-signed certificates) |

**Why accept 401/403?** Firewall management interfaces (Sophos and others) commonly return `401 Unauthorized` or `403 Forbidden` on `/` when unauthenticated — that's expected behavior and confirms the service is responding. Rejecting those codes would generate false positives.

Zabbix automatically creates supporting items for the scenario, visible under **Latest data** with the `web.test.*` prefix (response time, HTTP status code, error message, and failed-step count). The template does not ship a trigger on `web.test.fail[...]` by default; if you add one, set severity HIGH and add a dependency on the "WAN1: ICMP unavailable" trigger to avoid duplicate alerts when the whole link is down.

## Triggers

| Name | Severity | Condition | Notes |
|---|---|---|---|
| WAN1: ICMP unavailable | **DISASTER** | `max(icmpping,3m)=0` | Manual close. No response to ICMP for 3 consecutive minutes. |
| WAN1: {$WAN.HTTP.PORT} service unavailable | HIGH | `max(net.tcp.service[tcp,,{$WAN.HTTP.PORT}],10m)=0` | Manual close. Depends on the ICMP trigger to avoid duplicate alerts. |
| WAN1: High ICMP packet loss | WARNING | `min(icmppingloss,5m) > {$WAN.ICMP.LOSS.HIGH}` | Manual close. May indicate link degradation. |
| WAN1: High ICMP latency | WARNING | `avg(icmppingsec,5m) > {$WAN.ICMP.RTT.WARN}` | Manual close. Average RTT over the last 5 minutes. |

## Graphs

- **WAN: ICMP latency (RTT)** — RTT history in ms
- **WAN: ICMP packet loss (%)** — packet loss history

## Macros

| Macro | Default | Description |
|---|---|---|
| `{$WAN.HTTP.PORT}` | `4444` | Firewall HTTPS management service port |
| `{$WAN.ICMP.LOSS.HIGH}` | `50` | ICMP packet loss (%) threshold for the WARNING trigger |
| `{$WAN.ICMP.RTT.WARN}` | `200` | Average ICMP RTT (ms) threshold for the WARNING trigger |

To monitor a different management port, override `{$WAN.HTTP.PORT}` at the host level (e.g. `8443`, `443`) — both the TCP item and the web scenario URL update automatically. Monitoring a path other than `/` requires editing the web scenario step directly.

## Requirements

- Zabbix Server 7.4+
- No Zabbix Agent — all items are Simple Checks and a Web Scenario, executed by the Zabbix server
- Network access from the Zabbix server to the WAN1 public IP (ICMP + the configured management port)

## Installation

1. Create a host, e.g. `<SITE> - WAN1`, with an interface (any type) configured with the primary WAN's public IP.
2. Go to **Data collection → Templates → Import** and select `template.json`.
3. Link the **Dual WAN Primary Link by Zabbix** template to the host.
4. Review the macros above and override `{$WAN.HTTP.PORT}` at the host level if the management port differs from the default.

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

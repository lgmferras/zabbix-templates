# Zabbix 7.4 Custom Template Library

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Templates](https://img.shields.io/badge/Templates-19-7F13EC?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

Uma coleção de 19 templates Zabbix de nível enterprise desenvolvidos para ambientes MSP, cobrindo dispositivos de rede, plataformas de nuvem, servidores Windows, gateways IoT e aplicações de negócio.

Todos os templates têm como alvo o **Zabbix 7.4** e seguem convenções consistentes: thresholds orientados por macro, itens com tags, expressões de recuperação em todos os triggers e `DISCARD_UNCHANGED_HEARTBEAT` para reduzir ruído.

---

### Templates

| Template | Categoria | Método | Itens | UserParameters |
|---|---|---|---|---|
| [Ambiance (dormakaba)](templates/ambiance/) | Windows / Aplicações | Zabbix Agent 2 (ativo) | 27 | `user_parameters_ambiance.conf` |
| [ATHOS PDV](templates/athos-pdv/) | Windows / Aplicações | Zabbix Agent 2 (ativo) | 45 | `user_parameters_athos.conf` |
| [D-Link DGS-3100-24 Switch](templates/dlink-dgs-3100-24/) | Dispositivos de Rede | SNMP v2c | 16 | — |
| [Dragino IoT Gateway](templates/dragino-iot/) | IoT / LoRaWAN | SSH + Dependente | 58 | — |
| [Dual WAN Backup Link](templates/dual-wan-backup/) | Rede / Disponibilidade | Verificações simples | 4 | — |
| [Dual WAN Primary Link](templates/dual-wan-primary/) | Rede / Disponibilidade | Verificações simples | 4 + 1 web scenario | — |
| [Kairos](templates/kairos/) | Windows / Aplicações | Zabbix Agent 2 (ativo) | 1 | `user_parameters_kairos.conf` |
| [MSPClouds Backup Monitor](templates/mspclouds-backup/) | Aplicações / Nuvem | HTTP Agent + Dependente/LLD | 11 + LLD | — |
| [NETHOTEL](templates/nethotel/) | Aplicações | Zabbix Agent 2 (ativo) | 15 | `user_parameters_nethotel.conf` |
| [NFe SEFAZ Monitor](templates/nfe-sefaz-monitor/) | Aplicações | Zabbix Agent 2 (passivo) + Python | 1 + 8/autorizador (LLD) | `nfe.conf` |
| [Pi-hole v6](templates/pihole-v6/) | Rede / DNS | SCRIPT (API REST v6) + verificação simples | 23 | — |
| [Oracle Cloud Billing](templates/oracle-cloud-billing/) | Nuvem / Custo | SCRIPT (OCI Usage Reports API) | 2 | — |
| [Oracle Cloud Egress](templates/oracle-cloud-egress/) | Nuvem / Custo | SCRIPT (OCI Monitoring API) | 4 | — |
| [Ricoh SP 3710SF Printer](templates/ricoh-sp3710sf/) | Aplicações / Dispositivos | HTTP (interface web embutida) | 49 | — |
| [Sophos Firewall](templates/sophos-firewall/) | Dispositivos de Rede / Segurança | SNMP v2c | 15 | — |
| [TrueNAS](templates/truenas/) | Aplicações / Armazenamento | HTTP Agent + Dependente | 87 | — |
| [UniFi AP Legacy](templates/unifi-ap-legacy/) | Dispositivos de Rede | SNMP v1/v2c | 10 + 3/VAP | — |
| [UniFi Network 10.6](templates/unifi-network/) | Dispositivos de Rede / Wi-Fi | SCRIPT (chave de API) + LLD | 61 + LLD (AP/rádio/SSID) | — |
| [Windows Backup](templates/windows-backup/) | Windows / Backup | Zabbix Agent 2 (ativo) | 5 | `user_parameters_windows_backup.conf` |
| [Windows DHCP Server](templates/windows-dhcp/) | Windows / Rede | Zabbix Agent 2 (ativo) + PowerShell | 5 + 12 (LLD) | `userparameter_dhcp.conf` + `dhcp_zbx.ps1` |
| [WireGuard Tunnel](templates/wireguard-tunnel/) | Rede / VPN | Zabbix Agent (ativo) | 7 | `user_parameters_wireguard_linux.conf` / `_windows.conf` |

---

### Princípios de design

- **Thresholds orientados por macro** — todos os níveis de alerta são configuráveis por host, sem editar o template
- **Expressões de recuperação** em todo trigger — nenhum fechamento manual necessário para problemas transitórios
- **Itens com tags** — tags `application`, `component` e `scope` para filtragem em dashboards
- **`DISCARD_UNCHANGED_HEARTBEAT`** — reduz a carga de armazenamento sem perder visibilidade
- **Dependências** entre triggers — evita tempestades de alertas causadas por falhas em cascata

### Importação

1. Vá em **Configuração → Templates → Importar**
2. Selecione o `template.json` de qualquer subdiretório
3. Configure as macros do host conforme documentado no README de cada template

### UserParameters

Templates que usam itens ativos do Zabbix Agent com chaves customizadas exigem um arquivo UserParameter instalado no host monitorado. O arquivo está incluído no diretório de cada template, junto ao `template.json`.

**Hosts Linux** — copie para `/etc/zabbix/zabbix_agent2.d/` e execute `systemctl restart zabbix-agent2`.

**Hosts Windows** — copie para `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` e execute `Restart-Service "Zabbix Agent 2"`.

Para o **Windows DHCP Server**, copie também o `dhcp_zbx.ps1` para `C:\Program Files\Zabbix Agent 2\` (o `.conf` faz referência a ele a partir daí).

O **NFe SEFAZ Monitor** é a exceção: ele exige uma imagem customizada do Zabbix Agent 2 com Python 3 (`requests` + `beautifulsoup4`) e uma interface em modo passivo, em vez de um simples UserParameter. Veja o [README](templates/nfe-sefaz-monitor/) dele para a configuração completa.

### Ambiente

Estes templates foram desenvolvidos e testados em um ambiente MSP de produção rodando:
- Zabbix Server 7.4 em Docker (Linux)
- 30+ hosts monitorados entre múltiplos clientes
- Mix de Windows Server, Linux, dispositivos de rede e plataformas de nuvem

---

<a id="en-us"></a>
## 🇺🇸 English

A collection of 19 enterprise-grade Zabbix templates developed for MSP environments, covering network devices, cloud platforms, Windows servers, IoT gateways and business applications.

All templates target **Zabbix 7.4** and follow consistent conventions: macro-driven thresholds, tagged items, recovery expressions on all triggers and `DISCARD_UNCHANGED_HEARTBEAT` to reduce noise.

---

### Templates

| Template | Category | Method | Items | UserParameters |
|---|---|---|---|---|
| [Ambiance (dormakaba)](templates/ambiance/) | Windows / Applications | Zabbix Agent 2 (active) | 27 | `user_parameters_ambiance.conf` |
| [ATHOS PDV](templates/athos-pdv/) | Windows / Applications | Zabbix Agent 2 (active) | 45 | `user_parameters_athos.conf` |
| [D-Link DGS-3100-24 Switch](templates/dlink-dgs-3100-24/) | Network Devices | SNMP v2c | 16 | — |
| [Dragino IoT Gateway](templates/dragino-iot/) | IoT / LoRaWAN | SSH + Dependent | 58 | — |
| [Dual WAN Backup Link](templates/dual-wan-backup/) | Network / Availability | Simple checks | 4 | — |
| [Dual WAN Primary Link](templates/dual-wan-primary/) | Network / Availability | Simple checks | 4 + 1 web scenario | — |
| [Kairos](templates/kairos/) | Windows / Applications | Zabbix Agent 2 (active) | 1 | `user_parameters_kairos.conf` |
| [MSPClouds Backup Monitor](templates/mspclouds-backup/) | Applications / Cloud | HTTP Agent + Dependent/LLD | 11 + LLD | — |
| [NETHOTEL](templates/nethotel/) | Applications | Zabbix Agent 2 (active) | 15 | `user_parameters_nethotel.conf` |
| [NFe SEFAZ Monitor](templates/nfe-sefaz-monitor/) | Applications | Zabbix Agent 2 (passive) + Python | 1 + 8/authorizer (LLD) | `nfe.conf` |
| [Pi-hole v6](templates/pihole-v6/) | Network / DNS | SCRIPT (REST API v6) + simple check | 23 | — |
| [Oracle Cloud Billing](templates/oracle-cloud-billing/) | Cloud / Cost | SCRIPT (OCI Usage Reports API) | 2 | — |
| [Oracle Cloud Egress](templates/oracle-cloud-egress/) | Cloud / Cost | SCRIPT (OCI Monitoring API) | 4 | — |
| [Ricoh SP 3710SF Printer](templates/ricoh-sp3710sf/) | Applications / Devices | HTTP (embedded web UI) | 49 | — |
| [Sophos Firewall](templates/sophos-firewall/) | Network Devices / Security | SNMP v2c | 15 | — |
| [TrueNAS](templates/truenas/) | Applications / Storage | HTTP Agent + Dependent | 87 | — |
| [UniFi AP Legacy](templates/unifi-ap-legacy/) | Network Devices | SNMP v1/v2c | 10 + 3/VAP | — |
| [UniFi Network 10.6](templates/unifi-network/) | Network Devices / Wi-Fi | SCRIPT (API key) + LLD | 61 + LLD (AP/radio/SSID) | — |
| [Windows Backup](templates/windows-backup/) | Windows / Backup | Zabbix Agent 2 (active) | 5 | `user_parameters_windows_backup.conf` |
| [Windows DHCP Server](templates/windows-dhcp/) | Windows / Network | Zabbix Agent 2 (active) + PowerShell | 5 + 12 (LLD) | `userparameter_dhcp.conf` + `dhcp_zbx.ps1` |
| [WireGuard Tunnel](templates/wireguard-tunnel/) | Network / VPN | Zabbix Agent (active) | 7 | `user_parameters_wireguard_linux.conf` / `_windows.conf` |

---

### Design Principles

- **Macro-driven thresholds** — all alert levels configurable per host without editing the template
- **Recovery expressions** on every trigger — no manual close required for transient issues
- **Tagged items** — `application`, `component` and `scope` tags for dashboard filtering
- **`DISCARD_UNCHANGED_HEARTBEAT`** — reduces storage load without losing visibility
- **Dependencies** between triggers — prevents alert storms from cascading failures

### Import

1. Go to **Configuration → Templates → Import**
2. Select the `template.json` from any subdirectory
3. Configure host macros as documented in each template's README

### UserParameters

Templates that use Zabbix Agent active items with custom keys require a UserParameter file installed on the monitored host. The file is included in each template's directory alongside `template.json`.

**Linux hosts** — copy to `/etc/zabbix/zabbix_agent2.d/` and run `systemctl restart zabbix-agent2`.

**Windows hosts** — copy to `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` and run `Restart-Service "Zabbix Agent 2"`.

For **Windows DHCP Server**, also copy `dhcp_zbx.ps1` to `C:\Program Files\Zabbix Agent 2\` (the `.conf` references it from there).

**NFe SEFAZ Monitor** is the exception: it requires a custom Zabbix Agent 2 image with Python 3 (`requests` + `beautifulsoup4`) and a passive-mode interface rather than a plain UserParameter drop-in. See its [README](templates/nfe-sefaz-monitor/) for the full setup.

### Environment

These templates were developed and tested in a production MSP environment running:
- Zabbix Server 7.4 on Docker (Linux)
- 30+ monitored hosts across multiple clients
- Mix of Windows Server, Linux, network devices and cloud platforms

---

## Author

**Luis Gustavo Ferras** — Infrastructure Specialist at [Systrix Tecnologia](https://systrix.com.br/)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-lgmferras-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/lgmferras)
[![GitHub](https://img.shields.io/badge/GitHub-lgmferras-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/lgmferras)

20+ years in enterprise IT infrastructure — Docker · Linux · Zabbix · Oracle Cloud · LoRaWAN

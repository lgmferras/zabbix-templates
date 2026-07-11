# Sophos Firewall by SNMP

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Collection](https://img.shields.io/badge/Collection-SNMP_v2c-7F13EC?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

| | |
|---|---|
| **Categoria** | Dispositivos de rede / Segurança |
| **Método de coleta** | SNMP v2c (`XG-FIREWALL-MIB`) |
| **Itens** | 15 |
| **Versão do Zabbix** | 7.4+ |

### Descrição

Monitora appliances Sophos XG/XGS (SFOS) via SNMP v2c usando a MIB proprietária do fabricante `XG-FIREWALL-MIB` (OID enterprise `1.3.6.1.4.1.21067`). Cobre utilização de CPU, memória e disco, usuários ativos no portal, estado de failover do gateway WAN e throughput de entrada/saída nas interfaces WAN1, WAN2 e LAN.

O ponto central do template é o **trigger de failover WAN**: ele dispara quando o próprio Sophos reporta o gateway de backup (WAN2) como ativo, o que significa que o firewall já detectou a queda do link primário (WAN1) e redirecionou o tráfego. Esta é a forma mais confiável de detectar um evento de failover — mesmo que o polling SNMP seja brevemente interrompido durante a queda, o estado é capturado assim que o appliance reconecta e o histórico é preenchido retroativamente.

Testado em um Sophos XG105 rodando SFOS 17.5.x. Espera-se que funcione em qualquer appliance XG/XGS rodando SFOS 17.x–20.x, já que a MIB se manteve estável nessas versões.

Projetado para ser combinado com os templates [Dual WAN Primary Link](../dual-wan-primary/) e [Dual WAN Backup Link](../dual-wan-backup/) em uma arquitetura de 3 hosts: os hosts WAN1/WAN2 usam Simple Checks contra cada IP público de forma independente (permanecendo acessíveis mesmo que a própria interface SNMP do firewall caia durante um failover), enquanto este template consulta o próprio firewall para saúde interna e status do gateway.

> **Nota:** o Sophos XG não expõe a `HOST-RESOURCES-MIB` padrão (sem `hrProcessorLoad`, `hrStorageSize`, etc.), portanto todas as métricas de saúde do sistema são coletadas através da MIB proprietária do fabricante.

### Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$SOPHOS.CPU.UTIL.WARN}` | `80` | Uso de CPU (%) que dispara um trigger WARNING |
| `{$SOPHOS.CPU.UTIL.HIGH}` | `90` | Uso de CPU (%) que dispara um trigger HIGH |
| `{$SOPHOS.MEM.UTIL.WARN}` | `80` | Uso de memória (%) que dispara um trigger WARNING |
| `{$SOPHOS.MEM.UTIL.HIGH}` | `90` | Uso de memória (%) que dispara um trigger HIGH |
| `{$SOPHOS.DISK.UTIL.WARN}` | `80` | Uso de disco (%) que dispara um trigger WARNING |
| `{$SOPHOS.DISK.UTIL.HIGH}` | `90` | Uso de disco (%) que dispara um trigger HIGH |
| `{$SOPHOS.IF.WAN1.NAME}` | `Port1` | Nome da interface WAN1 conforme reportado pelo `ifDescr` |
| `{$SOPHOS.IF.WAN1.INDEX}` | `5` | `ifIndex` SNMP da interface WAN1 |
| `{$SOPHOS.IF.WAN2.NAME}` | `Port2` | Nome da interface WAN2/backup conforme reportado pelo `ifDescr` |
| `{$SOPHOS.IF.WAN2.INDEX}` | `6` | `ifIndex` SNMP da interface WAN2 |
| `{$SOPHOS.IF.LAN.NAME}` | `Port4` | Nome da interface LAN conforme reportado pelo `ifDescr` |
| `{$SOPHOS.IF.LAN.INDEX}` | `8` | `ifIndex` SNMP da interface LAN |
| `{$HOST.WAN1.NAME}` | *(vazio)* | Nome do host WAN1 correspondente no Zabbix — referenciado na descrição do trigger de failover para que o engenheiro de plantão saiba onde verificar |

As quatro macros de interface `{$SOPHOS.IF.*}` têm como padrão os valores do appliance sobre o qual este template foi construído; sobrescreva-as por host caso o layout de portas ou os índices SNMP sejam diferentes (veja [Descoberta do índice de interface](#descoberta-indice-interface) abaixo).

### Itens

| Key | Nome | OID | Unidades |
|---|---|---|---|
| `system.uptime` | Tempo de atividade | `1.3.6.1.2.1.1.3.0` | uptime |
| `sfos.model` | Modelo do appliance | `1.3.6.1.4.1.21067.2.1.1.2.0` | — |
| `sfos.firmware.version` | Versão do firmware | `1.3.6.1.4.1.21067.2.1.1.3.0` | — |
| `sfos.cpu.util` | Utilização de CPU | `1.3.6.1.4.1.21067.2.1.2.2.1.0` | % |
| `sfos.memory.util` | Utilização de memória | `1.3.6.1.4.1.21067.2.1.2.3.2.0` | % |
| `sfos.disk.util` | Utilização de disco | `1.3.6.1.4.1.21067.2.1.2.4.2.0` | % |
| `sfos.users.live` | Usuários ativos no portal | `1.3.6.1.4.1.21067.2.1.2.5.0` | — |
| `sfos.gateway.status[1]` | Status do gateway WAN1 | `1.3.6.1.4.1.21067.2.1.3.1.1.0` | 1=Ativo, 2=Inativo |
| `sfos.gateway.status[2]` | Status do gateway WAN2 (backup) | `1.3.6.1.4.1.21067.2.1.3.2.1.0` | 1=Ativo, 2=Inativo |
| `net.if.in[{$SOPHOS.IF.WAN1.NAME},bits]` | WAN1 — bits recebidos | `ifInOctets.{$SOPHOS.IF.WAN1.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.WAN1.NAME},bits]` | WAN1 — bits enviados | `ifOutOctets.{$SOPHOS.IF.WAN1.INDEX}` | bps |
| `net.if.in[{$SOPHOS.IF.WAN2.NAME},bits]` | WAN2 — bits recebidos | `ifInOctets.{$SOPHOS.IF.WAN2.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.WAN2.NAME},bits]` | WAN2 — bits enviados | `ifOutOctets.{$SOPHOS.IF.WAN2.INDEX}` | bps |
| `net.if.in[{$SOPHOS.IF.LAN.NAME},bits]` | LAN — bits recebidos | `ifInOctets.{$SOPHOS.IF.LAN.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.LAN.NAME},bits]` | LAN — bits enviados | `ifOutOctets.{$SOPHOS.IF.LAN.INDEX}` | bps |

Os itens de throughput aplicam `CHANGE_PER_SECOND` + um multiplicador `×8` sobre os contadores SNMP brutos (`ifInOctets`/`ifOutOctets`) para produzir bits por segundo. Os itens de CPU, memória, disco, uptime e status de gateway usam `DISCARD_UNCHANGED_HEARTBEAT` para evitar o armazenamento de valores redundantes sem alteração.

### Triggers

| Nome | Severidade | Condição |
|---|---|---|
| CPU alta | WARNING | `avg(sfos.cpu.util,5m) > {$SOPHOS.CPU.UTIL.WARN}` |
| CPU crítica | HIGH | `avg(sfos.cpu.util,5m) > {$SOPHOS.CPU.UTIL.HIGH}` |
| Memória alta | WARNING | `avg(sfos.memory.util,5m) > {$SOPHOS.MEM.UTIL.WARN}` |
| Memória crítica | HIGH | `avg(sfos.memory.util,5m) > {$SOPHOS.MEM.UTIL.HIGH}` |
| Disco alto | WARNING | `last(sfos.disk.util) > {$SOPHOS.DISK.UTIL.WARN}` |
| Disco crítico | HIGH | `last(sfos.disk.util) > {$SOPHOS.DISK.UTIL.HIGH}` |
| **Link de backup WAN2 ativo — verificar WAN1** | WARNING | `last(sfos.gateway.status[2]) = 1` |
| Versão do firmware alterada | INFO | `change(sfos.firmware.version) = 1` |

CPU, memória e disco possuem, cada um, um trigger WARNING que depende (e é suprimido por) seu trigger HIGH correspondente, de modo que apenas o alerta mais severo dispara durante uma escalada. Todos os triggers, exceto o informativo de mudança de firmware, exigem fechamento manual, e todos usam expressões de recuperação em vez de janelas de flapping com duração fixa.

### Instalação

#### 1. Habilitar o SNMP no appliance Sophos

`Administration → SNMP → Enable SNMP`
- Versão: **SNMPv2c**
- Community string: escolha um valor e anote-o
- Hosts permitidos: restrinja ao IP do servidor Zabbix

#### 2. Descobrir os índices de interface

<a id="descoberta-indice-interface"></a>

As macros `{$SOPHOS.IF.*.INDEX}` devem corresponder aos valores reais de `ifIndex` do seu appliance, que podem diferir dos padrões dependendo do layout de portas e da versão de firmware:

```bash
snmpwalk -v2c -c <community> <firewall-ip> 1.3.6.1.2.1.2.2.1.2
# Exemplo de saída:
# ifDescr.5 = Port1  → WAN1 → {$SOPHOS.IF.WAN1.INDEX} = 5
# ifDescr.6 = Port2  → WAN2 → {$SOPHOS.IF.WAN2.INDEX} = 6
# ifDescr.8 = Port4  → LAN  → {$SOPHOS.IF.LAN.INDEX}  = 8
```

#### 3. Criar o host no Zabbix

- Tipo de interface: **SNMP v2c**, porta 161, apontando para o IP WAN1 do firewall
- Importe o `template.json` (**Data collection → Templates → Import**) e vincule-o ao host
- Sobrescreva as macros `{$SOPHOS.IF.*}` no nível do host caso seus índices sejam diferentes dos padrões
- Opcionalmente defina `{$HOST.WAN1.NAME}` com o nome do host WAN1 correspondente no Zabbix, para que a descrição do trigger de failover aponte diretamente para ele

#### 4. Verificar

Confira **Latest data** para o host — `sfos.cpu.util`, `sfos.memory.util` e `sfos.model` devem ser preenchidos dentro de um intervalo de polling. Se os itens de throughput de interface (`net.if.in`/`net.if.out`) permanecerem em zero, verifique novamente as macros `{$SOPHOS.IF.*.INDEX}` em relação à saída do `snmpwalk` acima.

---

<a id="en-us"></a>
## 🇺🇸 English

| | |
|---|---|
| **Category** | Network Devices / Security |
| **Collection method** | SNMP v2c (`XG-FIREWALL-MIB`) |
| **Items** | 15 |
| **Zabbix version** | 7.4+ |

### Description

Monitors Sophos XG/XGS appliances (SFOS) over SNMP v2c using the vendor's proprietary `XG-FIREWALL-MIB` (enterprise OID `1.3.6.1.4.1.21067`). Covers CPU, memory and disk utilization, active portal users, WAN gateway failover state, and inbound/outbound throughput on the WAN1, WAN2 and LAN interfaces.

The template's centerpiece is its **WAN failover trigger**: it fires when the Sophos itself reports the backup gateway (WAN2) as active, which means the firewall has already detected the primary link (WAN1) as down and rerouted traffic. This is the most reliable way to detect a failover event — even if SNMP polling is briefly interrupted during the outage, the state is captured as soon as the appliance reconnects and history is backfilled.

Tested on a Sophos XG105 running SFOS 17.5.x. Expected to work on any XG/XGS appliance running SFOS 17.x–20.x, since the MIB has been stable across those releases.

Designed to be paired with the [Dual WAN Primary Link](../dual-wan-primary/) and [Dual WAN Backup Link](../dual-wan-backup/) templates in a 3-host architecture: the WAN1/WAN2 hosts use Simple Checks against each public IP independently (so they stay reachable even if the firewall's own SNMP interface goes down during a failover), while this template polls the firewall itself for internal health and gateway status.

> **Note:** the Sophos XG does not expose the standard `HOST-RESOURCES-MIB` (no `hrProcessorLoad`, `hrStorageSize`, etc.), so all system health metrics are collected through the vendor-specific MIB instead.

### Macros

| Macro | Default | Description |
|---|---|---|
| `{$SOPHOS.CPU.UTIL.WARN}` | `80` | CPU usage (%) that raises a WARNING trigger |
| `{$SOPHOS.CPU.UTIL.HIGH}` | `90` | CPU usage (%) that raises a HIGH trigger |
| `{$SOPHOS.MEM.UTIL.WARN}` | `80` | Memory usage (%) that raises a WARNING trigger |
| `{$SOPHOS.MEM.UTIL.HIGH}` | `90` | Memory usage (%) that raises a HIGH trigger |
| `{$SOPHOS.DISK.UTIL.WARN}` | `80` | Disk usage (%) that raises a WARNING trigger |
| `{$SOPHOS.DISK.UTIL.HIGH}` | `90` | Disk usage (%) that raises a HIGH trigger |
| `{$SOPHOS.IF.WAN1.NAME}` | `Port1` | WAN1 interface name as reported by `ifDescr` |
| `{$SOPHOS.IF.WAN1.INDEX}` | `5` | SNMP `ifIndex` of the WAN1 interface |
| `{$SOPHOS.IF.WAN2.NAME}` | `Port2` | WAN2/backup interface name as reported by `ifDescr` |
| `{$SOPHOS.IF.WAN2.INDEX}` | `6` | SNMP `ifIndex` of the WAN2 interface |
| `{$SOPHOS.IF.LAN.NAME}` | `Port4` | LAN interface name as reported by `ifDescr` |
| `{$SOPHOS.IF.LAN.INDEX}` | `8` | SNMP `ifIndex` of the LAN interface |
| `{$HOST.WAN1.NAME}` | *(empty)* | Name of the corresponding WAN1 host in Zabbix — referenced in the failover trigger description so the on-call engineer knows where to look |

All four `{$SOPHOS.IF.*}` interface macros default to the values from the appliance this template was built against; override them per host if your port layout or SNMP indexes differ (see [Interface index discovery](#interface-index-discovery) below).

### Items

| Key | Name | OID | Units |
|---|---|---|---|
| `system.uptime` | Uptime | `1.3.6.1.2.1.1.3.0` | uptime |
| `sfos.model` | Appliance model | `1.3.6.1.4.1.21067.2.1.1.2.0` | — |
| `sfos.firmware.version` | Firmware version | `1.3.6.1.4.1.21067.2.1.1.3.0` | — |
| `sfos.cpu.util` | CPU utilization | `1.3.6.1.4.1.21067.2.1.2.2.1.0` | % |
| `sfos.memory.util` | Memory utilization | `1.3.6.1.4.1.21067.2.1.2.3.2.0` | % |
| `sfos.disk.util` | Disk utilization | `1.3.6.1.4.1.21067.2.1.2.4.2.0` | % |
| `sfos.users.live` | Active portal users | `1.3.6.1.4.1.21067.2.1.2.5.0` | — |
| `sfos.gateway.status[1]` | WAN1 gateway status | `1.3.6.1.4.1.21067.2.1.3.1.1.0` | 1=Active, 2=Inactive |
| `sfos.gateway.status[2]` | WAN2 (backup) gateway status | `1.3.6.1.4.1.21067.2.1.3.2.1.0` | 1=Active, 2=Inactive |
| `net.if.in[{$SOPHOS.IF.WAN1.NAME},bits]` | WAN1 — bits received | `ifInOctets.{$SOPHOS.IF.WAN1.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.WAN1.NAME},bits]` | WAN1 — bits sent | `ifOutOctets.{$SOPHOS.IF.WAN1.INDEX}` | bps |
| `net.if.in[{$SOPHOS.IF.WAN2.NAME},bits]` | WAN2 — bits received | `ifInOctets.{$SOPHOS.IF.WAN2.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.WAN2.NAME},bits]` | WAN2 — bits sent | `ifOutOctets.{$SOPHOS.IF.WAN2.INDEX}` | bps |
| `net.if.in[{$SOPHOS.IF.LAN.NAME},bits]` | LAN — bits received | `ifInOctets.{$SOPHOS.IF.LAN.INDEX}` | bps |
| `net.if.out[{$SOPHOS.IF.LAN.NAME},bits]` | LAN — bits sent | `ifOutOctets.{$SOPHOS.IF.LAN.INDEX}` | bps |

Throughput items apply `CHANGE_PER_SECOND` + a `×8` multiplier to the raw SNMP counters (`ifInOctets`/`ifOutOctets`) to produce bits-per-second. CPU, memory, disk, uptime and gateway-status items use `DISCARD_UNCHANGED_HEARTBEAT` to avoid storing redundant unchanged values.

### Triggers

| Name | Severity | Condition |
|---|---|---|
| CPU high | WARNING | `avg(sfos.cpu.util,5m) > {$SOPHOS.CPU.UTIL.WARN}` |
| CPU critical | HIGH | `avg(sfos.cpu.util,5m) > {$SOPHOS.CPU.UTIL.HIGH}` |
| Memory high | WARNING | `avg(sfos.memory.util,5m) > {$SOPHOS.MEM.UTIL.WARN}` |
| Memory critical | HIGH | `avg(sfos.memory.util,5m) > {$SOPHOS.MEM.UTIL.HIGH}` |
| Disk high | WARNING | `last(sfos.disk.util) > {$SOPHOS.DISK.UTIL.WARN}` |
| Disk critical | HIGH | `last(sfos.disk.util) > {$SOPHOS.DISK.UTIL.HIGH}` |
| **WAN2 backup link active — check WAN1** | WARNING | `last(sfos.gateway.status[2]) = 1` |
| Firmware version changed | INFO | `change(sfos.firmware.version) = 1` |

CPU, memory and disk each have a WARNING trigger that depends on (and is suppressed by) their matching HIGH trigger, so only the more severe alert fires during an escalation. All triggers except the informational firmware-change one require manual close, and all use recovery expressions rather than fixed-duration flapping windows.

### Installation

#### 1. Enable SNMP on the Sophos appliance

`Administration → SNMP → Enable SNMP`
- Version: **SNMPv2c**
- Community string: choose a value and note it down
- Allowed hosts: restrict to the Zabbix Server's IP

#### 2. Discover the interface indexes

<a id="interface-index-discovery"></a>

The `{$SOPHOS.IF.*.INDEX}` macros must match your appliance's actual `ifIndex` values, which can differ from the defaults depending on port layout and firmware version:

```bash
snmpwalk -v2c -c <community> <firewall-ip> 1.3.6.1.2.1.2.2.1.2
# Example output:
# ifDescr.5 = Port1  → WAN1 → {$SOPHOS.IF.WAN1.INDEX} = 5
# ifDescr.6 = Port2  → WAN2 → {$SOPHOS.IF.WAN2.INDEX} = 6
# ifDescr.8 = Port4  → LAN  → {$SOPHOS.IF.LAN.INDEX}  = 8
```

#### 3. Create the host in Zabbix

- Interface type: **SNMP v2c**, port 161, pointed at the firewall's WAN1 IP
- Import `template.json` (**Data collection → Templates → Import**) and link it to the host
- Override the `{$SOPHOS.IF.*}` macros at the host level if your indexes differ from the defaults
- Optionally set `{$HOST.WAN1.NAME}` to the name of the corresponding WAN1-link host in Zabbix, so the failover trigger's description points directly at it

#### 4. Verify

Check **Latest data** for the host — `sfos.cpu.util`, `sfos.memory.util` and `sfos.model` should populate within one polling interval. If the interface throughput items (`net.if.in`/`net.if.out`) stay at zero, double-check the `{$SOPHOS.IF.*.INDEX}` macros against the `snmpwalk` output above.

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

# Windows DHCP Server by Zabbix agent active

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-2.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_active-339933?style=flat-square)
![OS](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

Template Zabbix para monitoramento do serviço DHCP em Windows Server via Zabbix Agent 2 ativo.

**Versão:** 2.0
**Zabbix:** 7.4
**Agente:** Zabbix Agent 2 (modo ativo) + PowerShell
**Sistema operacional:** Windows Server 2016+ (função DHCP Server)

---

## Arquivos

| Arquivo | Destino no Windows | Descrição |
|---|---|---|
| `dhcp_zbx.ps1` | `C:\Program Files\Zabbix Agent 2\` | Script PowerShell principal de coleta |
| `userparameter_dhcp.conf` | `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` | UserParameters do agente |
| `template.json` | Importar no Zabbix | Template Zabbix |

---

## Instalação

### 1. Copiar os arquivos para o Windows Server

```powershell
# Copiar o script
Copy-Item dhcp_zbx.ps1 "C:\Program Files\Zabbix Agent 2\"

# Copiar os userparameters
Copy-Item userparameter_dhcp.conf "C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\"
```

### 2. Configurar o Zabbix Agent 2

O arquivo de configuração principal do agente (`C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf`) deve conter:

```ini
ServerActive=<ZABBIX-SERVER-IP>   # IP do Zabbix Server
Hostname=<HOST-NAME-IN-ZABBIX>    # Nome exato do host no Zabbix
UnsafeUserParameters=1            # Necessário para passar argumentos ao script
Include=C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\
```

> A diretiva `Include` carrega automaticamente o `userparameter_dhcp.conf`.

### 3. Reiniciar o agente

```powershell
Restart-Service "Zabbix Agent 2"
```

### 4. Testar localmente

```powershell
# Testar se o script funciona (requer o módulo DhcpServer)
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4ScopesCount
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4LeasesTotal
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4Utilization
```

### 5. Importar o template e aplicar ao host

1. No Zabbix Web UI: **Data collection → Templates → Import**
2. Importar o `template.json`
3. Aplicar o template ao host Windows Server que executa o DHCP

---

## Itens monitorados

| Chave | Tipo | Descrição |
|---|---|---|
| `service.info[DHCPServer,state]` | uint | Estado do serviço DHCP (0 = em execução) |
| `dhcp.v4.scopes.count` | uint | Número de escopos IPv4 configurados |
| `dhcp.v4.leases.total` | uint | Total de endereços em todos os escopos |
| `dhcp.v4.leases.used` | uint | Endereços em uso (global) |
| `dhcp.v4.utilization` | float | Utilização global do pool de escopos (%) |

---

## Itens por escopo (LLD, v2.0+)

A discovery rule `dhcp.v4.scope.discovery` cria automaticamente os itens abaixo para cada escopo IPv4 descoberto (macros `{#SCOPEID}`, `{#SCOPENAME}`):

| Chave | Tipo | Descrição |
|---|---|---|
| `dhcp.v4.scope.details[{#SCOPEID}]` | TEXT (mestre) | JSON bruto — não usado diretamente, alimenta os itens dependentes abaixo |
| `dhcp.v4.scope.name[{#SCOPEID}]` | CHAR | Nome do escopo configurado no DHCP |
| `dhcp.v4.scope.leases.total[{#SCOPEID}]` | uint | Total de endereços do escopo |
| `dhcp.v4.scope.leases.used[{#SCOPEID}]` | uint | Endereços em uso no escopo |
| `dhcp.v4.scope.utilization[{#SCOPEID}]` | float, % | Utilização do escopo |
| `dhcp.v4.scope.gateway[{#SCOPEID}]` | CHAR | Gateway (option 003) |
| `dhcp.v4.scope.dns[{#SCOPEID}]` | TEXT | Servidores DNS (option 006), array JSON |
| `dhcp.v4.scope.domain[{#SCOPEID}]` | CHAR | Domínio (option 015) |
| `dhcp.v4.scope.reservations.count[{#SCOPEID}]` | uint | Número de reservas |
| `dhcp.v4.scope.reservations.json[{#SCOPEID}]` | TEXT | Lista de reservas (IP+MAC+nome), array JSON |
| `dhcp.v4.scope.exclusions.count[{#SCOPEID}]` | uint | Número de exclusion ranges |
| `dhcp.v4.scope.exclusions.json[{#SCOPEID}]` | TEXT | Lista de exclusion ranges, array JSON |

**Trigger:** *"Scope {#SCOPENAME}: no gateway/DNS configured"* (WARNING) — dispara quando `gateway` ou `dns` retornam vazios.

> A discovery rule utiliza a chave `dhcp.v4.scope.discovery`, já presente no `userparameter_dhcp.conf` desde a v1.0 (documentada como "uso manual"). Hosts que já executam o script v1.0 **não precisam de nenhuma alteração** para a LLD em si — apenas o item `dhcp.v4.scope.details[{#SCOPEID}]` (e seus dependentes) exige a atualização do script/conf da v2.0.

### UserParameters adicionais (disponíveis para uso manual)

| Chave | Descrição |
|---|---|
| `dhcp.ipv4.enabled` | DHCP IPv4 ativado/desativado |
| `dhcp.ipv6.enabled` | DHCP IPv6 ativado/desativado |
| `dhcp.db.path` | Caminho do banco de dados do DHCP |
| `dhcp.backup.path` | Caminho do backup do banco de dados |
| `dhcp.v4.scope.discovery` | LLD — descoberta de escopos |
| `dhcp.v4.scope.stats[{scopeid}]` | JSON de estatísticas por escopo |
| `dhcp.v4.scope.get[{scopeid}]` | JSON de detalhes por escopo |
| `dhcp.v4.scope.reservations.count[{scopeid}]` | Reservas por escopo |
| `dhcp.v4.scope.options.count[{scopeid}]` | Opções por escopo |

---

## Pré-requisitos

- Windows Server com a função **DHCP Server** instalada
- Módulo PowerShell `DhcpServer` disponível (`Import-Module DhcpServer`)
- Zabbix Agent 2 instalado em `C:\Program Files\Zabbix Agent 2\`
- `UnsafeUserParameters=1` no agente (necessário para passar argumentos ao script)

---

## Solução de problemas

**"Unknown metric dhcp.v4.leases.total"**
O `userparameter_dhcp.conf` não está sendo carregado. Verifique:
- Se o arquivo está em `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\`
- Se `Include=C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` está definido no conf principal
- Reinicie o serviço após qualquer alteração

**"Value of type string is not suitable for value type Numeric"**
Problema de BOM UTF-8 na saída do PowerShell. O script já inclui a correção:
```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
```
Se o erro persistir, verifique se o arquivo `.ps1` foi salvo sem BOM (use o VS Code com "UTF-8" sem BOM).

**Script retorna "0" sem erro**
O módulo `DhcpServer` não está disponível. Verifique:
```powershell
Get-Module -ListAvailable DhcpServer
```
O módulo é instalado automaticamente junto com a função DHCP Server do Windows.

---

## Changelog

| Versão | Alterações |
|---|---|
| 2.0 | Adicionada a discovery rule `dhcp.v4.scope.discovery` (LLD por escopo) com 11 item prototypes (nome, leases, utilização, gateway, DNS, domínio, reservas e exclusions) e o trigger prototype "no gateway/DNS configured"; corrigido o colapso do array JSON de escopo único em `V4ScopeDiscovery`; corrigidos os totais de `V4ScopeStats`/`V4ScopeDetails` para usar `InUse + Free` em vez de `AddressesTotal` |
| 1.0 | Versão inicial — estado do serviço, total/ativo de leases IPv4 e trigger de utilização do pool |

---

<a id="en-us"></a>
## 🇺🇸 English

Zabbix template for monitoring the DHCP service on Windows Server via active Zabbix Agent 2.

**Version:** 2.0
**Zabbix:** 7.4
**Agent:** Zabbix Agent 2 (active mode) + PowerShell
**Operating system:** Windows Server 2016+ (DHCP Server role)

---

## Files

| File | Destination on Windows | Description |
|---|---|---|
| `dhcp_zbx.ps1` | `C:\Program Files\Zabbix Agent 2\` | Main PowerShell collection script |
| `userparameter_dhcp.conf` | `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` | Agent UserParameters |
| `template.json` | Import into Zabbix | Zabbix template |

---

## Installation

### 1. Copy files to the Windows Server

```powershell
# Copy the script
Copy-Item dhcp_zbx.ps1 "C:\Program Files\Zabbix Agent 2\"

# Copy the userparameters
Copy-Item userparameter_dhcp.conf "C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\"
```

### 2. Configure Zabbix Agent 2

The main agent config file (`C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf`) must have:

```ini
ServerActive=<ZABBIX-SERVER-IP>   # Zabbix Server IP
Hostname=<HOST-NAME-IN-ZABBIX>    # Exact host name in Zabbix
UnsafeUserParameters=1            # Required to pass arguments to the script
Include=C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\
```

> The `Include` directive automatically loads `userparameter_dhcp.conf`.

### 3. Restart the agent

```powershell
Restart-Service "Zabbix Agent 2"
```

### 4. Test locally

```powershell
# Test that the script works (requires the DhcpServer module)
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4ScopesCount
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4LeasesTotal
& "C:\Program Files\Zabbix Agent 2\dhcp_zbx.ps1" -Action V4Utilization
```

### 5. Import the template and apply it to the host

1. In the Zabbix Web UI: **Data collection → Templates → Import**
2. Import `template.json`
3. Apply the template to the Windows Server host running DHCP

---

## Monitored items

| Key | Type | Description |
|---|---|---|
| `service.info[DHCPServer,state]` | uint | DHCP service state (0 = running) |
| `dhcp.v4.scopes.count` | uint | Number of configured IPv4 scopes |
| `dhcp.v4.leases.total` | uint | Total addresses across all scopes |
| `dhcp.v4.leases.used` | uint | Addresses in use (global) |
| `dhcp.v4.utilization` | float | Global scope pool utilization (%) |

---

## Per-scope items (LLD, v2.0+)

The `dhcp.v4.scope.discovery` discovery rule automatically creates the items below for each discovered IPv4 scope (macros `{#SCOPEID}`, `{#SCOPENAME}`):

| Key | Type | Description |
|---|---|---|
| `dhcp.v4.scope.details[{#SCOPEID}]` | TEXT (master) | Raw JSON — not used directly, feeds the dependent items below |
| `dhcp.v4.scope.name[{#SCOPEID}]` | CHAR | Scope name configured in DHCP |
| `dhcp.v4.scope.leases.total[{#SCOPEID}]` | uint | Total addresses in the scope |
| `dhcp.v4.scope.leases.used[{#SCOPEID}]` | uint | Addresses in use in the scope |
| `dhcp.v4.scope.utilization[{#SCOPEID}]` | float, % | Scope utilization |
| `dhcp.v4.scope.gateway[{#SCOPEID}]` | CHAR | Gateway (option 003) |
| `dhcp.v4.scope.dns[{#SCOPEID}]` | TEXT | DNS servers (option 006), JSON array |
| `dhcp.v4.scope.domain[{#SCOPEID}]` | CHAR | Domain (option 015) |
| `dhcp.v4.scope.reservations.count[{#SCOPEID}]` | uint | Number of reservations |
| `dhcp.v4.scope.reservations.json[{#SCOPEID}]` | TEXT | List of reservations (IP+MAC+name), JSON array |
| `dhcp.v4.scope.exclusions.count[{#SCOPEID}]` | uint | Number of exclusion ranges |
| `dhcp.v4.scope.exclusions.json[{#SCOPEID}]` | TEXT | List of exclusion ranges, JSON array |

**Trigger:** *"Scope {#SCOPENAME}: no gateway/DNS configured"* (WARNING) — fires when `gateway` or `dns` come back empty.

> The discovery rule uses the `dhcp.v4.scope.discovery` key, already present in `userparameter_dhcp.conf` since v1.0 (documented as "manual use"). Hosts already running the v1.0 script **need no change** for the LLD itself — only the `dhcp.v4.scope.details[{#SCOPEID}]` item (and its dependents) requires the v2.0 script/conf update.

### Additional UserParameters (available for manual use)

| Key | Description |
|---|---|
| `dhcp.ipv4.enabled` | DHCP IPv4 enabled/disabled |
| `dhcp.ipv6.enabled` | DHCP IPv6 enabled/disabled |
| `dhcp.db.path` | Path to the DHCP database |
| `dhcp.backup.path` | Path to the database backup |
| `dhcp.v4.scope.discovery` | LLD — scope discovery |
| `dhcp.v4.scope.stats[{scopeid}]` | Per-scope stats JSON |
| `dhcp.v4.scope.get[{scopeid}]` | Per-scope details JSON |
| `dhcp.v4.scope.reservations.count[{scopeid}]` | Reservations per scope |
| `dhcp.v4.scope.options.count[{scopeid}]` | Options per scope |

---

## Requirements

- Windows Server with the **DHCP Server** role installed
- PowerShell `DhcpServer` module available (`Import-Module DhcpServer`)
- Zabbix Agent 2 installed at `C:\Program Files\Zabbix Agent 2\`
- `UnsafeUserParameters=1` on the agent (required to pass arguments to the script)

---

## Troubleshooting

**"Unknown metric dhcp.v4.leases.total"**
`userparameter_dhcp.conf` is not being loaded. Check:
- That the file is in `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\`
- That `Include=C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` is set in the main conf
- Restart the service after any change

**"Value of type string is not suitable for value type Numeric"**
UTF-8 BOM issue in the PowerShell output. The script already includes the fix:
```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
```
If the error persists, verify the `.ps1` file was saved without a BOM (use VS Code with "UTF-8" without BOM).

**Script returns "0" with no error**
The `DhcpServer` module is not available. Check:
```powershell
Get-Module -ListAvailable DhcpServer
```
The module is installed automatically with the Windows DHCP Server role.

---

## Changelog

| Version | Changes |
|---|---|
| 2.0 | Added the `dhcp.v4.scope.discovery` discovery rule (per-scope LLD) with 11 item prototypes (name, leases, utilization, gateway, DNS, domain, reservations and exclusions) and the "no gateway/DNS configured" trigger prototype; fixed `V4ScopeDiscovery` single-scope JSON array collapse; fixed `V4ScopeStats`/`V4ScopeDetails` totals to use `InUse + Free` instead of `AddressesTotal` |
| 1.0 | Initial release — service state, IPv4 leases total/active and pool utilization trigger |

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

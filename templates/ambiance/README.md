# Ambiance by Zabbix agent active

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.2-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-Agent_2_active-339933?style=flat-square)
![OS](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

Template para o servidor do **dormakaba Ambiance**, o sistema de gestão de fechaduras de hotel. Monitora os 21 serviços do Ambiance e o backup do banco SQL Server, com a severidade de cada alerta definida pelo impacto real de cada serviço.

Não é um produto oficial da dormakaba.

---

### O que é Monitorado

- **Serviços** — 21 itens, um por serviço, verificados pela presença do processo (1 = em execução, 0 = parado), cada um com seu trigger.
- **Backup** — idade, tamanho, quantidade e nome dos arquivos `AMBIANCE-Backup-[1-7].bak` gravados pelo job do SQL Server, com 6 triggers.

Total: 27 itens, 27 triggers, 6 macros.

---

### Critério de Severidade

| Severidade | Quando | Serviços |
|---|---|---|
| DISASTER | Todo o sistema para | Server, Web API, Database Engine |
| HIGH | A recepção não consegue gravar nem ler cartões | Encoder Service, AmbianceClient |
| AVERAGE | Uma função inteira para, mas a emissão manual de chaves continua | PMS Agent, HubManager, HubGateway |
| WARNING | Interface ou integração que só afeta quem a usa | Demais interfaces de PMS, VHE, chave móvel, AuroraSync, MatrixSync |
| INFO | Nada para de funcionar para o hotel | Service Manager / Watchdog |

Segundo a dormakaba, todos os serviços ficam em execução o tempo todo, mesmo os de recursos que o hotel não usa. Por isso um serviço de interface parado merece alerta, mas baixo. Se o seu hotel usa uma interface de PMS específica (FIAS, LGS, BART etc.), vale subir a severidade dela.

---

### Itens — Serviços

#### Centrais (`subcomponent: core`)

| Item | Serviço Windows | Processo | Porta(s) | Severidade | Função e impacto |
|---|---|---|---|---|---|
| `ambiance.databaseengine` | Ambiance Database Engine | `Bus.DatabaseEngine.Service.Host` | 5040 | **DISASTER** | Camada de dados: grava, consulta e organiza os dados do Ambiance no SQL Server. Se parar: Todo o sistema para: nenhuma operação que dependa de dados funciona. |
| `ambiance.server` | Ambiance Server | `KabaService` | 49999 | **DISASTER** | Serviço principal: coordena todos os demais e executa os serviços internos do barramento (Bus) como tarefas paralelas. Se parar: Todo o sistema para: não é possível emitir nem ler chaves, e as integrações deixam de responder. |
| `ambiance.webapi` | Ambiance Web API | `Kaba.Web.Gateway.API` | 26265 (HTTP), 443 (HTTPS) | **DISASTER** | Gateway de API: recebe as requisições da interface do Ambiance e dos serviços de campo (cliente das estações e gateway dos hubs). Se parar: Todo o sistema para: a interface do Ambiance deixa de funcionar nas estações. |
| `ambiance.client` | AmbianceClient | `DokaClient` | 40100 | **HIGH** | Codifica e lê chaves RFID nos codificadores USB e fala com a unidade de manutenção (Maintenance Unit) ligados a esta máquina. Se parar: Não é possível gravar nem ler cartões nos codificadores USB desta máquina, nem usar a unidade de manutenção. |
| `ambiance.encoder` | Ambiance Encoder Service | `Encoder.Service.Host` | 28000 (HTTP), 28001 (HTTPS) | **HIGH** | Codifica e lê chaves RFID nos codificadores ligados por rede (TCP/IP). Se parar: Não é possível gravar nem ler cartões nos codificadores de rede; a recepção não emite chaves por eles. |

#### Integração com o PMS (`subcomponent: pms`)

| Item | Serviço Windows | Processo | Porta(s) | Severidade | Função e impacto |
|---|---|---|---|---|---|
| `ambiance.pmsagent` | Ambiance PMS Agent | `Kaba.PMS.Agent.Host` | 9595, 9596 | **AVERAGE** | Recebe do sistema de gestão hoteleira (PMS) os registros de hóspedes e os pedidos de emissão de chave e os entrega ao barramento. Atende todas as interfaces de PMS, exceto IRS e PRS. Se parar: O PMS deixa de registrar hóspedes e emitir chaves automaticamente (exceto por IRS/PRS). A emissão manual pela interface do Ambiance continua. |
| `ambiance.bart` | Ambiance PMS BART | `PMS.BART.Service.Host` | 9898 | **WARNING** | Interface de PMS dormakaba BART (web service). Se parar: Sem registro de hóspedes nem emissão de chaves pelo PMS via BART. Só afeta hotéis que usam essa interface. |
| `ambiance.pmsfias` | Ambiance PMS FIAS | `Kaba.PMS.FIAS.SocketService.Host` | 8265 | **WARNING** | Ouvinte TCP da interface Oracle FIAS (usada pelo Opera e por PMS compatíveis). Se parar: Sem registro de hóspedes nem emissão de chaves pelo PMS via FIAS. Só afeta hotéis que usam essa interface. |
| `ambiance.pmsirsagent` | Ambiance PMS IRSPRS Agent | `Kaba.PMS.IRS.Agent.Host` | 9696 | **WARNING** | Entrega ao barramento os registros de hóspedes e pedidos de chave vindos das interfaces dormakaba IRS e PRS. Se parar: Sem registro de hóspedes nem emissão de chaves pelo PMS via IRS/PRS. Só afeta hotéis que usam essas interfaces. |
| `ambiance.pmsirssocket` | Ambiance PMS IRSPRS | `Kaba.PMS.IRS.SocketService.Host` | 8264 | **WARNING** | Ouvinte TCP das interfaces dormakaba IRS e PRS; conversa com o PMS, inclusive por serial (RS232). Se parar: Sem registro de hóspedes nem emissão de chaves pelo PMS via IRS/PRS. Só afeta hotéis que usam essas interfaces. |
| `ambiance.pmslgs` | Ambiance PMS LGS API | `PMS.LGS.API` | 5120 (HTTP), 5121 (HTTPS) | **WARNING** | API REST dormakaba LGS para o PMS. Se parar: Sem registro de hóspedes nem emissão de chaves pelo PMS via API REST LGS. Só afeta hotéis que usam essa interface. |
| `ambiance.pmsrestapi` | Ambiance PMS REST API | `dkLockServerApiWs` | 9090 | **WARNING** | API REST dormakaba LGS para o PMS, variante KF2. Se parar: Sem registro de hóspedes nem emissão de chaves pelo PMS via API REST (KF2). Só afeta hotéis que usam essa interface. |
| `ambiance.pmsws` | Ambiance PMS WS | `MessengerNet PMSWS.Host` | 80 (HTTP), 443 (HTTPS) | **WARNING** | Web service SOAP da API dormakaba LGS para o PMS. Se parar: Sem registro de hóspedes nem emissão de chaves pelo PMS via API SOAP LGS. Só afeta hotéis que usam essa interface. |
| `ambiance.skytouch` | Ambiance PMS Skytouch | `PMS.SkyTouch.Service` | 5020 (HTTP), 5021 (HTTPS) | **WARNING** | Interface com o PMS SkyTouch. Se parar: Sem registro de hóspedes nem emissão de chaves pelo SkyTouch. Só afeta hotéis que usam esse PMS. |

#### Gestão remota de fechaduras (online) (`subcomponent: online`)

| Item | Serviço Windows | Processo | Porta(s) | Severidade | Função e impacto |
|---|---|---|---|---|---|
| `ambiance.hubgateway` | Ambiance HubGateway | `HubGatewayService.Host` | 27000/27700, 27701 (saída) | **AVERAGE** | Leva os comandos da Web API às fechaduras online por gateways (GWYI, GWYII, Control4) e pelo serviço VHE. Se parar: Sem gestão remota das fechaduras ligadas por gateway, Control4, INNCOM, Telkonet ou INTEREL. As fechaduras continuam abrindo com as chaves já emitidas. |
| `ambiance.hubmanager` | Ambiance HubManager | `Kaba.Bus.HubManager.Service.Host` | 9000 | **AVERAGE** | Gerencia a comunicação remota com as fechaduras online, por todos os dispositivos e interfaces, incluindo os gateways. Se parar: Sem gestão remota de nenhuma fechadura online (comandos, eventos e status em tempo real). As fechaduras continuam abrindo com as chaves já emitidas. |
| `ambiance.vhe` | Ambiance VHE Service | `VHEService.Host` | 6099, 6007, 6006/5020 | **WARNING** | Comunicação remota com fechaduras por sistemas de automação de quarto de terceiros (INNCOM, INTEREL, Telkonet); recebe os comandos pelo HubGateway. Se parar: Sem comunicação remota com fechaduras via INNCOM, INTEREL ou Telkonet. Só afeta hotéis com essas integrações. |

#### Integrações opcionais (`subcomponent: integration`)

| Item | Serviço Windows | Processo | Porta(s) | Severidade | Função e impacto |
|---|---|---|---|---|---|
| `ambiance.aurorasync` | Ambiance AuroraSync | `Kaba.AuroraSync.Service` | — | **WARNING** | Sincroniza as credenciais de hóspedes e funcionários com o servidor dormakaba Keyscan Aurora (controle de acesso de perímetro); recurso licenciado. Se parar: As credenciais deixam de sincronizar com os pontos de acesso Keyscan. Só afeta hotéis com essa integração. |
| `ambiance.matrixsyncmanager` | Ambiance MatrixSync | `Bus.MatrixSyncManager.Service.Host` | 5030 | **WARNING** | Sincroniza as credenciais de hóspedes e funcionários com o servidor dormakaba MATRIX (controle de acesso de perímetro). Se parar: As credenciais deixam de sincronizar com os pontos de acesso MATRIX. Só afeta hotéis com essa integração. |
| `ambiance.mobilekeydelivery` | Ambiance MobileKeyDeliveryService | `MobileKeyDeliveryService` | 8299 | **WARNING** | Emite chaves móveis (BLE e Apple Wallet), entregues pela plataforma LEGIC; recurso licenciado. Se parar: Não são emitidas chaves móveis. Só afeta hotéis com o recurso de chave no celular. |

#### Apoio (`subcomponent: management`)

| Item | Serviço Windows | Processo | Porta(s) | Severidade | Função e impacto |
|---|---|---|---|---|---|
| `ambiance.servicemanagerapi` | Ambiance Service Manager API | `DokaServiceManager.Service.API` | 9097 (Watchdog) | **INFO** | Processo de apoio do Service Manager do Ambiance, a ferramenta que inicia e para serviços e faz a verificação periódica de saúde (Watchdog). Provavelmente é o serviço Windows "Ambiance Watchdog"; a associação não foi confirmada no servidor. Se parar: Sem a verificação automática de saúde dos serviços. Nada para de funcionar para a recepção. |

---

### Itens — Backup

O job do SQL Server (instância `AMBIANCE`) grava um arquivo por dia da semana, em rodízio, em `C:\Program Files\Microsoft SQL Server\MSSQL16.AMBIANCE\MSSQL\Backup\`. Se a sua pasta for outra, ajuste o caminho no arquivo de UserParameters.

| Item | O que retorna |
|---|---|
| `ambiance.backup.age_hours` | Horas desde a gravação do backup mais recente (-1 se não houver arquivo) |
| `ambiance.backup.size` | Tamanho do backup mais recente, em bytes |
| `ambiance.backup.total_size` | Soma do tamanho dos 7 arquivos do rodízio |
| `ambiance.backup.file_count` | Quantidade de arquivos do rodízio |
| `ambiance.backup.latest_file` | Nome do arquivo mais recente |
| `ambiance.backup.latest_time` | Data e hora do arquivo mais recente |

| Trigger | Severidade | Item |
|---|---|---|
| Ambiance - Backup CRÍTICO (mais de {$AMBIANCE.BACKUP.AGE.DISASTER} horas sem backup) | DISASTER | `ambiance.backup.age_hours` |
| Ambiance - Nenhum arquivo de backup encontrado | DISASTER | `ambiance.backup.age_hours` |
| Ambiance - Backup com tamanho suspeito (abaixo do mínimo) | WARNING | `ambiance.backup.size` |
| Ambiance - Backup desatualizado (mais de {$AMBIANCE.BACKUP.AGE.WARN} horas) | WARNING | `ambiance.backup.age_hours` |
| Ambiance - Tamanho do backup diminuiu significativamente | WARNING | `ambiance.backup.size` |
| Ambiance - Faltam arquivos de backup (menos de {$AMBIANCE.BACKUP.EXPECTED_FILES}) | INFO | `ambiance.backup.file_count` |

---

### Macros

| Macro | Padrão | Descrição |
|---|---|---|
| `{$AMBIANCE.BACKUP.AGE.DISASTER}` | `48` | Idade do backup mais recente, em horas, para gerar DISASTER. Número puro, sem sufixo. |
| `{$AMBIANCE.BACKUP.AGE.WARN}` | `24` | Idade do backup mais recente, em horas, para gerar WARNING. Número puro, sem sufixo. |
| `{$AMBIANCE.BACKUP.EXPECTED_FILES}` | `7` | Quantidade esperada de arquivos de backup (um por dia da semana). |
| `{$AMBIANCE.BACKUP.MIN_SIZE}` | `10485760` | Tamanho mínimo aceitável do backup mais recente, em bytes (padrão: 10 MB). Ajuste por host conforme o tamanho real do banco. |
| `{$AMBIANCE.BACKUP.SIZE_DROP}` | `10485760` | Queda de tamanho entre backups, em bytes, para gerar alerta (padrão: 10 MB). |
| `{$AMBIANCE.SERVICE.CHECK_INTERVAL}` | `3m` | Intervalo de checagem dos serviços do Ambiance. |

As macros `AGE.*` são comparadas com um item em horas: use número puro, sem sufixo de tempo.

---

### O que este Template não Cobre

- `RabbitMQ`, `Redis`, `MongoDB` e `SQL Server (AMBIANCE)`: param todo o sistema (ou toda a parte online, no caso do MongoDB) e não têm item aqui. Use a descoberta de serviços do template `Windows by Zabbix agent active`.
- Se esse template Windows estiver no mesmo host, ele também descobre os serviços `Ambiance *` e alerta em dobro. Para ficar só com este template, acrescente `Ambiance (?!Watchdog$).+|AmbianceClient` em `{$SERVICE.NAME.NOT_MATCHES}` no host.
- O serviço `Ambiance Watchdog` não tem item próprio. O processo `DokaServiceManager.Service.API` provavelmente é ele, mas a associação não foi confirmada.

---

### Instalação

1. Copie `user_parameters_ambiance.conf` para `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` no servidor do Ambiance.
2. Reinicie o serviço **Zabbix Agent 2**.
3. Importe `template.json` em **Coleta de dados → Templates → Importar** e vincule ao host.
4. Ajuste `{$AMBIANCE.BACKUP.MIN_SIZE}` ao tamanho real do seu backup.

---

### Fontes

- [Ambiance services](https://ambiance-demo-amer.dormakaba.com/Help/ambiance/en/Content/Troubleshooting/Services.htm)
- [Troubleshooting services](https://ambiance-demo-amer.dormakaba.com/Help/ambiance/en/Content/Troubleshooting/ugTroubleshootingServices.htm)
- [Service Manager](https://ambiance-demo-amer.dormakaba.com/Help/ambiance/en/Content/Troubleshooting/ServiceManager.htm)

As páginas são da ajuda de um ambiente de demonstração da dormakaba; portas e detalhes podem variar conforme a versão instalada.

---

### Changelog

| Versão | Mudanças |
|---|---|
| 1.2 | Primeira versão pública. Severidade por impacto e descrição da função de cada serviço |

---

<a id="en-us"></a>
## 🇺🇸 English

Template for the **dormakaba Ambiance** server, the hotel lock management system. It monitors the 21 Ambiance services and the SQL Server database backup, with each alert's severity set by the real impact of the service.

Not an official dormakaba product. Item and trigger texts inside the template are in Brazilian Portuguese.

---

### What Is Monitored

- **Services** — 21 items, one per service, checked by process presence (1 = running, 0 = stopped), each with its own trigger.
- **Backup** — age, size, count and name of the `AMBIANCE-Backup-[1-7].bak` files written by the SQL Server job, with 6 triggers.

Total: 27 items, 27 triggers, 6 macros.

---

### Severity Criteria

| Severity | When | Services |
|---|---|---|
| DISASTER | The whole system stops | Server, Web API, Database Engine |
| HIGH | The front desk cannot write or read cards | Encoder Service, AmbianceClient |
| AVERAGE | A whole function stops, but manual key issuing still works | PMS Agent, HubManager, HubGateway |
| WARNING | Interface or integration that only affects those who use it | Other PMS interfaces, VHE, mobile key, AuroraSync, MatrixSync |
| INFO | Nothing stops working for the hotel | Service Manager / Watchdog |

According to dormakaba, all services run at all times, even those for features the hotel does not use. A stopped interface service therefore deserves an alert, but a low one. If your hotel uses a specific PMS interface (FIAS, LGS, BART etc.), raise its severity.

---

### Items — Services

#### Core (`subcomponent: core`)

| Item | Windows service | Process | Port(s) | Severity | Function and impact |
|---|---|---|---|---|---|
| `ambiance.databaseengine` | Ambiance Database Engine | `Bus.DatabaseEngine.Service.Host` | 5040 | **DISASTER** | Data layer: stores, retrieves and organizes Ambiance data in SQL Server. If it stops: The whole system stops: nothing that depends on data works. |
| `ambiance.server` | Ambiance Server | `KabaService` | 49999 | **DISASTER** | Main service: coordinates all the others and runs the internal Bus services as parallel tasks. If it stops: The whole system stops: keys cannot be issued or read and integrations stop responding. |
| `ambiance.webapi` | Ambiance Web API | `Kaba.Web.Gateway.API` | 26265 (HTTP), 443 (HTTPS) | **DISASTER** | API gateway: receives requests from the Ambiance UI and from field services (workstation client and hub gateway). If it stops: The whole system stops: the Ambiance UI stops working on workstations. |
| `ambiance.client` | AmbianceClient | `DokaClient` | 40100 | **HIGH** | Encodes and reads RFID keys on USB encoders and talks to the Maintenance Unit attached to this machine. If it stops: Cards cannot be written or read on this machine's USB encoders, and the Maintenance Unit is unavailable. |
| `ambiance.encoder` | Ambiance Encoder Service | `Encoder.Service.Host` | 28000 (HTTP), 28001 (HTTPS) | **HIGH** | Encodes and reads RFID keys on network (TCP/IP) encoders. If it stops: Cards cannot be written or read on network encoders; the front desk cannot issue keys through them. |

#### PMS integration (`subcomponent: pms`)

| Item | Windows service | Process | Port(s) | Severity | Function and impact |
|---|---|---|---|---|---|
| `ambiance.pmsagent` | Ambiance PMS Agent | `Kaba.PMS.Agent.Host` | 9595, 9596 | **AVERAGE** | Receives guest registrations and key requests from the property management system (PMS) and delivers them to the Bus. Serves every PMS interface except IRS and PRS. If it stops: The PMS stops registering guests and issuing keys automatically (except through IRS/PRS). Manual issuing from the Ambiance UI still works. |
| `ambiance.bart` | Ambiance PMS BART | `PMS.BART.Service.Host` | 9898 | **WARNING** | dormakaba BART PMS interface (web service). If it stops: No PMS registration or key issuing through BART. Only affects hotels using that interface. |
| `ambiance.pmsfias` | Ambiance PMS FIAS | `Kaba.PMS.FIAS.SocketService.Host` | 8265 | **WARNING** | TCP listener for the Oracle FIAS interface (used by Opera and compatible PMS). If it stops: No PMS registration or key issuing through FIAS. Only affects hotels using that interface. |
| `ambiance.pmsirsagent` | Ambiance PMS IRSPRS Agent | `Kaba.PMS.IRS.Agent.Host` | 9696 | **WARNING** | Delivers to the Bus the guest registrations and key requests coming from the dormakaba IRS and PRS interfaces. If it stops: No PMS registration or key issuing through IRS/PRS. Only affects hotels using those interfaces. |
| `ambiance.pmsirssocket` | Ambiance PMS IRSPRS | `Kaba.PMS.IRS.SocketService.Host` | 8264 | **WARNING** | TCP listener for the dormakaba IRS and PRS interfaces; talks to the PMS, including over serial (RS232). If it stops: No PMS registration or key issuing through IRS/PRS. Only affects hotels using those interfaces. |
| `ambiance.pmslgs` | Ambiance PMS LGS API | `PMS.LGS.API` | 5120 (HTTP), 5121 (HTTPS) | **WARNING** | dormakaba LGS REST API for the PMS. If it stops: No PMS registration or key issuing through the LGS REST API. Only affects hotels using that interface. |
| `ambiance.pmsrestapi` | Ambiance PMS REST API | `dkLockServerApiWs` | 9090 | **WARNING** | dormakaba LGS REST API for the PMS, KF2 variant. If it stops: No PMS registration or key issuing through the REST API (KF2). Only affects hotels using that interface. |
| `ambiance.pmsws` | Ambiance PMS WS | `MessengerNet PMSWS.Host` | 80 (HTTP), 443 (HTTPS) | **WARNING** | SOAP web service of the dormakaba LGS API for the PMS. If it stops: No PMS registration or key issuing through the LGS SOAP API. Only affects hotels using that interface. |
| `ambiance.skytouch` | Ambiance PMS Skytouch | `PMS.SkyTouch.Service` | 5020 (HTTP), 5021 (HTTPS) | **WARNING** | Interface with the SkyTouch PMS. If it stops: No registration or key issuing from SkyTouch. Only affects hotels using that PMS. |

#### Remote lock management (online) (`subcomponent: online`)

| Item | Windows service | Process | Port(s) | Severity | Function and impact |
|---|---|---|---|---|---|
| `ambiance.hubgateway` | Ambiance HubGateway | `HubGatewayService.Host` | 27000/27700, 27701 (outbound) | **AVERAGE** | Carries Web API commands to online locks through gateways (GWYI, GWYII, Control4) and the VHE service. If it stops: No remote management of locks connected through gateways, Control4, INNCOM, Telkonet or INTEREL. Locks keep opening with keys already issued. |
| `ambiance.hubmanager` | Ambiance HubManager | `Kaba.Bus.HubManager.Service.Host` | 9000 | **AVERAGE** | Manages remote communication with online locks across all devices and interfaces, including gateways. If it stops: No remote management of any online lock (commands, events, real-time status). Locks keep opening with keys already issued. |
| `ambiance.vhe` | Ambiance VHE Service | `VHEService.Host` | 6099, 6007, 6006/5020 | **WARNING** | Remote lock communication through third-party room automation systems (INNCOM, INTEREL, Telkonet); receives commands from HubGateway. If it stops: No remote lock communication through INNCOM, INTEREL or Telkonet. Only affects hotels with those integrations. |

#### Optional integrations (`subcomponent: integration`)

| Item | Windows service | Process | Port(s) | Severity | Function and impact |
|---|---|---|---|---|---|
| `ambiance.aurorasync` | Ambiance AuroraSync | `Kaba.AuroraSync.Service` | — | **WARNING** | Syncs guest and staff credentials with the dormakaba Keyscan Aurora server (perimeter access control); licensed feature. If it stops: Credentials stop syncing with Keyscan access points. Only affects hotels with that integration. |
| `ambiance.matrixsyncmanager` | Ambiance MatrixSync | `Bus.MatrixSyncManager.Service.Host` | 5030 | **WARNING** | Syncs guest and staff credentials with the dormakaba MATRIX server (perimeter access control). If it stops: Credentials stop syncing with MATRIX access points. Only affects hotels with that integration. |
| `ambiance.mobilekeydelivery` | Ambiance MobileKeyDeliveryService | `MobileKeyDeliveryService` | 8299 | **WARNING** | Issues mobile keys (BLE and Apple Wallet), delivered through the LEGIC platform; licensed feature. If it stops: No mobile keys are issued. Only affects hotels using mobile keys. |

#### Support (`subcomponent: management`)

| Item | Windows service | Process | Port(s) | Severity | Function and impact |
|---|---|---|---|---|---|
| `ambiance.servicemanagerapi` | Ambiance Service Manager API | `DokaServiceManager.Service.API` | 9097 (Watchdog) | **INFO** | Support process of the Ambiance Service Manager, the tool that starts and stops services and runs the periodic health check (Watchdog). Probably the "Ambiance Watchdog" Windows service; not confirmed. If it stops: No automatic service health check. Nothing stops working for the front desk. |

---

### Items — Backup

The SQL Server job (instance `AMBIANCE`) writes one file per weekday, in rotation, to `C:\Program Files\Microsoft SQL Server\MSSQL16.AMBIANCE\MSSQL\Backup\`. If your folder differs, change the path in the UserParameters file.

| Item | Returns |
|---|---|
| `ambiance.backup.age_hours` | Hours since the newest backup file was written (-1 if none found) |
| `ambiance.backup.size` | Size of the newest backup, in bytes |
| `ambiance.backup.total_size` | Total size of the 7 rotation files |
| `ambiance.backup.file_count` | Number of files in the rotation |
| `ambiance.backup.latest_file` | Name of the newest file |
| `ambiance.backup.latest_time` | Write time of the newest file |

| Trigger | Severity | Item |
|---|---|---|
| Ambiance - Backup CRITICAL (more than {$AMBIANCE.BACKUP.AGE.DISASTER} hours without a backup) | DISASTER | `ambiance.backup.age_hours` |
| Ambiance - No backup file found | DISASTER | `ambiance.backup.age_hours` |
| Ambiance - Backup outdated (more than {$AMBIANCE.BACKUP.AGE.WARN} hours) | WARNING | `ambiance.backup.age_hours` |
| Ambiance - Backup size dropped significantly | WARNING | `ambiance.backup.size` |
| Ambiance - Backup with suspicious size (below minimum) | WARNING | `ambiance.backup.size` |
| Ambiance - Backup files missing (fewer than {$AMBIANCE.BACKUP.EXPECTED_FILES}) | INFO | `ambiance.backup.file_count` |

---

### Macros

| Macro | Default | Description |
|---|---|---|
| `{$AMBIANCE.BACKUP.AGE.DISASTER}` | `48` | Age of the newest backup, in hours, for DISASTER. Plain number, no suffix. |
| `{$AMBIANCE.BACKUP.AGE.WARN}` | `24` | Age of the newest backup, in hours, for WARNING. Plain number, no suffix. |
| `{$AMBIANCE.BACKUP.EXPECTED_FILES}` | `7` | Expected number of backup files (one per weekday). |
| `{$AMBIANCE.BACKUP.MIN_SIZE}` | `10485760` | Minimum acceptable size of the newest backup, in bytes (default: 10 MB). Adjust per host to the real database size. |
| `{$AMBIANCE.BACKUP.SIZE_DROP}` | `10485760` | Size drop between backups, in bytes, that raises an alert (default: 10 MB). |
| `{$AMBIANCE.SERVICE.CHECK_INTERVAL}` | `3m` | Check interval for the Ambiance services. |

The `AGE.*` macros are compared against an item in hours: use a plain number, no time suffix.

---

### What This Template Does Not Cover

- `RabbitMQ`, `Redis`, `MongoDB` and `SQL Server (AMBIANCE)`: they stop the whole system (or all online features, for MongoDB) and have no item here. Use the service discovery of the `Windows by Zabbix agent active` template.
- If that Windows template is on the same host, it also discovers the `Ambiance *` services and alerts twice. To keep only this template's alerts, add `Ambiance (?!Watchdog$).+|AmbianceClient` to `{$SERVICE.NAME.NOT_MATCHES}` on the host.
- The `Ambiance Watchdog` service has no item of its own. The `DokaServiceManager.Service.API` process is probably it, but this was not confirmed.

---

### Installation

1. Copy `user_parameters_ambiance.conf` to `C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\` on the Ambiance server.
2. Restart the **Zabbix Agent 2** service.
3. Import `template.json` under **Data collection → Templates → Import** and link it to the host.
4. Set `{$AMBIANCE.BACKUP.MIN_SIZE}` to your real backup size.

---

### Sources

- [Ambiance services](https://ambiance-demo-amer.dormakaba.com/Help/ambiance/en/Content/Troubleshooting/Services.htm)
- [Troubleshooting services](https://ambiance-demo-amer.dormakaba.com/Help/ambiance/en/Content/Troubleshooting/ugTroubleshootingServices.htm)
- [Service Manager](https://ambiance-demo-amer.dormakaba.com/Help/ambiance/en/Content/Troubleshooting/ServiceManager.htm)

These pages belong to the help of a dormakaba demo environment; ports and details may vary with the installed version.

---

### Changelog

| Version | Changes |
|---|---|
| 1.2 | First public release. Severity by impact and a description of each service's function |

---

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

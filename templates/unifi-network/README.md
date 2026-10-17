# UniFi Network by API

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-D40000?style=flat-square&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0-7F13EC?style=flat-square)
![Collection](https://img.shields.io/badge/Collection-SCRIPT_(UniFi_API_key)-009639?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production-brightgreen?style=flat-square)

[🇧🇷 Português](#pt-br) · [🇺🇸 English](#en-us)

---

<a id="pt-br"></a>
## 🇧🇷 Português

Template Zabbix para o **UniFi Network** (aplicação Network 10.x) com **chave de API**: funciona com o UniFi OS (console UniFi ou UniFi OS Server) e com a Network Application standalone (Docker/Linux). Foi feito para Wi-Fi com reclamação de usuários, como hotéis e escritórios: mostra onde a rede está ruim e por quê.

**Coleta:** dois itens mestres do tipo Script.

- `unifi.devices.get`, a cada 1 min: APs, rádios, redes Wi-Fi e clientes.
- `unifi.site.get`, a cada 5 min: controller, conexões das últimas 24 h, experiência dos clientes, otimizações sugeridas e redes vizinhas.

A mesma chave dá acesso às APIs de integração (v1), clássica (`/api/s/<site>`) e v2. O template tem três descobertas: APs (por MAC), rádios (por AP e faixa) e redes Wi-Fi (por SSID). São 61 itens do site, 17 triggers do site e 13 protótipos de trigger, todos com tags `component`/`scope` e descrição do que fazer.

**Privacidade (LGPD):** só agregados. Nenhum MAC, IP ou nome de aparelho de usuário é gravado. O JSON de saída é montado campo a campo, porque `stat/device` traz segredos do controller.

### O que mede

- **APs:** estado, modelo, fim de vida (EOL), firmware, CPU e memória, clientes, satisfação, sinal médio dos clientes, porta de rede (velocidade negociada × máxima, tráfego, erros).
- **Rádios:** canal, largura, potência, uso do canal, interferência externa, retransmissões, clientes.
- **Redes Wi-Fi:** faixas, segurança, PMF, roaming rápido (802.11r), BSS transition, taxa mínima, clientes e satisfação.
- **Site:**
  - APs fora do ar ou fora de linha, e APs dual-band com a rede só em 2,4 GHz.
  - Clientes por faixa, com sinal fraco ou em padrão antigo.
  - Taxa de sucesso das conexões e tempo para conectar (associação, autenticação, DHCP).
  - Sessões com experiência boa, regular ou ruim.
  - Redes vizinhas fortes por canal (1/6/11).

### Pré-requisitos

1. Escolha como o Zabbix vai se autenticar no controller:
   - **UniFi OS** (console UniFi ou UniFi OS Server): vá em **Settings → Control Plane → Integrations → API Keys**, crie uma chave e copie-a, porque ela não aparece de novo.
   - **Network Application standalone:** esse menu não existe, porque a tela de chaves é do UniFi OS. Em **Settings → Admins**, crie um usuário local com o papel **View Only**.
2. No Zabbix, crie um host por site do controller, com uma interface no IP do controller.
3. Vincule o template e defina no host:
   - **UniFi OS:** `{$UNIFI.API.KEY}` como texto secreto.
   - **Standalone:** `{$UNIFI.USER}`, e `{$UNIFI.PASSWORD}` como texto secreto.
4. Ajuste `{$UNIFI.PORT}` e `{$UNIFI.API.PREFIX}` conforme a tabela abaixo.

| Controller | `{$UNIFI.PORT}` | `{$UNIFI.API.PREFIX}` |
|---|---|---|
| UniFi OS Server | `11443` | `/proxy/network` |
| Console UniFi (UDM, UCG, Cloud Key…) | `443` | `/proxy/network` |
| Network Application standalone | `8443` (ou a porta HTTPS configurada) | vazio |

### Macros principais

| Macro | Padrão | Descrição |
|---|---|---|
| `{$UNIFI.API.KEY}` | — | Chave de API (secreta) |
| `{$UNIFI.USER}` / `{$UNIFI.PASSWORD}` | — | Usuário View Only e senha (secreta), só na standalone sem chave |
| `{$UNIFI.SCHEME}` / `{$UNIFI.PORT}` | `https` / `11443` | Endereço da interface |
| `{$UNIFI.API.PREFIX}` | `/proxy/network` | Vazio na standalone |
| `{$UNIFI.SITE}` | `default` | Site do controller |
| `{$UNIFI.AP.EOL.ALERT}` | `1` | `0` desliga o alerta por AP fora de linha (a contagem continua em `unifi.aps.eol`) |
| `{$UNIFI.RADIO.CU.MAX}` / `.INTERFERENCE.MAX` / `.RETRIES.MAX` | `70` / `40` / `20` | Limites por rádio (%) |
| `{$UNIFI.AP.SATISFACTION.MIN}` / `{$UNIFI.SITE.SATISFACTION.MIN}` | `70` / `75` | Satisfação mínima |
| `{$UNIFI.CLIENT.SIGNAL.WEAK}` / `{$UNIFI.CLIENTS.WEAK.PCT.MAX}` | `-70` / `30` | Sinal fraco (dBm) e % máxima de clientes com sinal fraco |
| `{$UNIFI.EXPERIENCE.POOR.MAX}` | `20` | % máxima de sessões ruins em 24 h |
| `{$UNIFI.APS.OFFLINE.DISASTER}` | `3` | APs fora do ar para alerta de desastre |

### Triggers

- **Validado em:** UniFi OS Server 5.1 com Network 10.6. Na Network Application standalone os caminhos da API foram conferidos, mas a coleta ainda não foi validada.
- **Todos têm a tag `glpi: nao`**, para quem usa integração com helpdesk e não quer chamado por Wi-Fi: basta excluir a tag na ação.
- **Todos aceitam fechamento manual.**
- **Os de qualidade têm recuperação com folga** (histerese) para não oscilar perto do limite: CPU, memória, clientes e satisfação por AP; canal, interferência e retransmissões por rádio; e, no site, experiência, sinal fraco, satisfação e vizinhança.
- **Destaques:**
  - Desastre: vários APs fora do ar.
  - Alta: AP fora do ar e interface HTTPS sem resposta.
  - Atenção: Wi-Fi só em 2,4 GHz com APs de 5 GHz disponíveis, e porta de rede abaixo da capacidade.
  - Atenção: retransmissões ou interferência altas, e experiência ruim.
  - Info: modelo fora de linha, firmware para atualizar e otimizações pendentes.

---

<a id="en-us"></a>
## 🇺🇸 English

Zabbix template for **UniFi Network** (Network application 10.x) using an **API key**. It works with UniFi OS (UniFi consoles or UniFi OS Server) and with the standalone Network Application (Docker/Linux). It was built for Wi-Fi with user complaints, such as hotels and offices: it shows where the network is bad and why.

**Collection:** two Script master items.

- `unifi.devices.get`, every 1 min: APs, radios, WLANs and clients.
- `unifi.site.get`, every 5 min: controller, last-24 h connections, client experience, Wi-Fi AI suggestions and neighboring networks.

One key covers the Integration (v1), classic (`/api/s/<site>`) and v2 APIs. The template has three discoveries: APs (by MAC), radios (by AP and band) and WLANs (by SSID). It has 61 site items, 17 site triggers and 13 trigger prototypes, all tagged with `component`/`scope` and with operator guidance.

**Privacy:** aggregates only. No client MAC, IP or device name is stored. The output JSON is built field by field, because `stat/device` contains controller secrets.

### Setup

1. Choose how Zabbix authenticates to the controller:
   - **UniFi OS** (UniFi console or UniFi OS Server): go to **Settings → Control Plane → Integrations → API Keys**, then create a key and copy it, because it is shown only once.
   - **Standalone Network Application:** that menu doesn't exist, because the API key screen belongs to UniFi OS. In **Settings → Admins**, create a local **View Only** user.
2. In Zabbix, create one host per controller site, with an interface on the controller IP.
3. Link the template and set on the host:
   - **UniFi OS:** `{$UNIFI.API.KEY}` as secret text.
   - **Standalone:** `{$UNIFI.USER}`, and `{$UNIFI.PASSWORD}` as secret text.
4. Set `{$UNIFI.PORT}` and `{$UNIFI.API.PREFIX}`:
   - UniFi OS Server: `11443`, `/proxy/network`.
   - UniFi console: `443`, `/proxy/network`.
   - Standalone Network Application: `8443` (or your HTTPS port), empty prefix.

`{$UNIFI.AP.EOL.ALERT}=0` disables the per-AP end-of-life alert; the count stays in `unifi.aps.eol`.

Validated on UniFi OS Server 5.1 with Network 10.6; on the standalone Network Application the API paths were checked, but collection is not validated yet. All triggers carry the tag `glpi: nao` (exclude it in your helpdesk action) and can be closed manually. Quality triggers use recovery expressions with hysteresis, so they don't flap around the threshold.

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Zabbix NFe Monitor — scraping da página de disponibilidade da NF-e SEFAZ.

Uso:
    nfe_status.py --json        JSON completo por autorizador (item mestre)
    nfe_status.py --discovery   LLD [{"{#AUTORIZADOR}": ...}] (teste manual;
                                o template usa LLD dependente do item mestre)

Status das bolas: verde=1, amarela=2, vermelha=0, sem imagem=-1.
Em caso de falha de coleta: mensagem no stderr e exit 1 (item vira
NOTSUPPORTED no Zabbix; trigger nodata() no item mestre cobre o cenário).
"""

import sys
import json
import argparse
import requests
from bs4 import BeautifulSoup

# TLS é validado normalmente: a raiz ISRG Root YR (hierarquia Gen Y da Let's
# Encrypt, usada pela SEFAZ mas ausente dos trust stores) é instalada no store
# do container pela imagem custom (Dockerfiles/zabbix-agent2).
URL = "https://www.nfe.fazenda.gov.br/portal/disponibilidade.aspx"

# Ordem das colunas na tabela "tabelaListagemDados" (após "Autorizador").
# "Tempo Médio" (índice 6) é texto, não imagem — tratado à parte.
SERVICOS = [
    "autorizacao",
    "retorno_autorizacao",
    "inutilizacao",
    "consulta_protocolo",
    "status_servico",
    "tempo_medio",
    "consulta_cadastro",
    "recepcao_evento",
]
COL_TEMPO_MEDIO = SERVICOS.index("tempo_medio")


def get_status_from_image(img_tag):
    """Status: verde=1, amarela=2, vermelha=0, sem imagem=-1"""
    if not img_tag or not img_tag.has_attr('src'):
        return -1
    src = img_tag['src'].lower()
    if "verde" in src:
        return 1
    elif "amarela" in src:
        return 2
    elif "vermelh" in src:
        # prefixo cobre "vermelho"/"vermelha" — a imagem real é bola_vermelho_P.png
        return 0
    return -1


def scrape_nfe():
    session = requests.Session()
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
    }

    # O portal redireciona (AspxAutoDetectCookieSupport); a Session trata o cookie
    response = session.get(URL, headers=headers, timeout=15)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, 'html.parser')
    table = soup.find('table', class_='tabelaListagemDados')
    if not table:
        raise ValueError("tabela 'tabelaListagemDados' nao encontrada na pagina")

    data = {}
    for row in table.find_all('tr'):
        cols = row.find_all('td')
        if len(cols) < len(SERVICOS) + 1:
            continue  # cabeçalho (<th>) ou linha incompleta

        autorizador = cols[0].text.strip()
        if not autorizador:
            continue

        status = {}
        for i, servico in enumerate(SERVICOS, start=1):
            if i - 1 == COL_TEMPO_MEDIO:
                status[servico] = cols[i].text.strip()  # "-" ou valor em texto
            else:
                status[servico] = get_status_from_image(cols[i].find('img'))
        data[autorizador] = status

    if not data:
        raise ValueError("nenhum autorizador extraido da tabela")
    return data


def main():
    parser = argparse.ArgumentParser(description='Zabbix NFe Monitor')
    parser.add_argument('--json', action='store_true', help='JSON completo por autorizador')
    parser.add_argument('--discovery', action='store_true', help='Saída LLD para Zabbix')
    args = parser.parse_args()

    try:
        data = scrape_nfe()
    except Exception as e:
        print(f"erro na coleta SEFAZ: {e}", file=sys.stderr)
        sys.exit(1)

    if args.discovery:
        print(json.dumps([{"{#AUTORIZADOR}": k} for k in data]))
    else:
        print(json.dumps(data, ensure_ascii=False))


if __name__ == '__main__':
    main()

FROM zabbix/zabbix-agent2:alpine-7.4-latest

USER root

# Python para os scripts de UserParameter (nfe_status.py).
# Pacotes via apk: pip falha no Alpine >= 3.19 (PEP 668 externally-managed).
#
# ISRG Root YR: a SEFAZ (www.nfe.fazenda.gov.br) usa a hierarquia Gen Y da
# Let's Encrypt, cuja raiz ainda nao esta nos trust stores — sem ela o
# verify TLS do nfe_status.py falha. Ver isrg-root-yr.crt para proveniencia.
COPY Dockerfiles/zabbix-agent2/isrg-root-yr.crt /usr/local/share/ca-certificates/isrg-root-yr.crt
RUN apk add --no-cache python3 py3-requests py3-beautifulsoup4 ca-certificates \
    && update-ca-certificates

# Usuário padrão zabbix da imagem oficial
USER 1997

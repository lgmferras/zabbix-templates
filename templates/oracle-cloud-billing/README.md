# Oracle Cloud Billing

**Category:** Cloud / Cost  
**Collection method:** HTTP (OCI Usage API)  
**Items:** 2  
**Zabbix version:** 7.4+

## Description

Current-month OCI billing cost via Usage Reports API. Alerts on unexpected charges for Always Free tenants.

## Requirements

- Zabbix Server 7.4+
- HTTP (OCI Usage API) configured on the monitored host

## Import

1. Go to **Configuration → Templates**
2. Click **Import**
3. Select `template.json`
4. Click **Import**

## Macros

Configure the following host macros after importing:

> See the template description inside `template.json` for the full macro list and default values.

## Author

Luis Gustavo Ferras — [Systrix Tecnologia](https://systrix.com.br/)  
[lgmferras](https://github.com/lgmferras) · [LinkedIn](https://www.linkedin.com/in/lgmferras)

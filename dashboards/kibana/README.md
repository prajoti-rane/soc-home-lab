# Kibana Dashboards

Custom Kibana dashboard exports for this SOC lab.

## Importing a Dashboard

```bash
# [host] Import dashboard via Kibana API
curl -k -X POST "https://192.168.64.10:5601/api/saved_objects/_import" \
  -H "kbn-xsrf: true" \
  -H "Authorization: Basic $(echo -n 'admin:PASSWORD' | base64)" \
  --form file=@dashboards/kibana/soc-lab-overview.ndjson
```

## Dashboard Index (Phase 3+)

| Dashboard | File | Description |
|-----------|------|-------------|
| SOC Lab Overview | `soc-lab-overview.ndjson` | Alert timeline, agent status, severity heatmap |
| MITRE ATT&CK Coverage | `mitre-coverage.ndjson` | ATT&CK matrix with alert counts per technique |
| Sliver C2 Monitor | `sliver-c2.ndjson` | Outbound HTTPS connections, DNS queries from victim |
| Credential Access | `credential-access.ndjson` | LSASS access, SAM database access alerts |
| Persistence Tracker | `persistence.ndjson` | Registry Run Key, scheduled task, service creation alerts |

## Exporting a Dashboard

1. Open Kibana → Stack Management → Saved Objects
2. Select the dashboard(s) to export
3. Click Export → include related objects
4. Save the `.ndjson` file to this directory

## Pre-Built Wazuh Dashboards

The Wazuh app in Kibana includes pre-built dashboards for:
- Security events overview
- Agent inventory
- Policy monitoring (SCA)
- Vulnerability detection
- MITRE ATT&CK (basic)

Access them at: `https://192.168.64.10:5601` → Wazuh → Modules

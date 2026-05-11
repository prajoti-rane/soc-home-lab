# Sigma Detection Rules

Sigma is a vendor-agnostic YAML format for SIEM detection rules. Every Wazuh rule in this lab has a Sigma equivalent, enabling the same detection logic to be deployed to Splunk, Microsoft Sentinel, QRadar, or Elastic SIEM without rewriting.

## Why Sigma?

- **Portability** — write once, convert to any SIEM backend
- **Interview signal** — demonstrates SIEM-agnostic thinking expected at FAANG security roles
- **Industry standard** — MITRE, CISA, and most MSSP threat intel feeds publish Sigma rules

## Rule Inventory

| File | Rule IDs (Wazuh equiv.) | MITRE | Technique |
|------|------------------------|-------|-----------|
| `sigma-100001-brute-force-ssh.yml` | 100001–100002 | T1110.001 | SSH password brute-force + success |
| `sigma-100003-brute-force-rdp.yml` | 100003–100004 | T1110.001, T1021.001 | RDP EventID 4625 brute-force + success |
| `sigma-100005-credential-dumping-lsass.yml` | 100005 | T1003.001 | Sysmon EID 10 LSASS access |
| `sigma-100006-suspicious-powershell.yml` | 100006–100008 | T1059.001, T1027 | Encoded/bypass PowerShell + suspicious parent |
| `sigma-100009-c2-beaconing.yml` | 100009–100011 | T1071.001, T1036.005 | Repeated outbound connections from writable path |
| `sigma-100012-lateral-movement-psexec.yml` | 100012–100013 | T1021.002, T1570 | PsExec service install + suspicious binary path |
| `sigma-100015-defender-tampering.yml` | 100015–100016 | T1562.001 | Registry tamper + Set-MpPreference |
| `sigma-100017-suspicious-scheduled-task.yml` | 100017–100019 | T1053.005, T1027 | schtasks with scripting payload + obfuscation |

## Converting Sigma Rules

### Setup

```bash
# Install sigma-cli and the Wazuh backend
pip3 install sigma-cli
pip3 install pySigma-backend-wazuh    # community Wazuh backend
pip3 install pySigma-backend-splunk   # for Splunk conversion
```

### Convert a Single Rule

```bash
# To Wazuh XML format
sigma convert -t wazuh detections/sigma/sigma-100005-credential-dumping-lsass.yml

# To Splunk SPL
sigma convert -t splunk detections/sigma/sigma-100005-credential-dumping-lsass.yml

# To Elasticsearch Query DSL (Kibana)
sigma convert -t elasticsearch detections/sigma/sigma-100005-credential-dumping-lsass.yml
```

### Batch Convert All Rules to Splunk

```bash
for f in detections/sigma/sigma-*.yml; do
  echo "=== Converting $f ==="
  sigma convert -t splunk "$f"
done
```

### Convert to Microsoft Sentinel KQL

```bash
pip3 install pySigma-backend-microsoft365defender
sigma convert -t microsoft365defender detections/sigma/sigma-100009-c2-beaconing.yml
```

## Sigma Rule Structure Reference

```yaml
title: Human-readable title
id: UUID-v4                   # unique rule identifier
status: experimental | stable
description: What this detects and why it matters
references:
  - https://attack.mitre.org/techniques/TXXXX/
author: Your Name
date: YYYY/MM/DD
tags:
  - attack.tactic            # e.g., attack.credential_access
  - attack.tXXXX.XXX         # ATT&CK technique ID
logsource:
  category: process_creation  # or network_connection, registry_set, etc.
  product: windows            # or linux, macos
detection:
  selection:
    FieldName: value          # exact match
    FieldName|contains: str   # substring match
    FieldName|endswith: str   # suffix match
    FieldName|re: regex       # regex match
  filter_allowlist:
    FieldName: known_good_value
  timeframe: 60s              # for aggregation rules
  condition: selection and not filter_allowlist
  # Aggregation: selection | count() by field > N
fields:
  - Field1
  - Field2
falsepositives:
  - Known false positive scenario
level: low | medium | high | critical
```

## Aggregation Conditions (Sigma v2)

Sigma supports time-window aggregation for brute-force and beaconing detection:

```yaml
# Fire when selection matches more than 5 times within 60 seconds,
# grouped by the IpAddress field
timeframe: 60s
condition: selection | count() by IpAddress > 5
```

These are supported natively in Splunk, Elastic, and Sentinel backends. The Wazuh backend maps them to `frequency`/`timeframe` rule attributes.

## Status

Phase 3 complete. See [STATUS.md](../../STATUS.md).

# Sigma Rules

Sigma is a generic, tool-agnostic format for writing SIEM detection rules. Rules here can be converted to Wazuh, Splunk, QRadar, Microsoft Sentinel, or Elastic syntax using `sigma-cli`.

## Why Sigma?

Writing detections in Sigma format demonstrates:
- Portability across SIEM platforms (relevant for FAANG where the stack may differ)
- Industry-standard methodology (MITRE uses Sigma for ATT&CK coverage)
- Separation of detection logic from implementation

## Converting Sigma to Wazuh

```bash
# [host] Install sigma-cli
pip3 install sigma-cli

# Convert a Sigma rule to Wazuh format
sigma convert -t wazuh rules/lsass-access.yml
```

## Files (Phase 3)

| File | MITRE ID | Technique |
|------|----------|-----------|
| `lsass-access.yml` | T1003.001 | Credential Dumping via LSASS |
| `powershell-obfuscation.yml` | T1059.001 | Encoded PowerShell commands |
| `registry-run-key.yml` | T1547.001 | Registry Run Key persistence |
| `sliver-https-c2.yml` | T1071.001 | Sliver C2 over HTTPS |
| `event-log-clear.yml` | T1070.001 | Windows Event Log clearing |

## Status

Sigma rules are created during Phase 3. See [STATUS.md](../../STATUS.md).

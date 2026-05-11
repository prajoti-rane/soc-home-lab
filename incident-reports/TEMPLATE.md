# Incident Report — [INCIDENT-ID]: [Short Title]

**Date:** YYYY-MM-DD  
**Analyst:** Prajoti Rane  
**Severity:** Critical / High / Medium / Low  
**Status:** Open / Contained / Resolved  
**MITRE ATT&CK:** T1XXX.XXX, T1XXX

---

## Executive Summary

One paragraph describing what happened, how it was detected, and what the impact was.

---

## Timeline

| Time (UTC) | Event | Source | Evidence |
|------------|-------|--------|---------|
| HH:MM:SS | Initial access — implant dropped to C:\Temp\update.exe | Sysmon EventID 11 | Wazuh alert #100200 |
| HH:MM:SS | Implant executed | Sysmon EventID 1 | rule.id: 92001 |
| HH:MM:SS | Persistence via Registry Run Key | Sysmon EventID 13 | rule.id: 17101 |
| HH:MM:SS | LSASS memory access | Sysmon EventID 10 | rule.id: 100201 |
| HH:MM:SS | Event log cleared | Windows EventID 1102 | rule.id: 18145 |

---

## Attack Chain (MITRE ATT&CK)

```
Initial Access       → T1566 (Phishing / direct delivery in lab)
Execution            → T1059.001 (PowerShell)
Persistence          → T1547.001 (Registry Run Key)
Privilege Escalation → T1055 (Process Injection)
Credential Access    → T1003.001 (LSASS Memory)
Defense Evasion      → T1070.001 (Event Log Clearing)
Command & Control    → T1071.001 (HTTPS C2 — Sliver)
```

---

## Indicators of Compromise (IOCs)

### File Hashes

| File | SHA256 | Location | Tool |
|------|--------|----------|------|
| update.exe | `<hash>` | C:\Temp\update.exe | Sliver implant |

### Network IOCs

| Type | Value | Protocol | Port |
|------|-------|----------|------|
| IP | 192.168.64.30 | HTTPS | 443 |
| Domain | — | — | — |

### Registry IOCs

| Key | Value Name | Data |
|-----|-----------|------|
| HKCU\Software\Microsoft\Windows\CurrentVersion\Run | updater | C:\Temp\update.exe |

### Process IOCs

| Process | Parent | Command Line | Unusual? |
|---------|--------|-------------|---------|
| update.exe | explorer.exe | update.exe | Yes — unexpected parent |

---

## Detection Details

### Alerts Generated

| Rule ID | Rule Name | Level | Time | Agent |
|---------|-----------|-------|------|-------|
| 100200 | Suspicious process in writable path | 14 | HH:MM | victim-windows |
| 17101 | Registry Run Key modification | 10 | HH:MM | victim-windows |
| 100201 | LSASS process access | 15 | HH:MM | victim-windows |
| 18145 | Windows event log cleared | 12 | HH:MM | victim-windows |

### Detection Gaps

- [ ] Initial implant download from HTTP server not alerted (HTTP traffic monitoring not configured)
- [ ] Lateral movement would not be detected without additional victim VMs

---

## Containment Actions

1. Isolated victim-windows VM (UTM → suspend)
2. Blocked 192.168.64.30 in victim-windows firewall (post-incident)
3. Removed persistence: `Remove-ItemProperty HKCU:\...Run -Name updater`
4. Deleted implant: `Remove-Item C:\Temp\update.exe -Force`

---

## Root Cause Analysis

- **How did the attack succeed?** Windows Defender was disabled for lab purposes
- **What detection rule should have fired earlier?** DNS query monitoring for new C2 connections
- **What was the detection latency?** First alert within X seconds of implant execution

---

## Lessons Learned

1. **What worked:** Sysmon EventID 10 correctly detected LSASS access before log clearing
2. **What failed:** HTTP download of implant was not detected
3. **Rule improvement:** Add Wazuh decoder for Filebeat HTTP access logs to catch implant downloads

---

## Remediation Recommendations

- [ ] Enable Windows Defender (or equivalent AV) for realistic detection testing
- [ ] Add HTTP/S proxy logging to detect C2 download events
- [ ] Create Wazuh active response rule to isolate host on LSASS access alert

---

## Appendix

### Raw Alert JSON (excerpt)

```json
{
  "timestamp": "YYYY-MM-DDTHH:MM:SS.mmmZ",
  "rule": {
    "id": "100201",
    "level": 15,
    "description": "LSASS process access — possible credential dumping"
  },
  "agent": {
    "name": "victim-windows",
    "ip": "192.168.64.20"
  },
  "data": {
    "win": {
      "eventdata": {
        "sourceImage": "C:\\Temp\\update.exe",
        "targetImage": "C:\\Windows\\System32\\lsass.exe",
        "grantedAccess": "0x1010"
      }
    }
  }
}
```

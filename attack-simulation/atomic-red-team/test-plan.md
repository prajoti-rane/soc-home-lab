# Detection Validation Test Plan

> **FOR AUTHORIZED HOME LAB USE ONLY**

This document maps every Wazuh custom rule (Phase 3) to its corresponding Atomic Red Team test, the expected Sysmon events, and the cleanup procedure.

## Pre-Execution Checklist

- [ ] All 3 VMs are running and healthy
- [ ] UTM snapshot taken on all VMs before starting (`UTM → right-click VM → New Snapshot`)
- [ ] Kibana accessible: [http://192.168.64.10:5601](http://192.168.64.10:5601)
- [ ] Sysmon service running on victim-windows: `Get-Service Sysmon64a`
- [ ] Filebeat service running on victim-windows: `Get-Service filebeat`
- [ ] Wazuh agent healthy on victim-windows: `Get-Service WazuhSvc`
- [ ] Note UTC start time before each test: `[System.DateTime]::UtcNow`

---

## Test Execution Table

| Our Rule ID | MITRE T-Code | Atomic Test Name | Test Number | Run From | Requires Admin | Expected Detection | Cleanup Command |
|-------------|--------------|-----------------|-------------|----------|----------------|-------------------|-----------------|
| 100001–100002 | T1110.001 | SSH Brute Force (Hydra) | *manual* | kali-attacker | No | Rule 100001 fires after 5+ failures from same IP | N/A — test ends when hydra stops |
| 100003–100004 | T1110.001 | Password Brute Force via Kerbrute | T1110.001-9 | victim-windows | No | Rule 100003 (level 10) fires on 5+ EventID 4625 | `Invoke-AtomicTest T1110.001 -TestNumbers 9 -Cleanup` |
| 100005 | T1003.001 | Dump LSASS Memory using ProcDump | T1003.001-1 | victim-windows | **Yes** | Rule 100005 (level 14) fires — Sysmon EID 10 | `Invoke-AtomicTest T1003.001 -TestNumbers 1 -Cleanup; Remove-Item C:\Temp\lsass.dmp -Force` |
| 100006–100008 | T1059.001 | Encoded PowerShell Command | T1059.001-1 | victim-windows | No | Rule 100007 (level 12) fires — Sysmon EID 1 with -enc | No artifacts — test is self-contained |
| 100009–100011 | T1071.001 | Malicious User Agents | T1071.001-1 | victim-windows | No | Rule 100009 fires (level 6); rule 100010 fires after 10+ connections | No artifacts |
| 100012–100014 | T1021.002 | PsExec Commands | T1021.002-2 | victim-windows | **Yes** | Rule 100012 (level 10) — EventID 7045 PSEXESVC | `Invoke-AtomicTest T1021.002 -TestNumbers 2 -Cleanup` |
| 100015–100016 | T1562.001 | Disable Windows Defender AV | T1562.001-1 | victim-windows | **Yes** | Rule 100015 (level 14) — Sysmon EID 13 registry set | `Invoke-AtomicTest T1562.001 -TestNumbers 1 -Cleanup` **+ verify Defender re-enabled** |
| 100017–100019 | T1053.005 | Scheduled Task Startup Script | T1053.005-1 | victim-windows | No | Rule 100018 (level 12) — Sysmon EID 1 schtasks.exe | `Invoke-AtomicTest T1053.005 -TestNumbers 1 -Cleanup` |

---

## Detailed Test Procedures

### Test 1: SSH Brute Force (T1110.001 → Rules 100001–100002)

**Run from:** kali-attacker VM

```bash
# [kali-attacker] 192.168.64.30
# Brute-force SSH on wazuh-manager
hydra -l soc -P /usr/share/wordlists/rockyou.txt \
  ssh://192.168.64.10 -t 4 -V -f -I -e nsr

# Simulates hitting the same username repeatedly from same IP
# Rule 100001 fires after attempt #5 (frequency=5, timeframe=60s)
```

**Verify in Kibana:**
```
rule.id:100001 AND agent.name:"wazuh-manager"
```

**Cleanup:**
```bash
# No cleanup needed — hydra stops when word list is exhausted or -f flag exits on success
# If testing the compound rule (100002), ensure no legitimate SSH session stays open
```

---

### Test 2: RDP Brute Force (T1110.001 → Rules 100003–100004)

**Run from:** victim-windows VM or kali-attacker

```powershell
# [victim-windows] Atomic test simulates multiple failed logons
Invoke-AtomicTest T1110.001 -TestNumbers 9 -GetPrereqs
Invoke-AtomicTest T1110.001 -TestNumbers 9
# Note: this test uses Kerbrute or direct login attempts against a local account
```

OR from Kali:

```bash
# [kali-attacker] Direct RDP brute-force
crowbar -b rdp -s 192.168.64.20/32 -u SOCAdmin \
  -C /usr/share/wordlists/rockyou.txt -n 1 -v
```

**Verify in Kibana:**
```
rule.id:100003 AND agent.name:"victim-windows"
```

**Cleanup:**
```powershell
Invoke-AtomicTest T1110.001 -TestNumbers 9 -Cleanup
```

---

### Test 3: LSASS Credential Dumping (T1003.001 → Rule 100005)

**Run from:** victim-windows VM — **requires Administrator**

```powershell
# [victim-windows — Admin PowerShell]
# Downloads procdump64.exe from Sysinternals live
Invoke-AtomicTest T1003.001 -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest T1003.001 -TestNumbers 1
# Expected: procdump creates C:\Temp\lsass.dmp
# Sysmon EID 10 fires with grantedAccess=0x1fffff → Wazuh rule 100005 level 14
```

**Verify in Kibana:**
```
rule.id:100005 AND win.eventdata.targetImage:*lsass*
```

**Cleanup:**
```powershell
Invoke-AtomicTest T1003.001 -TestNumbers 1 -Cleanup
Remove-Item C:\Temp\lsass.dmp -Force -ErrorAction SilentlyContinue
Remove-Item C:\Tools\procdump64.exe -Force -ErrorAction SilentlyContinue
```

---

### Test 4: Encoded PowerShell (T1059.001 → Rules 100006–100008)

**Run from:** victim-windows VM — no admin required

```powershell
# [victim-windows — Standard PowerShell as SOCAdmin]
Invoke-AtomicTest T1059.001 -TestNumbers 1 -ShowDetails  # Preview first
Invoke-AtomicTest T1059.001 -TestNumbers 1
# Expected: powershell.exe with -EncodedCommand flag
# Sysmon EID 1 fires → Wazuh rule 100007 (level 12)
```

**Verify in Kibana:**
```
rule.id:100007 AND win.eventdata.commandLine:*-enc*
```

**Cleanup:** No persistent artifacts — test is self-contained.

---

### Test 5: C2 Beaconing (T1071.001 → Rules 100009–100011)

**Run from:** victim-windows VM

```powershell
# [victim-windows] Atomic test generates outbound web requests with C2-like behavior
Invoke-AtomicTest T1071.001 -TestNumbers 1
# Expected: Sysmon EID 3 (network connect) from PowerShell/cmd to external IP
# Rule 100009 (level 6) fires on writable-path binary making web request
# Rule 100010 (level 12) fires after 10+ connections to same destination

# Alternatively, run the Sliver implant (see sliver/README.md for full C2 scenario)
```

**Verify in Kibana:**
```
rule.id:(100009 OR 100010) AND agent.name:"victim-windows"
```

**Cleanup:** No artifacts.

---

### Test 6: PsExec Lateral Movement (T1021.002 → Rules 100012–100014)

**Run from:** victim-windows VM — **requires Administrator**

```powershell
# [victim-windows — Admin PowerShell]
Invoke-AtomicTest T1021.002 -TestNumbers 2 -GetPrereqs
Invoke-AtomicTest T1021.002 -TestNumbers 2
# Expected: PSEXESVC service installed → EventID 7045
# Wazuh rule 100012 fires (level 10)
```

**Verify in Kibana:**
```
rule.id:100012 AND win.eventdata.serviceName:PSEXESVC
```

**Cleanup:**
```powershell
Invoke-AtomicTest T1021.002 -TestNumbers 2 -Cleanup
# Verify PSEXESVC service is removed
Get-Service PSEXESVC -ErrorAction SilentlyContinue
```

---

### Test 7: Defender Tampering (T1562.001 → Rules 100015–100016)

**Run from:** victim-windows VM — **requires Administrator**

> **IMPORTANT:** Always run cleanup immediately after this test. Running without Defender is a security risk even in a lab.

```powershell
# [victim-windows — Admin PowerShell]
Invoke-AtomicTest T1562.001 -TestNumbers 1
# Expected: Add-MpPreference adds exclusion path
# Sysmon EID 13 (registry set on Defender Exclusions key) → Wazuh rule 100015 (level 14)
```

**Verify in Kibana:**
```
rule.id:(100015 OR 100016) AND agent.name:"victim-windows"
```

**Cleanup — MANDATORY:**
```powershell
Invoke-AtomicTest T1562.001 -TestNumbers 1 -Cleanup

# Verify Defender is fully restored
$status = Get-MpComputerStatus
Write-Host "AV Enabled: $($status.AntivirusEnabled)"
Write-Host "Real-Time: $($status.RealTimeProtectionEnabled)"
# Both must be True before continuing
```

---

### Test 8: Suspicious Scheduled Task (T1053.005 → Rules 100017–100019)

**Run from:** victim-windows VM — no admin required

```powershell
# [victim-windows — Standard PowerShell as SOCAdmin]
Invoke-AtomicTest T1053.005 -TestNumbers 1
# Expected: schtasks.exe /create with PowerShell action
# Sysmon EID 1 → Wazuh rule 100018 (level 12)
```

**Verify in Kibana:**
```
rule.id:(100017 OR 100018) AND win.eventdata.image:*schtasks*
```

**Cleanup:**
```powershell
Invoke-AtomicTest T1053.005 -TestNumbers 1 -Cleanup
# Verify the task is removed
schtasks /query /tn "AtomicTask" 2>&1
# Should show "ERROR: The system cannot find the path specified."
```

---

## Post-Test Evidence Capture

After all tests, export alerts from Kibana for the incident report:

```bash
# [macOS host] Export Wazuh alerts from Elasticsearch
START_TIME="2024-01-01T00:00:00Z"  # Replace with your actual test start time
curl -s "http://192.168.64.10:9200/wazuh-alerts-*/_search" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": {
      \"bool\": {
        \"must\": [
          {\"range\": {\"timestamp\": {\"gte\": \"$START_TIME\"}}},
          {\"range\": {\"rule.id\": {\"gte\": 100001, \"lte\": 100019}}}
        ]
      }
    },
    \"size\": 100
  }" | python3 -m json.tool > ~/Desktop/art-alerts-export.json
```

---

## Pass/Fail Criteria

| Result | Meaning |
|--------|---------|
| ✅ PASS | Wazuh alert at expected level fires within 30 seconds of test execution |
| ⚠️ PARTIAL | Alert fires but at wrong level or delayed >60 seconds |
| ❌ FAIL | No alert fires — detection gap identified |
| ⏭️ SKIP | Test requires different VM or admin rights not available |

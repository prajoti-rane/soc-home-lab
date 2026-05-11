# Atomic Red Team — Detection Validation Guide

> **WARNING: FOR AUTHORIZED HOME LAB USE ONLY**
> Atomic Red Team tests simulate real attacker techniques. Run these tests
> ONLY on the victim-windows VM (192.168.64.20) within the isolated UTM
> lab network. Never execute these tests on production systems or systems
> you do not own.

---

## What Is Atomic Red Team?

[Atomic Red Team](https://github.com/redcanaryco/atomic-red-team) (ART) is an open-source library of small, focused test cases for individual MITRE ATT&CK techniques. Each "atomic test" is the minimum set of commands needed to trigger the observable behavior of a specific technique.

**Why ART is the industry standard for detection validation:**
- Maps 1-to-1 with ATT&CK technique IDs (T1003.001, T1059.001, etc.)
- Tests are small, targeted, and easily cleaned up
- Used by Blue Teams at enterprise SOCs and MSSPs to validate detection coverage
- The `Invoke-AtomicRedTeam` PowerShell module enables automated execution and cleanup
- CISA and NIST recommend ART-style exercises in their Purple Team guidance

**In this lab**, ART provides the ground-truth events that our Wazuh rules must detect. If a test runs and no alert fires, the detection has a coverage gap.

---

## Installation on Windows 11 ARM64

```powershell
# [victim-windows] Open PowerShell as Administrator

# Step 1: Allow PowerShell to install from PSGallery
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force

# Step 2: Install the Invoke-AtomicRedTeam module
IEX (New-Object Net.WebClient).DownloadString(
  'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1'
)
Install-AtomicRedTeam -getAtomics -Force

# Step 3: Import the module
Import-Module invoke-atomicredteam

# Step 4: Verify installation
Invoke-AtomicTest T1059.001 -TestNumbers 1 -ShowDetails
# Should print test details without executing

# Step 5: Install prerequisites for resource-intensive tests
Invoke-AtomicTest T1003.001 -TestNumbers 1 -GetPrereqs
```

---

## How Tests Work

Each test has three phases:

```powershell
# 1. Show what the test will do (safe — no execution)
Invoke-AtomicTest T1003.001 -TestNumbers 1 -ShowDetails

# 2. Check prerequisites (downloads tools if needed)
Invoke-AtomicTest T1003.001 -TestNumbers 1 -GetPrereqs

# 3. Execute the test (generates detectable events)
Invoke-AtomicTest T1003.001 -TestNumbers 1

# 4. Clean up after the test
Invoke-AtomicTest T1003.001 -TestNumbers 1 -Cleanup
```

---

## Detection Coverage Map

This table maps our 8 Wazuh custom rules to their corresponding Atomic Red Team tests.

| Our Rule ID | MITRE Technique | Atomic Test | Test Name | Wazuh Level | Expected Sysmon Events |
|-------------|----------------|-------------|-----------|-------------|----------------------|
| 100001–100002 | T1110.001 | T1110.001-1 | Brute Force Credentials of Single Target over SSH | 10 → 14 | Linux auth failures (5710) |
| 100003–100004 | T1110.001 | T1110.001-9 | Password Brute User using Kerbrute Tool | 10 | Windows EventID 4625 ×5 |
| 100005 | T1003.001 | T1003.001-1 | Dump LSASS.exe Memory using ProcDump | 14 | Sysmon EID 10 (LSASS access) |
| 100006–100008 | T1059.001 | T1059.001-1 | Mimikatz - Cred Dump using PS Encoded Cmd | 6 → 12 → 14 | Sysmon EID 1 (PS with -enc flag) |
| 100009–100011 | T1071.001 | T1071.001-1 | Malicious User Agents | 6 → 12 | Sysmon EID 3 (repeated connections) |
| 100012–100014 | T1021.002 | T1021.002-2 | PsExec Commands | 10 | Windows EventID 7045 (PSEXESVC) |
| 100015–100016 | T1562.001 | T1562.001-1 | Disable Windows Defender AV | 14 | Sysmon EID 13 (registry set) |
| 100017–100019 | T1053.005 | T1053.005-1 | Scheduled Task Startup Script | 10 → 12 | Sysmon EID 1 (schtasks.exe) |

---

## Running Individual Tests

### T1003.001 — Credential Dumping (LSASS)

```powershell
# [victim-windows — Administrator PowerShell]
# Prereq: downloads procdump64.exe from Sysinternals
Invoke-AtomicTest T1003.001 -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest T1003.001 -TestNumbers 1

# Expected: Sysmon EID 10 fires, Wazuh rule 100005 (level 14) alerts
# Cleanup:
Invoke-AtomicTest T1003.001 -TestNumbers 1 -Cleanup
Remove-Item C:\Temp\lsass.dmp -Force -ErrorAction SilentlyContinue
```

### T1059.001 — Suspicious PowerShell

```powershell
# [victim-windows — Standard PowerShell as SOCAdmin]
Invoke-AtomicTest T1059.001 -TestNumbers 1

# Expected: Sysmon EID 1 with -enc flag, Wazuh rule 100007 (level 12) alerts
# Cleanup: no artifacts
```

### T1562.001 — Disable Windows Defender

```powershell
# [victim-windows — Administrator PowerShell]
Invoke-AtomicTest T1562.001 -TestNumbers 1

# Expected: Sysmon EID 13 (registry write), Wazuh rule 100015 (level 14) alerts
# Cleanup: RE-ENABLE DEFENDER IMMEDIATELY after test
Invoke-AtomicTest T1562.001 -TestNumbers 1 -Cleanup
# Verify Defender is back on:
Get-MpComputerStatus | Select-Object -Property AntivirusEnabled, RealTimeProtectionEnabled
```

### T1053.005 — Scheduled Task

```powershell
# [victim-windows — Standard PowerShell as SOCAdmin]
Invoke-AtomicTest T1053.005 -TestNumbers 1

# Expected: Sysmon EID 1 (schtasks.exe), Wazuh rule 100018 (level 12) alerts
# Cleanup:
Invoke-AtomicTest T1053.005 -TestNumbers 1 -Cleanup
```

### T1021.002 — PsExec Lateral Movement

```powershell
# [victim-windows — Administrator PowerShell]
# Prereq: downloads PsExec from Sysinternals
Invoke-AtomicTest T1021.002 -TestNumbers 2 -GetPrereqs
Invoke-AtomicTest T1021.002 -TestNumbers 2

# Expected: EventID 7045 (PSEXESVC service), Wazuh rule 100012 (level 10) alerts
# Cleanup:
Invoke-AtomicTest T1021.002 -TestNumbers 2 -Cleanup
```

---

## Batch Execution

Use `runner.ps1` to run all tests in sequence with Kibana timestamp markers:

```powershell
# [victim-windows] Run full detection validation suite
.\runner.ps1 -OutputPath C:\Temp\art-results.txt
```

---

## Correlating Results with Kibana

```powershell
# [victim-windows] Note the UTC timestamp before each test run
$timestamp = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-Host "Test start time: $timestamp"

# After the test, go to Kibana:
# http://192.168.64.10:5601
# Stack Management → Saved Objects → Wazuh alerts
# Filter: timestamp >= $timestamp AND rule.id: [100001 TO 100019]
```

**Kibana saved query for all Phase 4 tests:**

```
rule.id:[100001 TO 100019] AND agent.name:"victim-windows"
```

---

## Expected Alert Latency

| Stage | Typical latency |
|-------|----------------|
| Sysmon event generated | < 1 second |
| Wazuh agent → manager | 1–5 seconds |
| Manager processes + indexes to ES | 2–10 seconds |
| Visible in Kibana | **5–15 seconds total** |

If an alert doesn't appear within 30 seconds, check:
1. Filebeat service: `Get-Service filebeat`
2. Wazuh agent: `Get-Service WazuhSvc`
3. Sysmon: `Get-Service Sysmon64a`

---

## Status

Phase 4 complete. See [STATUS.md](../../STATUS.md).

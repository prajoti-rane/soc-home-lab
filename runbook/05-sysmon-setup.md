# Step 5: Sysmon Installation (Windows 11 ARM64)

Install Sysmon on the `victim-windows` VM with the SwiftOnSecurity configuration for high-fidelity, low-noise telemetry.

**Run all commands on victim-windows (192.168.64.20) as Administrator.**

---

## Download Sysmon

```powershell
# [windows] Create tools directory
New-Item -ItemType Directory -Path C:\Tools -Force

# Download Sysmon (ARM64-compatible — the x64 binary works under Windows 11 ARM via emulation,
# but Sysinternals ships a native ARM64 build as of Sysmon 15.x)
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile C:\Tools\Sysmon.zip
Expand-Archive -Path C:\Tools\Sysmon.zip -DestinationPath C:\Tools\Sysmon
```

---

## Download SwiftOnSecurity Config

```powershell
# [windows] Download SwiftOnSecurity sysmonconfig-export.xml
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" `
  -OutFile C:\Tools\Sysmon\sysmonconfig.xml
```

Review the config before installing — you may want to tune it later to reduce noise.

---

## Install Sysmon

```powershell
# [windows] Install with config (run as Administrator)
cd C:\Tools\Sysmon
.\Sysmon64.exe -accepteula -i sysmonconfig.xml
```

Expected output:
```
System Monitor v15.x - System activity monitor
...
Sysmon installed.
SysmonDrv installed.
Starting SysmonDrv.
SysmonDrv started.
Starting Sysmon.
Sysmon started.
```

---

## Verify Installation

```powershell
# [windows] Check service is running
Get-Service Sysmon64

# Verify events are flowing
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 10 | Select-Object Id, Message
```

You should see EventIDs like 1 (process create), 3 (network connect), 11 (file create).

---

## Key Event IDs Reference

| EventID | Name | Detection Use |
|---------|------|--------------|
| 1 | Process Create | Malicious process execution, LOLBins |
| 3 | Network Connection | C2 callbacks, lateral movement |
| 5 | Process Terminate | Process tracking |
| 7 | Image Loaded | DLL hijacking, process injection |
| 8 | CreateRemoteThread | Process injection |
| 10 | ProcessAccess | Credential dumping (LSASS) |
| 11 | FileCreate | Dropper activity, staging |
| 12/13/14 | Registry Events | Persistence (Run keys) |
| 15 | FileCreateStreamHash | Alternate data streams |
| 22 | DNSEvent | C2 domain lookups |
| 23 | FileDelete | Anti-forensics |

---

## Update Sysmon Config

To update the config without reinstalling:

```powershell
# [windows]
C:\Tools\Sysmon\Sysmon64.exe -c C:\Tools\Sysmon\sysmonconfig.xml
```

---

## Protect Sysmon from Tampering

```powershell
# [windows] Restrict Sysmon config file permissions (prevents non-admin modification)
icacls C:\Tools\Sysmon\sysmonconfig.xml /inheritance:r /grant:r "SYSTEM:F" /grant:r "Administrators:F"
```

Wazuh will alert (via its FIM module and EventID 4663) if the config file is modified by an unauthorized process.

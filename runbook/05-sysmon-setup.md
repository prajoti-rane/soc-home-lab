# Step 5: Sysmon Installation (Windows 11 ARM64)

Install Sysmon on `victim-windows` (192.168.64.20) with the SwiftOnSecurity configuration for high-fidelity, low-noise telemetry.

**Run all commands on victim-windows as Administrator.**

**Estimated time:** 20 minutes

> Connect via RDP from your Mac: open **Microsoft Remote Desktop** → Add PC → `192.168.64.20` → username `socadmin`

---

## 5.1 — Open an Administrator PowerShell

On Windows:
1. Press `Win + X` → select **Terminal (Admin)** or **Windows PowerShell (Admin)**
2. Click **Yes** at the UAC prompt
3. Verify you see `PS C:\Users\socadmin>` or similar with "Administrator" in the title bar

All commands in this step run in this Administrator PowerShell.

---

## 5.2 — Create Tools Directory

```powershell
# [windows]
New-Item -ItemType Directory -Path C:\Tools -Force
New-Item -ItemType Directory -Path C:\Tools\Sysmon -Force
```

---

## 5.3 — Download Sysmon

```powershell
# [windows] Download Sysmon from Microsoft Sysinternals
Invoke-WebRequest `
  -Uri "https://download.sysinternals.com/files/Sysmon.zip" `
  -OutFile "C:\Tools\Sysmon.zip"

# Extract
Expand-Archive -Path "C:\Tools\Sysmon.zip" -DestinationPath "C:\Tools\Sysmon" -Force

# Verify files extracted
Get-ChildItem C:\Tools\Sysmon
# Expected:
# Eula.txt
# Sysmon.exe      (x86, ignore this one)
# Sysmon64.exe    (x64, works under ARM64 via emulation)
# Sysmon64a.exe   (native ARM64, use this — available in Sysmon 15.x+)
```

> **Which binary to use?** `Sysmon64a.exe` is the native ARM64 build introduced in Sysmon 15.x. It has lower overhead and better compatibility with ARM64 Windows. If you downloaded Sysmon before 15.x was released, you'll only see `Sysmon64.exe` — that works too (runs under x64 emulation).

```powershell
# [windows] Verify the ARM64 binary exists
if (Test-Path "C:\Tools\Sysmon\Sysmon64a.exe") {
    Write-Host "Using native ARM64 binary: Sysmon64a.exe"
    $SYSMON = "C:\Tools\Sysmon\Sysmon64a.exe"
} else {
    Write-Host "ARM64 binary not found, using x64: Sysmon64.exe"
    $SYSMON = "C:\Tools\Sysmon\Sysmon64.exe"
}
Write-Host "Sysmon binary: $SYSMON"
```

---

## 5.4 — Download SwiftOnSecurity Config

```powershell
# [windows] Download the community-maintained sysmonconfig
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" `
  -OutFile "C:\Tools\Sysmon\sysmonconfig.xml"

# Verify download
Get-Item "C:\Tools\Sysmon\sysmonconfig.xml" | Select-Object Length
# Expected: > 50000 bytes (the config file is ~100 KB)
```

> **Why SwiftOnSecurity?** This config is used across thousands of production environments. It filters noisy benign events (like Windows Update processes) while retaining high-value events. It's the correct balance for a lab that needs detectable attack signals without drowning in false positives.

---

## 5.5 — Install Sysmon

```powershell
# [windows] Install Sysmon with the config
# If you set $SYSMON in step 5.3, use it; otherwise use the full path:
C:\Tools\Sysmon\Sysmon64a.exe -accepteula -i C:\Tools\Sysmon\sysmonconfig.xml
```

Expected output:

```
System Monitor v15.x - System activity monitor
Copyright (C) 2014-2024 Mark Russinovich and Thomas Garnier
...
Loading configuration file with schema version 4.90
Sysmon schema version: 4.90
Configuration file validated.
Sysmon installed.
SysmonDrv installed.
Starting SysmonDrv.
SysmonDrv started.
Starting Sysmon64a.
Sysmon64a started.
```

If you see any error about "already installed", Sysmon was installed previously:

```powershell
# [windows] Update existing install instead
C:\Tools\Sysmon\Sysmon64a.exe -c C:\Tools\Sysmon\sysmonconfig.xml
```

---

## 5.6 — Verify Sysmon is Running

```powershell
# [windows] Check the service
Get-Service Sysmon64
# Expected: Status=Running, Name=Sysmon64

# Check driver
Get-Service SysmonDrv
# Expected: Status=Running
```

```powershell
# [windows] Verify events are flowing — look at the last 10 Sysmon events
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 10 |
  Select-Object Id, TimeCreated, @{N="Description";E={$_.Message.Substring(0,[Math]::Min(100,$_.Message.Length))}}
```

Expected: you should see events with IDs like:
- **1** (Process Create) — triggered when you ran PowerShell commands above
- **3** (Network Connection) — if anything made a network connection
- **11** (File Create) — triggered when you downloaded files

If you see `No events were found that match the specified selection criteria`, wait 30 seconds and retry — Sysmon may need a moment to initialize.

---

## 5.7 — View Events in Event Viewer (Optional)

1. Press `Win + R` → type `eventvwr.msc` → Enter
2. Navigate: **Applications and Services Logs → Microsoft → Windows → Sysmon → Operational**
3. You should see events populating in the right panel
4. Double-click any event to see its XML format — this is the raw data Wazuh collects

---

## 5.8 — Test a Key Detection (LSASS Access)

Generate a test event that should trigger Wazuh rule 100005:

```powershell
# [windows] Open Windows Task Manager
# Find lsass.exe PID
Get-Process -Name lsass | Select-Object Id
# Note the PID (e.g., 584)

# [windows] Use Get-Process to "access" lsass — this is benign but generates a Sysmon EID 10
$lsassPid = (Get-Process -Name lsass).Id
$p = [System.Diagnostics.Process]::GetProcessById($lsassPid)
Write-Host "Accessed lsass PID: $($p.Id)"
```

After running this, check the Sysmon event log for EventID 10 (ProcessAccess) targeting `lsass.exe`. You should see the event in Event Viewer.

> **Note:** Rule 100005 requires `grantedAccess 0x1fffff` — this PowerShell access uses a lower privilege mask and won't trigger the critical alert. The real trigger is `procdump` or mimikatz requesting PROCESS_ALL_ACCESS. This test just confirms EID 10 events are being generated.

---

## 5.9 — Protect Sysmon Config from Tampering

```powershell
# [windows] Lock down config file permissions
# Only SYSTEM and Administrators can modify it
icacls "C:\Tools\Sysmon\sysmonconfig.xml" `
  /inheritance:r `
  /grant:r "SYSTEM:F" `
  /grant:r "Administrators:F"

# Verify
icacls "C:\Tools\Sysmon\sysmonconfig.xml"
# Expected: SYSTEM Allow  FullControl
#           BUILTIN\Administrators Allow  FullControl
```

---

## Key Event IDs Reference

| EventID | Name | Why it matters |
|---------|------|----------------|
| 1 | ProcessCreate | Detects malicious process execution, LOLBins (T1059) |
| 3 | NetworkConnection | C2 callbacks, lateral movement (T1071, T1021) |
| 7 | ImageLoaded | DLL hijacking, process injection |
| 8 | CreateRemoteThread | Process injection (T1055) |
| 10 | ProcessAccess | Credential dumping — LSASS access (T1003.001) |
| 11 | FileCreate | Dropper staging, file-based persistence |
| 12/13/14 | RegistryEvents | Registry-based persistence (T1547.001) |
| 22 | DnsQuery | C2 domain lookups (T1071.004) |
| 23 | FileDelete | Anti-forensics (T1070.004) |

---

## Updating Sysmon Config (Future)

To update the SwiftOnSecurity config without reinstalling:

```powershell
# [windows] Download latest config
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" `
  -OutFile "C:\Tools\Sysmon\sysmonconfig.xml"

# Apply update
C:\Tools\Sysmon\Sysmon64a.exe -c C:\Tools\Sysmon\sysmonconfig.xml
# Expected: "Configuration updated."
```

---

## Troubleshooting

**"Access denied" when running Sysmon64a.exe**
You're not in an Administrator PowerShell. Close and reopen as Administrator (Step 5.1).

**"Sysmon schema version mismatch"**
The downloaded config is newer than your Sysmon binary, or vice versa.
```powershell
# [windows] Check Sysmon version
C:\Tools\Sysmon\Sysmon64a.exe --  # Prints version
# Then download matching Sysmon version from Microsoft
```

**No events in Sysmon/Operational log**
```powershell
# [windows] Check if the log exists and is enabled
Get-WinEvent -ListLog "Microsoft-Windows-Sysmon/Operational" | Select-Object LogName, IsEnabled
# If IsEnabled = False:
wevtutil sl "Microsoft-Windows-Sysmon/Operational" /e:true
```

**`Sysmon.zip` download fails (SSL/TLS error)**
```powershell
# [windows] Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "C:\Tools\Sysmon.zip"
```

**Sysmon events not appearing in Wazuh (after Step 6)**
```bash
# [manager] Verify ossec.conf has Sysmon channel configured
sudo grep -A2 "Sysmon" /var/ossec/etc/ossec.conf
# If missing, add it — see Step 6 for details
```

---

## Checklist — Step 5 Complete When:

- [ ] `Get-Service Sysmon64` returns `Status=Running`
- [ ] Event Viewer shows events in `Microsoft-Windows-Sysmon/Operational`
- [ ] `Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 10` returns events
- [ ] Config file permissions locked down (SYSTEM + Administrators only)

**Next step → [06-agent-deployment.md](06-agent-deployment.md)**

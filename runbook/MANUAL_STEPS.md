# Manual Steps — GUI-Required Operations

Operations that require UTM's graphical interface or a VM's display and cannot be automated via SSH or Ansible. Complete these steps as they appear in the runbook — don't try to script around them.

---

## UTM: Create wazuh-manager VM

Referenced from: [02-utm-vm-creation.md](02-utm-vm-creation.md)

1. Open **UTM** → click **+** (top-left toolbar)
2. Select **Virtualize** ← not "Emulate"
3. Select **Linux**
4. Boot ISO Image → **Browse** → navigate to `~/Downloads/SOC-Lab-ISOs/`
5. Select `ubuntu-24.04.x-live-server-arm64.iso` → **Open**
6. Hardware settings:
   - CPU Cores: `4`
   - Memory (MiB): `8192`
   - (leave all other settings at default)
7. Storage → Size: `64` GB → **Next**
8. Shared Directory → **Skip** (don't add one)
9. Summary:
   - Name: `wazuh-manager`
   - (optionally check "Open VM Settings" to verify before saving)
10. Click **Save**

---

## UTM: Create victim-windows VM (VHDX Import)

Referenced from: [02-utm-vm-creation.md](02-utm-vm-creation.md)

1. UTM → **+** → **Virtualize** → **Windows**
2. Select **Import VHDX Image** → Browse → select your `.vhdx` or `.iso` file → **Open**
3. Hardware:
   - CPU Cores: `4`
   - Memory (MiB): `4096`
4. Verify these are enabled (UTM enables them automatically for Windows):
   - ✅ TPM Enabled
   - ✅ UEFI Boot
5. Network: Shared Network (default)
6. Name: `victim-windows` → **Save**

---

## UTM: Create kali-attacker VM

Referenced from: [02-utm-vm-creation.md](02-utm-vm-creation.md)

1. UTM → **+** → **Virtualize** → **Linux**
2. Boot ISO: Browse → select `kali-linux-2024.x-installer-arm64.iso` → **Open**
3. Hardware:
   - CPU Cores: `4`
   - Memory (MiB): `4096`
4. Storage → Size: `40` GB → **Next**
5. Shared Directory → **Skip**
6. Name: `kali-attacker` → **Save**

---

## Ubuntu Server Installer: Exact Selections

Referenced from: [02-utm-vm-creation.md](02-utm-vm-creation.md)

After clicking Play on wazuh-manager VM. Navigate with arrow keys, Tab, Space, Enter.

| Screen | Selection |
|--------|-----------|
| Language | English |
| Keyboard layout | English (US) |
| Type of install | Ubuntu Server |
| Network | Accept DHCP defaults → Done |
| Proxy | Leave blank → Done |
| Mirror | Accept default → Done (wait for test) |
| Guided storage | Use an entire disk → no LVM |
| Storage confirm | Continue (destructive) |
| Your name | SOC Admin |
| Server name | wazuh-manager |
| Username | ubuntu |
| SSH server | **Install OpenSSH server — YES** (Space to check) |
| Featured snaps | Leave all unchecked → Done |

After install: **Reboot Now** → eject ISO if UTM doesn't auto-eject.

---

## Windows 11 OOBE: Local Account Without Microsoft

Referenced from: [02-utm-vm-creation.md](02-utm-vm-creation.md)

Windows 11 23H2+ forces Microsoft account sign-in during OOBE. Bypass:

1. At "Let's add your Microsoft account" screen
2. Press **Shift + F10** → Command Prompt opens
3. Type: `oobe\bypassnro` → Enter
4. VM reboots → returns to OOBE
5. Select "I don't have internet" → "Continue with limited setup"
6. Enter: Computer name = `VICTIM-WIN`, Username = `socadmin`, Password = your choice

---

## Windows 11: VirtIO Network Driver Installation

Referenced from: [02-utm-vm-creation.md](02-utm-vm-creation.md)

Without this step, Windows has no network adapter.

1. After Windows boots, open **Device Manager**: right-click Start → Device Manager
2. Look for: **Other devices → Ethernet Controller** (yellow warning icon)
3. Right-click **Ethernet Controller** → **Update driver**
4. Select: **Browse my computer for drivers**
5. Browse to the VirtIO CD that UTM auto-mounts (check File Explorer for a CD drive)
   - If no CD appears in File Explorer, mount it manually: UTM → VM Settings (gear) → Drives → Add → find `virtio-win.iso` in `/Applications/UTM.app/Contents/Resources/qemu/`
6. Check **Include subfolders** → **Next**
7. Windows finds and installs the VirtIO network driver
8. Verify: Ethernet Controller moves to **Network adapters**

---

## Windows 11: Configure Static IP via Settings GUI {#windows-static-ip}

Referenced from: [03-network-setup.md](03-network-setup.md)

Use this if PowerShell method fails.

1. **Settings** → **System** → **Network & Internet** → **Ethernet**
2. Click the connected adapter name
3. Next to "IP assignment" → click **Edit**
4. Switch dropdown from "Automatic (DHCP)" to **Manual**
5. Toggle **IPv4** to On
6. Enter:
   - IP address: `192.168.64.20`
   - Subnet mask prefix length: `24`
   - Gateway: `192.168.64.1`
   - Preferred DNS: `192.168.64.1`
   - Alternate DNS: `8.8.8.8`
7. Click **Save**
8. Open Command Prompt → `ipconfig` → verify `192.168.64.20` appears

---

## Windows 11: Disable Windows Defender for Attack Simulation

Referenced from: [08-attack-simulation.md](08-attack-simulation.md)

> Re-enable after each attack session. Leaving Defender disabled permanently defeats the purpose of the lab.

1. Open **Windows Security** (search "Windows Security" in Start)
2. Click **Virus & threat protection**
3. Under "Virus & threat protection settings" → click **Manage settings**
4. Toggle **Real-time protection** → **Off**
5. Confirm UAC prompt

**Re-enable after attack simulation:**
- Toggle Real-time protection back to **On**
- Or run: `Set-MpPreference -DisableRealtimeMonitoring $false` in Administrator PowerShell

---

## UTM: Take Snapshots {#utm-snapshots}

Take snapshots before risky operations (installing packages, attack simulations). Snapshot restoration is the fastest way to reset a VM to clean state.

**Create a snapshot:**
1. In UTM VM list, right-click the VM name
2. Select **New Snapshot**
3. Name: `clean-baseline-YYYY-MM-DD` (e.g., `clean-baseline-2026-05-12`)
4. Click **New Snapshot**

**Restore a snapshot:**
1. Right-click the VM → **Restore Snapshot**
2. Select the snapshot name → **Restore**
3. Confirm: this rolls back all disk changes to the snapshot point

**Recommended snapshot schedule:**

| VM | When to snapshot | Name |
|----|-----------------|------|
| wazuh-manager | After Step 4 (Wazuh installed) | `wazuh-installed-YYYY-MM-DD` |
| victim-windows | After Step 6 (Wazuh agent + Sysmon) | `agent-sysmon-installed-YYYY-MM-DD` |
| kali-attacker | After Step 7 (tools installed) | `tools-installed-YYYY-MM-DD` |
| victim-windows | Before each attack session | `pre-attack-YYYY-MM-DD-HH` |

---

## Kibana: Initial Dashboard Configuration

Referenced from: [09-detection-validation.md](09-detection-validation.md)

After Wazuh agents are connected and events are flowing:

1. Open `https://192.168.64.10` in Mac browser → log in as `admin`
2. Navigate to **Wazuh** (left sidebar) → **Overview**
3. Click **Agents** → verify both agents show green **Active** status
4. Click **Security Events** → confirm events are flowing (check the count > 0)
5. Navigate to **MITRE ATT&CK** → confirm technique coverage shows your detected techniques
6. Navigate to **Dashboards** (Kibana native, not Wazuh) → click **Create dashboard**:
   - Add a visualization: **Security Events Timeline** (line chart by `@timestamp`)
   - Add: **Top Rule IDs** (terms aggregation on `rule.id`, size 10)
   - Add: **Alert Severity Distribution** (terms on `rule.level`)
   - Click **Save** → name: `SOC Lab — Attack Overview`

---

## UTM: Eject ISO After Installation

After any VM OS installation, eject the ISO so the VM doesn't boot back into the installer on next start.

1. In UTM, click the VM (or right-click → Edit)
2. Go to the **Drives** section
3. Find the CD/DVD drive that has the ISO path filled in
4. Click the **X** to clear the ISO path (or click the drive and press Delete)
5. Save settings

**UTM usually does this automatically** when the installer calls for reboot — but verify if a VM boots into the installer again.

---

## Notes

- Complete all GUI steps before running Ansible automation (Steps 3+ are SSH/CLI-based)
- The UTM console window shows VM output even if you lose SSH — always available as a fallback
- Take the "clean-baseline" snapshot on each VM before running any attack scenarios
- If UTM shows a VM as "stopped" unexpectedly, check Activity Monitor on your Mac for high memory pressure — you may have exceeded RAM and macOS killed a QEMU process

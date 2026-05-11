# Manual Steps — GUI-Required Operations

These steps require direct GUI interaction with UTM or a VM console and cannot be scripted. Complete them before running Ansible automation.

---

## UTM: Create wazuh-manager VM

1. Open UTM → Click **+** (new VM)
2. Select **Virtualize** (not Emulate) → **Linux**
3. Boot ISO: select `ubuntu-24.04-live-server-arm64.iso`
4. CPU: 4 cores | RAM: 8192 MB
5. Disk: 60 GB → click **New Drive**
6. Name: `wazuh-manager` → **Save**
7. Start VM → complete Ubuntu text installer
   - Language: English
   - Hostname: `wazuh-manager`
   - Username: `ubuntu` | Password: (set one)
   - OpenSSH: **Install OpenSSH server — YES**
   - Import SSH key: paste your `~/.ssh/soc-lab.pub` content
   - Guided storage: use entire disk, no LVM
8. After install: **Reboot** → unmount ISO in UTM (Drive → Eject)

---

## UTM: Create victim-windows VM (VHDX Import)

1. Open UTM → Click **+** → **Virtualize** → **Windows**
2. Select **Import VHDX** → choose `Windows11_InsiderPreview_Client_ARM64.vhdx`
3. CPU: 4 cores | RAM: 4096 MB
4. Enable **TPM** and **UEFI** (required for Windows 11)
5. Network: **Shared Network**
6. Name: `victim-windows` → **Save**
7. Start VM → complete Windows OOBE
   - Use local account (skip Microsoft account sign-in): press `Shift+F10` → `oobe\bypassnro` trick if needed
   - Computer name: `VICTIM-WIN`
8. Install VirtIO network drivers (UTM mounts these automatically on first boot — check Device Manager for "Ethernet Controller" → Update Driver → search UTM CD drive)

---

## UTM: Create kali-attacker VM

1. Open UTM → Click **+** → **Virtualize** → **Linux**
2. Boot ISO: select `kali-linux-2024.x-installer-arm64.iso`
3. CPU: 4 cores | RAM: 4096 MB | Disk: 40 GB
4. Display: VGA | Network: **Shared Network**
5. Name: `kali-attacker` → **Save**
6. Start VM → complete Kali graphical installer
   - Hostname: `kali-attacker`
   - Username: `kali` | Password: (set one)
   - Desktop: Xfce (recommended for ARM performance)
   - SSH server: **Yes**
7. After install: reboot → eject ISO in UTM

---

## Windows 11: Disable Windows Defender (Optional, for Attack Simulation)

Windows Defender will quarantine Sliver implants before they execute. For attack simulation purposes:

1. Open **Windows Security** → **Virus & threat protection**
2. Click **Manage settings** under "Virus & threat protection settings"
3. Toggle **Real-time protection** → **Off**
4. Confirm the UAC prompt

> Re-enable after attack simulation if you want to test AV evasion separately.

---

## Windows 11: Configure Static IP via Settings GUI

1. Settings → System → Network & internet → Ethernet
2. Click the connected adapter name
3. Next to "IP assignment" → **Edit**
4. Switch to **Manual** → enable **IPv4**
5. Enter:
   - IP: `192.168.64.20`
   - Subnet mask: `255.255.255.0`
   - Gateway: `192.168.64.1`
   - DNS: `192.168.64.1`
6. Click **Save**

---

## UTM: Snapshot Before Attack Simulation

Before running attack scenarios, snapshot all VMs so you can restore to clean state:

1. In UTM, right-click each VM → **New Snapshot**
2. Name: `clean-baseline-YYYY-MM-DD`

Restore a snapshot via: right-click VM → **Restore Snapshot** → select snapshot name.

---

## Kibana: Initial Dashboard Setup

1. Open `https://192.168.64.10:5601` in Mac browser
2. Log in with credentials from Wazuh install output
3. Navigate to: **Wazuh** (via left menu) → **Overview**
4. Click **Agents** → verify both agents show as Active
5. Click **Security events** → verify events are flowing

---

## Notes

- All GUI steps above should be completed before running `ansible-playbook site.yml`
- Record the UTM-assigned initial DHCP IPs (check UTM info panel) to SSH in before setting static IPs
- Windows requires a reboot after network driver install and after static IP assignment

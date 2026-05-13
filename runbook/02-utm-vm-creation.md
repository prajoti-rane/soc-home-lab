# Step 2: UTM VM Creation

Create three VMs in UTM. This step is entirely GUI-based — no terminal commands until Step 3.

**Estimated time:** 60–90 minutes (most of this is waiting for OS installers)

> All three VMs use **Virtualize** mode (native ARM64). Never select "Emulate" — it's 10x slower.

---

## VM Overview

| VM | OS | CPU | RAM | Disk | Role |
|----|-----|-----|-----|------|------|
| wazuh-manager | Ubuntu 24.04 LTS ARM64 | 4 cores | 8 GB | 60 GB | SIEM + ELK |
| victim-windows | Windows 11 ARM64 | 4 cores | 4 GB | 40 GB | Monitored endpoint |
| kali-attacker | Kali Linux ARM64 | 4 cores | 4 GB | 40 GB | Red team platform |

> If you have only 16 GB RAM: create all VMs but run only 2 simultaneously. Start wazuh-manager first (it needs the most RAM), then the VM you're actively working on.

---

## VM 1: wazuh-manager (Ubuntu 24.04)

### Create the VM

1. Open **UTM** → click **+** (top left) or select **File → New Virtual Machine**
2. Select **Virtualize** ← (not Emulate)
3. Select **Linux**
4. Under "Boot ISO Image":
   - Click **Browse** → navigate to `~/Downloads/SOC-Lab-ISOs/`
   - Select `ubuntu-24.04.x-live-server-arm64.iso`
   - Click **Open**
5. Hardware settings:
   - **CPU Cores:** 4
   - **Memory:** 8192 MB
   - Leave other hardware at defaults
6. Storage:
   - **Size:** 64 GB  (UTM rounds up — you'll get ~60 GB usable)
7. Shared Directory: **Skip** (click Next without selecting anything)
8. Summary page:
   - **Name:** `wazuh-manager`
   - Check "Open VM Settings" if you want to review before saving
9. Click **Save**

### Install Ubuntu Server

Click the **Play** button (▶) to start the VM. A console window opens.

Ubuntu ARM64 uses a text-based installer. Navigate with **Arrow keys** and **Tab**, select with **Space**, confirm with **Enter**.

Follow these exact selections:

**Language screen:**
- Select: `English` → Enter

**Keyboard layout:**
- Layout: `English (US)` → Done

**Type of install:**
- Select: `Ubuntu Server` (not minimized) → Done

**Network connections:**
- Leave DHCP default (shows something like `enp0s1: DHCP with address 192.168.64.x`) → Done
- We'll switch to static IP in Step 3 after the OS is installed.

**Configure proxy:**
- Leave blank → Done

**Configure Ubuntu archive mirror:**
- Leave default (`http://ports.ubuntu.com/ubuntu-ports`) → Done
- Wait for the "mirror location" test to complete (30–60 seconds)

**Guided storage configuration:**
- Select: `Use an entire disk`
- Disk to use: `QEMU QEMU HARDDISK` (the only option)
- Leave "Set up this disk as an LVM group" **unchecked** — LVM adds complexity we don't need
- → Done

**Storage configuration — confirm layout:**
- Review the layout shown (should show entire 64 GB allocated)
- → Done
- Confirm popup: select **Continue** (this will erase the virtual disk — that's fine)

**Profile setup:**
```
Your name:    SOC Admin
Your server's name:  wazuh-manager
Pick a username:     ubuntu
Choose a password:   [pick one — write it down]
Confirm password:    [same]
```
→ Done

**SSH Setup:**
- `Install OpenSSH server` → **press Space to check the box** ← important
- Import SSH identity:
  - Select `from GitHub` if you have your public key on GitHub
  - Or select `No` and we'll copy the key manually in Step 3
- → Done

**Featured server snaps:**
- Leave everything **unchecked** → Done

**Wait for installation to complete.** This takes 3–8 minutes. You'll see a progress bar. Do not close the UTM window.

When installation finishes, you'll see: `[ OK ] Reached target ...` and a prompt saying "Reboot Now":
- Press Enter to reboot

**After reboot:**
- UTM will eject the ISO automatically (if not: click the CD icon in UTM → Eject)
- The login prompt appears: `wazuh-manager login:`
- Log in: username `ubuntu`, password you set above

**Get the DHCP IP address:**
```
ubuntu@wazuh-manager:~$ ip addr show enp0s1
```

Look for `inet 192.168.64.x/24` — note this IP. You'll SSH from your Mac using it.

**Verify internet access from the VM:**
```
ubuntu@wazuh-manager:~$ ping -c 3 8.8.8.8
```
Expected: 3 packets received. If this fails, check UTM network mode (should be Shared Network).

---

## VM 2: victim-windows (Windows 11 ARM64)

### Option A: Import VHDX (if you have a Windows 11 VHDX)

1. Open UTM → click **+** → **Virtualize** → **Windows**
2. Select **Import VHDX Image** → Browse → select your `.vhdx` file → Open
3. Hardware:
   - CPU: 4 cores
   - Memory: 4096 MB
4. Make sure **TPM** and **UEFI** are enabled (required for Windows 11 — UTM enables these automatically when you select Windows)
5. Network: Shared Network (default)
6. Name: `victim-windows` → Save

### Option B: Install from ISO

1. Open UTM → click **+** → **Virtualize** → **Windows**
2. Under "Boot ISO Image": Browse → select your Windows 11 ARM64 ISO
3. Hardware:
   - CPU: 4 cores
   - Memory: 4096 MB
4. Storage: 40 GB
5. Name: `victim-windows` → Save

### Install Windows (OOBE Setup)

Click **Play** to start the VM. The Windows setup wizard runs in a graphical window.

**Windows Setup wizard (language/region):**
- Language: English (United States)
- Time and currency format: English (United States)
- Keyboard: US
- Click **Next** → **Install now**

**License key:**
- Click **I don't have a product key** (you can activate later)

**Edition:**
- Select **Windows 11 Pro** → Next

**License agreement:** Accept → Next

**Installation type:**
- Click **Custom: Install Windows only (advanced)**
- Select the unallocated drive → Next
- Windows installs — wait 5–15 minutes, VM reboots automatically

**OOBE (Out-of-Box Experience):**

> **Important:** Windows 11 tries to force a Microsoft account. Use this workaround for a local account:

- At the "Let's add your Microsoft account" screen:
  - Press `Shift + F10` → a Command Prompt opens
  - Type: `oobe\bypassnro` → Enter
  - The VM reboots and returns to OOBE
  - Now the "I don't have internet" option appears — click it → "Continue with limited setup"

- **Computer name:** `VICTIM-WIN`
- **Username:** `socadmin`
- **Password:** [choose one — write it down]
- Security questions: answer 3 (or type random answers — this is a lab)
- Privacy settings: toggle everything **Off** → Accept

**Install VirtIO network drivers (critical — no internet without this):**

After Windows desktop loads, open **Device Manager** (right-click Start → Device Manager):
- Look for a yellow warning icon on "Ethernet Controller" under "Other devices"
- Right-click → **Update driver** → **Browse my computer for drivers**
- Browse to the UTM-mounted CD drive (check File Explorer — UTM mounts a VirtIO ISO)
- Select the drive → search subfolders → click **Next**
- Windows finds and installs the network driver
- The Ethernet Controller moves to "Network adapters"

If UTM didn't auto-mount the VirtIO drivers ISO:
- In UTM, click the VM settings (gear icon) → Drives → Add Drive → select the VirtIO ISO from UTM's resources directory (`/Applications/UTM.app/Contents/Resources/`)

**Verify network (after driver install):**
- Open Command Prompt: `ipconfig`
- Look for `IPv4 Address: 192.168.64.x` — note this IP

---

## VM 3: kali-attacker (Kali Linux ARM64)

### Create the VM

1. Open UTM → click **+** → **Virtualize** → **Linux**
2. Boot ISO: Browse → select `kali-linux-2024.x-installer-arm64.iso` → Open
3. Hardware:
   - CPU: 4 cores
   - Memory: 4096 MB
4. Storage: 40 GB
5. Shared Directory: Skip
6. Name: `kali-attacker` → Save

### Install Kali Linux

Click **Play**. Kali uses a graphical installer.

**Boot menu:**
- Select **Graphical install** (or just **Install** if graphics are slow)

**Language:** English → Continue

**Location:** Your country (or United States) → Continue

**Keyboard:** American English → Continue

**Hostname:** `kali-attacker` → Continue

**Domain name:** Leave blank → Continue

**User setup:**
- Full name: `Kali` (or anything)
- Username: `kali`
- Password: [choose one — write it down]

**Disk partitioning:**
- Select: **Guided — use entire disk**
- Select the available disk (QEMU HARDDISK)
- Partitioning scheme: **All files in one partition**
- Finish partitioning and write changes to disk → **Yes**

**Package manager:**
- Debian archive mirror: choose your country → Continue
- HTTP proxy: leave blank → Continue

**Software selection:**
- Select: **[X] Xfce** (fastest ARM performance) + **[X] standard system utilities**
- Select: **[X] SSH server** ← required for Step 3
- Click **Continue** — this installs packages (5–15 minutes)

**GRUB bootloader:**
- Install to `/dev/vda` → Continue

Installation complete → **Continue** → VM reboots.

After reboot → log in with username `kali` and your password.

**Verify network:**
```bash
# [kali — VM console]
ip addr show
```
Look for `inet 192.168.64.x/24`. Note the IP.

---

## Post-Creation: SSH Access from Mac

After all three VMs are running and networked, verify SSH access from your Mac:

```bash
# [host] SSH to wazuh-manager (use the DHCP IP from Ubuntu install)
ssh ubuntu@192.168.64.10
# If 10 doesn't work, check the actual DHCP IP from the VM console
# Accept the host key fingerprint (type 'yes')

# [host] SSH to kali-attacker
ssh kali@192.168.64.30
```

For Windows: use Microsoft Remote Desktop app (free on Mac App Store):
- PC name: `192.168.64.20`
- Username: `socadmin`
- Password: your Windows password

---

## Troubleshooting

**"Virtualize is greyed out / unavailable"**
UTM shows this if your Mac is in Rosetta emulation mode or if there's a macOS security restriction. Open Terminal → `uname -m` → confirm `arm64`. Restart UTM.

**Ubuntu installer hangs at "Configuring apt"**
This sometimes happens if the mirror test is slow. Wait up to 5 minutes. If it never proceeds, press Ctrl+C and manually select the archive mirror step again.

**Windows OOBE won't show "I don't have internet"**
Try the Shift+F10 → `oobe\bypassnro` method described above. If that fails, disconnect the network interface temporarily in UTM VM settings (pause networking), complete OOBE, then re-enable.

**Windows device manager shows no VirtIO drive to browse**
In UTM → click your Windows VM → Edit (pencil icon) → Drives section → look for an existing "CD/DVD" drive. If it's empty, change its path to the VirtIO ISO. The VirtIO ISO is at:
```
/Applications/UTM.app/Contents/Resources/qemu/virtio-win.iso
```

**Kali installer hangs at "Configuring network"**
Select **Cancel** when prompted — network config can be done post-install. Kali will still install. Complete network setup in Step 3.

**VM shows 192.168.64.x but Mac can't ping it**
Verify the VM's UTM network adapter is set to **Shared Network** (not "Bridged" or "None"):
UTM → right-click VM → Edit → Network section → Network Mode: Shared Network.

---

## Checklist — Step 2 Complete When:

- [ ] wazuh-manager: Ubuntu boots, SSH works, `ip addr` shows 192.168.64.x
- [ ] victim-windows: Windows desktop loads, VirtIO network driver installed, `ipconfig` shows 192.168.64.x
- [ ] kali-attacker: Kali boots, SSH works from Mac, `ip addr` shows 192.168.64.x
- [ ] All 3 VMs can ping `192.168.64.1` (UTM gateway)
- [ ] UTM snapshot taken of each VM at this clean state (see [MANUAL_STEPS.md](MANUAL_STEPS.md))

**Next step → [03-network-setup.md](03-network-setup.md)**

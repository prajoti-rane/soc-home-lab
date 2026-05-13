# Step 1: Prerequisites

Install everything on your Mac and download the required ISOs before creating any VMs.

**Estimated time:** 30 minutes + ISO download time (Ubuntu ~1.5 GB, Kali ~4 GB)

---

## 1.1 — Verify Hardware

```bash
# [host] Confirm Apple Silicon
uname -m
# Expected: arm64
# If you see x86_64, stop — this lab is ARM64-only.

# [host] Check available RAM (returns bytes — divide by 1073741824 for GB)
sysctl -n hw.memsize
# Expected: >= 17179869184  (16 GB)
# 8 GB is possible but you'll need to run VMs one at a time.

# [host] Check free disk space
df -h ~
# Look at the "Avail" column for your home partition.
# Expected: >= 150Gi
# You need: wazuh-manager 60 GB + victim-windows 40 GB + kali-attacker 40 GB + ISOs ~15 GB = 155 GB
```

---

## 1.2 — Install UTM

UTM is a free virtualization app for Apple Silicon.

1. Open your browser and go to: **https://mac.getutm.app**
2. Click **Download** → save `UTM.dmg` to Downloads
3. Open `UTM.dmg` → drag UTM to Applications
4. Open UTM from Applications (accept Gatekeeper prompt if shown)
5. Verify: UTM opens to an empty VM list

> **Alternative:** UTM is also on the Mac App Store ($10) — the paid version is identical but funds development. The free version from mac.getutm.app is fully functional.

Minimum version: **UTM 4.x**. Check via UTM menu → About UTM.

---

## 1.3 — Install Homebrew

Homebrew is the package manager for everything else.

```bash
# [host] Check if already installed
brew --version
# If this returns a version, skip to 1.4.

# [host] Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

The installer will prompt for your Mac password (to install to `/opt/homebrew`). Follow all on-screen instructions including the "Next steps" at the end — you need to add Homebrew to your PATH.

After installation, open a **new terminal tab** and verify:

```bash
brew --version
# Expected: Homebrew 4.x.x
```

---

## 1.4 — Install Required Tools

```bash
# [host] Install all tools in one command
brew install ansible git gh python3

# Or install individually if one fails:
brew install ansible    # Ansible automation engine
brew install git        # Version control
brew install gh         # GitHub CLI
brew install python3    # Python 3 interpreter
```

### Verify installations

```bash
# [host]
ansible --version
# Expected first line: ansible [core 2.16.x] or later
# If you see 2.15 or older: brew upgrade ansible

git --version
# Expected: git version 2.x.x

gh --version
# Expected: gh version 2.x.x

python3 --version
# Expected: Python 3.11.x or later
# If you see 3.9 or 3.10: brew install python@3.11
```

> **If brew install fails with "formula not found":** run `brew update` first, then retry.

---

## 1.5 — Authenticate GitHub CLI

The GitHub CLI is used to push your work and potentially clone private repos.

```bash
# [host]
gh auth login
# Select: GitHub.com → HTTPS → Yes (authenticate Git) → Login with browser
# Your browser opens → authorize the CLI → return to terminal
# Expected: "Logged in as <your-username>"

# [host] Verify
gh auth status
```

---

## 1.6 — Set Up SSH Keys

SSH keys are used to access the Linux VMs without passwords.

```bash
# [host] Check if you already have a key
ls -la ~/.ssh/*.pub 2>/dev/null
# If any .pub files exist, skip to "Add to SSH agent" below.

# [host] Generate a new key for the lab (if no key exists)
ssh-keygen -t ed25519 -C "soc-lab" -f ~/.ssh/soc-lab
# Press Enter twice to use no passphrase (or set one for extra security)
# Creates: ~/.ssh/soc-lab (private) and ~/.ssh/soc-lab.pub (public)

# [host] Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/soc-lab

# [host] Verify key is loaded
ssh-add -l
# Expected: shows your key fingerprint

# [host] Print your public key — you'll paste this during VM installs
cat ~/.ssh/soc-lab.pub
```

Save the public key contents somewhere accessible (Notes app, clipboard) — you'll need to paste it into the Ubuntu and Kali installers in Step 2.

---

## 1.7 — Clone This Repository

```bash
# [host]
mkdir -p ~/Projects
cd ~/Projects
git clone https://github.com/prajoti-rane/soc-home-lab.git
cd soc-home-lab

# Verify
ls
# Expected: ansible  architecture  attack-simulation  dashboards  ...
```

If you already have the repo cloned, make sure it's up to date:

```bash
# [host]
cd ~/Projects/soc-home-lab
git pull origin main
```

---

## 1.8 — Install Ansible Collections

```bash
# [host]
cd ~/Projects/soc-home-lab
ansible-galaxy install -r ansible/requirements.yml

# Verify
ansible-galaxy collection list
# Expected output includes:
#   ansible.windows  2.x.x
#   ansible.posix    1.x.x
#   community.general x.x.x
```

> **If you get "ERROR! couldn't resolve module/action"** when running playbooks later, re-run this command.

---

## 1.9 — Download ISOs

### Option A: Automated download (Ubuntu + Kali)

```bash
# [host] Creates ~/Downloads/SOC-Lab-ISOs/ and downloads Ubuntu + Kali ARM64 ISOs
bash ~/Projects/soc-home-lab/scripts/download-isos.sh
```

This script downloads Ubuntu 24.04 LTS ARM64 and Kali Linux ARM64 with SHA256 verification. Download time varies (Ubuntu ~1.5 GB, Kali ~4 GB).

### Option B: Manual download

Download these files and save them to `~/Downloads/SOC-Lab-ISOs/`:

| OS | URL | Filename pattern |
|----|-----|-----------------|
| **Ubuntu 24.04 LTS ARM64** | https://cdimage.ubuntu.com/releases/noble/release/ | `ubuntu-24.04.x-live-server-arm64.iso` |
| **Kali Linux ARM64** | https://www.kali.org/get-kali/#kali-installer-images | `kali-linux-2024.x-installer-arm64.iso` |

### Windows 11 ARM64

Windows 11 ARM64 is not available for direct download from Microsoft without an Insider subscription. The recommended method is **UUPDump**:

1. Open your browser → go to **https://uupdump.net**
2. Search for "Windows 11 ARM64"
3. Select the latest stable release → choose language "English" → edition "Windows 11 Pro"
4. Download the build script package (a `.zip` with a `uup_download_*.cmd` script)
5. Unzip → run the `.cmd` script — it downloads and converts to ISO automatically
   - Requires: a Windows or Linux machine (or a VM you already have)
   - Alternative: use a pre-built ISO from the Microsoft Insider Preview program if you have access
6. Move the resulting ISO to `~/Downloads/SOC-Lab-ISOs/`

> **Note:** The Windows image is a VHDX or ISO (~5 GB). If you use the VHDX from Microsoft Insider, it can be imported directly into UTM without creating an ISO.

### Verify downloads

```bash
# [host]
ls -lh ~/Downloads/SOC-Lab-ISOs/
# Expected:
# ubuntu-24.04.x-live-server-arm64.iso   ~1.5 GB
# kali-linux-2024.x-installer-arm64.iso  ~3.5–4 GB
# Windows11*.iso or *.vhdx               ~4–5 GB
```

---

## 1.10 — Run the Prerequisites Check Script

After completing all steps above, run the automated check:

```bash
# [host]
cd ~/Projects/soc-home-lab
bash scripts/check-prereqs.sh
```

Expected output (all green):

```
============================================
  SOC Home Lab — Prerequisites Check
  2026-05-12 10:30:00
============================================

[ Mac Architecture ]
  [PASS] Apple Silicon (arm64) — ARM64 VMs will run natively
  [PASS] macOS 14.x (>= Ventura 13 required for UTM 4.x)

[ UTM ]
  [PASS] UTM 4.x installed at /Applications/UTM.app

[ Command-Line Tools ]
  [PASS] Homebrew: Homebrew 4.x.x
  [PASS] Ansible 2.16.x (>= 2.16 required)
  [PASS] Git 2.x.x
  [PASS] GitHub CLI 2.x.x
  [PASS] Python 3.11.x (>= 3.11 required)

[ SSH Keys ]
  [PASS] SSH public key found: /Users/you/.ssh/soc-lab.pub (ED25519)
  [PASS] SSH agent has key(s) loaded

[ Disk Space ]
  [PASS] Free disk: 180 GB  (150 GB minimum for all 3 VMs)

[ Memory ]
  [PASS] RAM: 16 GB  (16 GB minimum)

[ Repository ]
  [PASS] Repository found at /Users/you/Projects/soc-home-lab
  [PASS] Ansible collection ansible.windows installed

[ ISO Downloads ]
  [PASS] Ubuntu ARM64 ISO: ubuntu-24.04.x-live-server-arm64.iso
  [PASS] Kali ARM64 ISO: kali-linux-2024.x-installer-arm64.iso
  [PASS] Windows 11 ARM64 image: Windows11_...iso

============================================
  Results: 14 passed · 0 warnings · 0 failed
============================================

  All checks passed.  Proceed to: runbook/02-utm-vm-creation.md
```

If any item shows `[FAIL]`, fix it before continuing. `[WARN]` items are non-blocking but should be reviewed.

---

## Common Problems

**`brew: command not found` after install**
Homebrew requires adding itself to `PATH`. Follow the "Next steps" printed by the installer:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**`ansible-galaxy install` fails with SSL error**
```bash
pip3 install --upgrade pip
pip3 install ansible
# Then retry ansible-galaxy install -r ansible/requirements.yml
```

**`gh auth login` opens wrong browser**
```bash
gh auth login --web
# Or: gh auth login --with-token  (paste a GitHub personal access token)
```

**Not enough disk space**
- Delete unused Xcode simulators: `xcrun simctl delete unavailable`
- Move large files to external drive
- The minimum is 150 GB; 100 GB will work but you'll need to be careful with snapshot management.

---

## Checklist — Step 1 Complete When:

- [ ] `uname -m` returns `arm64`
- [ ] Free disk >= 150 GB
- [ ] RAM >= 16 GB (or accepted limitation)
- [ ] UTM 4.x installed in `/Applications/`
- [ ] `ansible --version` shows 2.16+
- [ ] `git --version`, `gh --version`, `python3 --version` all return output
- [ ] `gh auth status` shows "Logged in as ..."
- [ ] SSH public key exists and is loaded in agent (`ssh-add -l`)
- [ ] Repo cloned to `~/Projects/soc-home-lab/`
- [ ] `ansible-galaxy install` completed without errors
- [ ] Ubuntu + Kali + Windows ISOs in `~/Downloads/SOC-Lab-ISOs/`
- [ ] `bash scripts/check-prereqs.sh` shows all PASS

**Next step → [02-utm-vm-creation.md](02-utm-vm-creation.md)**

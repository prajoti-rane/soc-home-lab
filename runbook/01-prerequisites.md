# Step 1: Prerequisites

Install these tools on your Mac and download the required ISOs before creating any VMs.

## Mac Tools

```bash
# [host] Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# [host] Install required tools
brew install ansible git gh python3

# [host] Verify versions
ansible --version   # expect 2.16+
python3 --version   # expect 3.11+
gh --version        # expect 2.x
```

## UTM Installation

Download UTM from [mac.getutm.app](https://mac.getutm.app) (free) or Mac App Store.

Minimum version: UTM 4.x

## ISO Downloads

Download these ARM64 ISOs to your Mac (save to `~/Downloads/`):

| OS | Download URL | File |
|----|-------------|------|
| Ubuntu 24.04 LTS Server ARM64 | ubuntu.com/download/server/arm | `ubuntu-24.04-live-server-arm64.iso` |
| Kali Linux ARM64 | kali.org/get-kali/#kali-installer-images | `kali-linux-2024.x-installer-arm64.iso` |
| Windows 11 ARM64 | Microsoft MSDN / UUP dump | `Windows11_InsiderPreview_Client_ARM64.vhdx` |

**Note:** Windows 11 ARM64 is distributed as a VHDX (virtual hard disk), not an ISO. Download from the Microsoft Insider Preview program or generate via UUP dump. This is a manual step — see [MANUAL_STEPS.md](MANUAL_STEPS.md).

## SSH Key Setup

```bash
# [host] Generate SSH key for VM access if you don't have one
ssh-keygen -t ed25519 -C "soc-lab" -f ~/.ssh/soc-lab

# [host] Add to SSH agent
ssh-add ~/.ssh/soc-lab
```

## Clone This Repository

```bash
# [host]
mkdir -p ~/Projects
cd ~/Projects
git clone https://github.com/prajoti-rane/soc-home-lab.git
cd soc-home-lab
```

## Ansible Dependencies

```bash
# [host] Install Ansible collections and roles
ansible-galaxy install -r ansible/requirements.yml
```

## Checklist Before Proceeding

- [ ] UTM 4.x installed on Mac
- [ ] Ubuntu 24.04 ARM64 ISO downloaded
- [ ] Kali Linux ARM64 ISO downloaded
- [ ] Windows 11 ARM64 VHDX obtained
- [ ] SSH key generated and added to agent
- [ ] Repo cloned to `~/Projects/soc-home-lab/`
- [ ] `ansible-galaxy install` completed without errors
- [ ] At least 160 GB free disk space confirmed (`df -h ~`)

# Runbook — SOC Home Lab Setup Guide

Step-by-step instructions for building the full SOC home lab on an Apple Silicon Mac using UTM virtualization. Follow steps in order — each step depends on the previous one.

**Estimated total time:** 6–8 hours hands-on (plus download/install wait time)

---

## Prerequisites

Before you start, verify your Mac meets these requirements:

| Requirement | Minimum | Recommended | Check command |
|------------|---------|-------------|---------------|
| **CPU** | Apple Silicon (M1) | M2 Pro or later | `uname -m` → `arm64` |
| **RAM** | 16 GB | 24 GB | `sysctl -n hw.memsize` |
| **Free disk** | 150 GB | 200 GB | `df -h ~` |
| **macOS** | 13 Ventura | 14 Sonoma or later | `sw_vers` |
| **Internet** | Stable broadband | — | — |

Run the prerequisites check script before doing anything else:

```bash
# [host]
cd ~/Projects/soc-home-lab
bash scripts/check-prereqs.sh
```

All `[PASS]` required before proceeding. See [01-prerequisites.md](01-prerequisites.md) to install anything that fails.

---

## Step Order and Dependencies

| Step | File | Description | Est. time | Depends on |
|------|------|-------------|-----------|-----------|
| 1 | [01-prerequisites.md](01-prerequisites.md) | Install tools, download ISOs | 30 min + download | — |
| 2 | [02-utm-vm-creation.md](02-utm-vm-creation.md) | Create 3 VMs in UTM GUI | 60–90 min | Step 1 |
| 3 | [03-network-setup.md](03-network-setup.md) | Configure static IPs, test connectivity | 20 min | Step 2 |
| 4 | [04-wazuh-elk-install.md](04-wazuh-elk-install.md) | Install Wazuh + ELK on Ubuntu | 45–60 min | Step 3 |
| 5 | [05-sysmon-setup.md](05-sysmon-setup.md) | Install Sysmon on Windows ARM64 | 20 min | Step 3 |
| 6 | [06-agent-deployment.md](06-agent-deployment.md) | Deploy Wazuh agents, verify events | 20 min | Steps 4 + 5 |
| 7 | [07-kali-setup.md](07-kali-setup.md) | Install Sliver, ART, attack tools | 30 min | Step 3 |
| 8 | [08-attack-simulation.md](08-attack-simulation.md) | Execute attack scenarios | 60 min | Steps 6 + 7 |
| 9 | [09-detection-validation.md](09-detection-validation.md) | Validate rules, review Kibana | 30 min | Step 8 |

**Dependency graph:**

```
Step 1 (Prerequisites)
    └── Step 2 (VM Creation)
            └── Step 3 (Network)
                    ├── Step 4 (Wazuh/ELK)
                    │       └── Step 6 (Agents) ──┐
                    ├── Step 5 (Sysmon) ───────────┤
                    │                              ├── Step 8 (Attack)
                    └── Step 7 (Kali) ─────────────┤
                                                   └── Step 9 (Validate)
```

Steps 4, 5, and 7 can be done in any order once Step 3 is complete.

---

## Where to Start

**→ [Step 1: Prerequisites](01-prerequisites.md)**

If you have all 3 VMs already created and networked, jump to:
- **→ [Step 4: Wazuh/ELK Install](04-wazuh-elk-install.md)** to install the SIEM
- **→ [Step 5: Sysmon](05-sysmon-setup.md)** to set up Windows telemetry

---

## Conventions Used in This Runbook

Commands are prefixed with the machine where they run:

| Prefix | Machine | IP | How to connect |
|--------|---------|-----|----------------|
| `[host]` | Your Mac | — | Terminal.app or iTerm2 |
| `[manager]` | wazuh-manager (Ubuntu 24.04) | 192.168.64.10 | `ssh ubuntu@192.168.64.10` |
| `[windows]` | victim-windows (Windows 11 ARM64) | 192.168.64.20 | RDP or UTM console |
| `[kali]` | kali-attacker (Kali Linux ARM64) | 192.168.64.30 | `ssh kali@192.168.64.30` |

Code blocks are exact — copy-paste them verbatim unless a comment says to substitute a value.

---

## GUI-Only Steps

Some steps require the UTM GUI or a VM graphical interface and cannot be scripted. They are consolidated in [MANUAL_STEPS.md](MANUAL_STEPS.md) and referenced inline where they occur. Complete them as they come up; don't skip ahead.

---

## Lab IP Reference

| Hostname | Role | IP | OS |
|---------|------|-----|-----|
| wazuh-manager | SIEM + ELK stack | 192.168.64.10 | Ubuntu 24.04 LTS ARM64 |
| victim-windows | Monitored endpoint | 192.168.64.20 | Windows 11 ARM64 |
| kali-attacker | Red team platform | 192.168.64.30 | Kali Linux ARM64 |
| (UTM gateway) | NAT + DNS relay | 192.168.64.1 | UTM internal |

---

## If Something Goes Wrong

1. **Check the troubleshooting section** at the bottom of each step file first.
2. **Take a UTM snapshot before risky steps** (installing packages, changing network config). See [MANUAL_STEPS.md → UTM Snapshots](MANUAL_STEPS.md#utm-snapshots).
3. **Search existing GitHub issues** in this repo for your error message.
4. **Reset to clean state**: restore the snapshot taken before the failing step.

---

## Quick-Start (Experienced Users)

If you've done this before or just need reminders:

```bash
# [host] Verify prereqs
bash scripts/check-prereqs.sh

# [host] Download ISOs
bash scripts/download-isos.sh

# Create 3 VMs in UTM (GUI — see MANUAL_STEPS.md)

# [manager] Install Wazuh stack
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.x/config.yml
# Edit config.yml, then:
bash wazuh-install.sh --generate-config-files
bash wazuh-install.sh --wazuh-indexer node-1
bash wazuh-install.sh --wazuh-server wazuh-1
bash wazuh-install.sh --wazuh-dashboard dashboard

# [windows] Install Sysmon + Wazuh agent (see Steps 5-6)

# [kali] Install Sliver + tools (see Step 7)
bash /path/to/attack-simulation/sliver/setup-sliver.sh

# [host] Run attack scenarios (see Step 8)
# [host] Validate detection rules (see Step 9)
bash scripts/validate-detections.sh
```

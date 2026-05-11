# Runbook — SOC Home Lab Setup Guide

This runbook walks through the complete setup of the SOC home lab from zero to a fully operational Wazuh + ELK environment with red team capability. Follow steps in order.

## Prerequisites

- macOS Apple Silicon Mac (M1/M2/M3)
- UTM installed
- ~4–6 hours of uninterrupted time
- 160 GB free disk space
- Stable internet connection (for ISO downloads and package installs)

## Step Order

| Step | File | What you'll do | Est. time |
|------|------|---------------|-----------|
| 1 | [01-prerequisites.md](01-prerequisites.md) | Install tools on Mac, download ISOs | 30 min |
| 2 | [02-utm-vm-creation.md](02-utm-vm-creation.md) | Create 3 VMs in UTM GUI | 45 min |
| 3 | [03-network-setup.md](03-network-setup.md) | Configure static IPs, test connectivity | 20 min |
| 4 | [04-wazuh-elk-install.md](04-wazuh-elk-install.md) | Deploy Wazuh + ELK on Ubuntu manager | 60 min |
| 5 | [05-sysmon-setup.md](05-sysmon-setup.md) | Install Sysmon on Windows 11 ARM | 20 min |
| 6 | [06-agent-deployment.md](06-agent-deployment.md) | Deploy and register Wazuh agents | 20 min |
| 7 | [07-kali-setup.md](07-kali-setup.md) | Install Sliver, ART, and tools on Kali | 30 min |
| 8 | [08-attack-simulation.md](08-attack-simulation.md) | Execute attack scenarios | 60 min |
| 9 | [09-detection-validation.md](09-detection-validation.md) | Verify rules fire, review Kibana | 30 min |

## GUI-Only Steps

Some steps require UTM's graphical interface and cannot be scripted. See [MANUAL_STEPS.md](MANUAL_STEPS.md) for a consolidated list.

## Conventions

- `[manager]` — run on wazuh-manager (192.168.64.10) via SSH
- `[windows]` — run on victim-windows (192.168.64.20) via RDP or UTM console
- `[kali]` — run on kali-attacker (192.168.64.30) via SSH
- `[host]` — run on the macOS host
- Commands in code blocks are exact — copy-paste them verbatim

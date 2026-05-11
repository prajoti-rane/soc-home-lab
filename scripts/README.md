# Scripts

Utility and automation scripts for the SOC Home Lab. Run from the macOS host unless otherwise noted.

## Script Index

| Script | Language | Phase | Description |
|--------|----------|-------|-------------|
| `download-isos.sh` | Bash | 4 | Download and SHA256-verify Ubuntu + Kali ARM64 ISOs; print Windows 11 manual instructions |
| `generate-sysmon-config.sh` | Bash | 4 | Download SwiftOnSecurity Sysmon config, apply lab customizations, validate XML, install to ansible role |
| `validate-detections.sh` | Bash | 3 | Parse test-case YAML, feed log samples to wazuh-logtest via SSH, report PASS/FAIL per rule |

## Usage

### Download ISOs (Phase 4)

```bash
# Run from macOS host before building VMs
bash scripts/download-isos.sh

# Custom output directory
bash scripts/download-isos.sh ~/ISOs/

# Output: ~/Downloads/SOC-Lab-ISOs/
#   ubuntu-24.04.2-live-server-arm64.iso
#   kali-linux-2024.1-installer-arm64.iso
#   (Windows 11 instructions printed — manual download required)
```

### Regenerate Sysmon Config (Phase 4)

```bash
# Downloads latest SwiftOnSecurity config + applies lab customizations
bash scripts/generate-sysmon-config.sh

# Skip customizations (use SwiftOnSecurity base only)
bash scripts/generate-sysmon-config.sh --no-custom

# Output: ansible/roles/sysmon/files/sysmonconfig-export.xml
# Deploy: ansible-playbook playbooks/windows-victim.yml --tags sysmon
```

### Validate Detections (Phase 3)

```bash
# Requires: wazuh-manager VM running, SSH key, python3 + pyyaml
pip3 install pyyaml
bash scripts/validate-detections.sh

# Custom test cases directory
bash scripts/validate-detections.sh detections/test-cases/

# Environment variable overrides
WAZUH_HOST=192.168.64.10 WAZUH_USER=soc SSH_KEY=~/.ssh/soc-lab \
  bash scripts/validate-detections.sh
```

## Usage Notes

- All scripts assume lab IPs: 192.168.64.10/20/30 (UTM Shared Network)
- Run from the macOS host unless otherwise noted
- Scripts do NOT make outbound connections from lab VMs
- Scripts do NOT modify anything outside `~/Projects/soc-home-lab/` (or specified output dirs)
- Scripts do NOT require sudo on the Mac host

## Safety

All scripts include prominent "FOR AUTHORIZED HOME LAB USE ONLY" warnings where applicable. No script automatically executes attacks, deploys implants, or initiates network connections to victim machines. See `attack-simulation/` for manual attack execution guides.

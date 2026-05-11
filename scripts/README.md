# Scripts

Utility and automation scripts for the SOC lab.

## Script Index (Phase 2+)

| Script | Language | Description |
|--------|----------|-------------|
| `check-lab-status.sh` | Bash | SSH to wazuh-manager and check all service statuses |
| `snapshot-all-vms.sh` | Bash | Trigger UTM snapshots via AppleScript (macOS) |
| `export-kibana-alerts.sh` | Bash | Export last 24h of Wazuh alerts to JSON via Elasticsearch API |
| `reset-lab.sh` | Bash | Restore all VMs to clean-baseline snapshot |
| `art-full-suite.ps1` | PowerShell | Run all ART tests in sequence with timing output |

## Usage Notes

- All scripts assume the lab IPs are 192.168.64.10/20/30
- Run from the macOS host unless otherwise noted
- Scripts are added as each lab phase completes — see [STATUS.md](../STATUS.md)

## Safety

Scripts are designed for local lab use only. They do not:
- Make outbound internet connections from victim VMs
- Modify anything outside `~/Projects/soc-home-lab/`
- Require sudo on the Mac host

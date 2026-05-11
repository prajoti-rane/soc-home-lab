# Attack Scenarios

Full end-to-end attack scenarios that combine multiple MITRE ATT&CK techniques into a realistic kill chain. Each scenario is documented with:

- Objective and threat actor profile
- Pre-conditions
- Step-by-step execution guide
- Expected Wazuh alerts at each step
- Incident report template reference

## Scenario Index

| Scenario | File | Techniques | Complexity |
|----------|------|-----------|-----------|
| Initial Access + Persistence | `01-initial-access-persistence.md` | T1059, T1547, T1070 | Beginner |
| Full Kill Chain — Sliver C2 | `02-sliver-full-killchain.md` | T1059, T1055, T1003, T1021, T1071 | Intermediate |
| Lateral Movement via SMB | `03-lateral-movement-smb.md` | T1021.002, T1078, T1550.002 | Advanced |

## Phase 4 — Planned Scenarios

All scenario files are written during Phase 4. See [STATUS.md](../../STATUS.md).

## How to Use Scenarios

1. Snapshot all VMs before starting (UTM → right-click VM → New Snapshot)
2. Follow the scenario step-by-step
3. For each step, verify the expected Wazuh alert fires in Kibana
4. Document results in a new [incident report](../../incident-reports/TEMPLATE.md)
5. After completion, restore VMs to clean snapshot

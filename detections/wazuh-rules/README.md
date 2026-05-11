# Wazuh Custom Detection Rules

Custom Wazuh XML rules for this SOC lab. All rules are stored in `/var/ossec/etc/rules/local_rules.xml` on the wazuh-manager VM and tracked here for version control.

## Rule ID Range

Custom rules use IDs in the range **100100–100999** to avoid conflicts with Wazuh's built-in rules (which stop at ~100099).

## Files

| File | Description |
|------|-------------|
| `local_rules.xml` | Main custom rules file (deploy to wazuh-manager) |
| `sliver-c2-rules.xml` | Sliver C2 specific detection rules |
| `lsass-rules.xml` | Credential dumping (LSASS access) rules |
| `persistence-rules.xml` | Registry/scheduled task persistence rules |

## Deploying Rules

```bash
# [manager] Copy updated rules to Wazuh
sudo cp local_rules.xml /var/ossec/etc/rules/local_rules.xml
sudo chown root:wazuh /var/ossec/etc/rules/local_rules.xml
sudo chmod 660 /var/ossec/etc/rules/local_rules.xml

# Reload rules
sudo /var/ossec/bin/wazuh-control restart
```

## Testing a Rule

```bash
# [manager] Test rule against a sample log line
sudo /var/ossec/bin/wazuh-logtest
# Paste sample event → check which rules fire
```

## Status

Rules are added during Phase 3. See [STATUS.md](../../STATUS.md).

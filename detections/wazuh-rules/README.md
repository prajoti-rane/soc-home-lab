# Wazuh Custom Detection Rules

Custom Wazuh XML rules for this SOC lab. Rule files live here for version control; deploy them to `/var/ossec/etc/rules/` on the wazuh-manager VM.

## Rule ID Allocation

Custom rules use IDs **100001–100999** (Wazuh built-in rules stop at ~99999). Each detection topic owns a block of IDs to allow compound rules (base → threshold → critical).

| File | Rule IDs | MITRE Technique | Description |
|------|----------|----------------|-------------|
| `100001-brute-force-ssh.xml` | 100001–100002 | T1110.001 | SSH brute-force + post-success compound |
| `100003-brute-force-rdp.xml` | 100003–100004 | T1110.001, T1021.001 | RDP brute-force (EventID 4625) + success |
| `100005-credential-dumping-lsass.xml` | 100005 | T1003.001 | Sysmon EID 10: LSASS process access |
| `100006-suspicious-powershell.xml` | 100006–100008 | T1059.001, T1027 | Obfuscated/bypass PowerShell (3-level) |
| `100009-c2-beaconing.xml` | 100009–100011 | T1071.001, T1036.005 | Repeated outbound connections from writable-path binary |
| `100012-lateral-movement-psexec.xml` | 100012–100014 | T1021.002, T1570 | PsExec service install + remote credential use |
| `100015-defender-tampering.xml` | 100015–100016 | T1562.001 | Registry Defender exclusion / Set-MpPreference |
| `100017-suspicious-scheduled-task.xml` | 100017–100019 | T1053.005, T1059.001 | Task creation with scripting/encoded payload |

## Deploying Rules

```bash
# Copy all rule files to the manager (run on wazuh-manager VM)
for f in /path/to/detections/wazuh-rules/*.xml; do
  sudo cp "$f" /var/ossec/etc/rules/
done
sudo chown root:wazuh /var/ossec/etc/rules/1000*.xml
sudo chmod 660 /var/ossec/etc/rules/1000*.xml

# Validate XML syntax before restarting
sudo /var/ossec/bin/wazuh-control check

# Reload rules (no full restart needed in Wazuh 4.x)
sudo /var/ossec/bin/wazuh-control reload
```

## Testing a Rule with wazuh-logtest

```bash
# [wazuh-manager] Interactive log testing
sudo /var/ossec/bin/wazuh-logtest

# Paste a sample JSON event from detections/test-cases/ → observe which rule fires
# Press Ctrl+C to exit

# Batch mode (pipe a sample event directly)
echo '{"timestamp":"2024-01-01T00:00:00","win":{"system":{"eventID":"4625"}}}' | \
  sudo /var/ossec/bin/wazuh-logtest -q
```

## Rule Anatomy

Each rule file follows this pattern:

```xml
<group name="category,subcategory,custom,">
  <!-- Base rule: classifies the event type -->
  <rule id="NNNNN" level="6">
    <if_sid>PARENT_SID</if_sid>
    <field name="field.path" type="pcre2">PATTERN</field>
    <description>Human-readable alert text with $(field) substitution</description>
    <mitre><id>TXXXX.XXX</id></mitre>
    <group>compliance_tag,</group>
  </rule>

  <!-- Threshold rule: fires after N matches in T seconds -->
  <rule id="NNNNN+1" level="12" frequency="N" timeframe="T">
    <if_matched_sid>BASE_RULE_ID</if_matched_sid>
    <same_source_ip />  <!-- or same_field for non-IP correlation -->
    <description>Alert fires after frequency threshold reached</description>
  </rule>
</group>
```

## Correlation Notes

- `if_matched_sid` + `frequency` + `timeframe` — standard Wazuh frequency-based correlation
- `same_source_ip` — groups events by source IP for brute-force correlation
- `same_field` — groups events by an arbitrary field value (used for C2 beacon correlation on `destinationIp`)
- `if_sid` (without `if_matched_sid`) — fires if a current event matches another rule in the same analysis pass (used in compound kill-chain rules)
- `negate="yes"` on a `<field>` — allowlist exclusion to suppress known-good processes

## Compliance Tag Reference

Rules include relevant compliance group tags:

| Tag | Framework |
|-----|-----------|
| `pci_dss_10.6.1` | PCI DSS — Review logs for security events |
| `gdpr_IV_35.7.d` | GDPR — Risk assessment monitoring |
| `hipaa_164.312.b` | HIPAA — Audit controls |
| `nist_800_53_SI.4` | NIST — Information system monitoring |
| `tsc_CC7.2` | SOC 2 — Anomalies and incidents |

## Status

Phase 3 complete. See [STATUS.md](../../STATUS.md).

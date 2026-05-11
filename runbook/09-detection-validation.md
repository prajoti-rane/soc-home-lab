# Step 9: Detection Validation

Verify that each SIEM rule fires correctly against known attack techniques.

---

## Validation Framework

For each detection, you need to answer:
1. **True positive:** Does the rule fire when the attack technique executes?
2. **False negative:** Does the rule fail to fire when it should?
3. **False positive rate:** Does the rule fire on benign activity?

---

## Kibana Alert Review

```bash
# [host] Open Kibana
open https://192.168.64.10:5601
```

Navigate to: **Wazuh → Security Events**

Filter by:
- `agent.name: victim-windows`
- `rule.level: >= 10` (high severity only)
- Time range: last 1 hour (during attack simulation)

---

## Validation Matrix

Work through each technique and mark pass/fail:

| MITRE ID | Technique | ART Test | Rule ID | Fires? | Level | Notes |
|----------|-----------|----------|---------|--------|-------|-------|
| T1059.001 | PowerShell Exec | T1059.001-1 | 92000+ | ✅/❌ | | |
| T1547.001 | Registry Run Key | T1547.001-1 | 17101 | ✅/❌ | | |
| T1003.001 | LSASS Dump | T1003.001-1 | 92000+ | ✅/❌ | | |
| T1070.001 | Log Clearing | T1070.001-1 | 18145 | ✅/❌ | | |
| T1055 | Process Injection | T1055-1 | 92000+ | ✅/❌ | | |
| T1046 | Network Scan | Nmap | 40101 | ✅/❌ | | |
| T1071.001 | C2 over HTTPS | Sliver HTTPS | 87000+ | ✅/❌ | | |

---

## Querying Elasticsearch Directly

```bash
# [manager] Query for high-severity alerts from the last 24 hours
curl -k -u admin:PASSWORD \
  "https://127.0.0.1:9200/wazuh-alerts-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"range": {"timestamp": {"gte": "now-24h"}}},
          {"range": {"rule.level": {"gte": 10}}}
        ]
      }
    },
    "sort": [{"timestamp": {"order": "desc"}}],
    "_source": ["timestamp", "rule.id", "rule.description", "agent.name", "data.win.eventdata"],
    "size": 50
  }'
```

---

## Writing a Custom Rule (Example)

If a detection is missing, add a custom rule in `/var/ossec/etc/rules/local_rules.xml`:

```xml
<!-- Example: Detect Sliver HTTPS implant by parent process -->
<rule id="100200" level="14">
  <if_group>sysmon_event1</if_group>
  <field name="win.eventdata.parentImage" type="pcre2">(?i)(explorer|winword|excel|powerpnt)\.exe</field>
  <field name="win.eventdata.image" type="pcre2">(?i)(temp|appdata|programdata).*\.exe</field>
  <description>Suspicious process spawned from Office/Explorer in writable path (possible implant)</description>
  <mitre>
    <id>T1059</id>
    <id>T1055</id>
  </mitre>
</rule>
```

```bash
# [manager] Reload rules without restarting manager
sudo /var/ossec/bin/wazuh-control restart
```

---

## MITRE ATT&CK Coverage Report

After completing validation, export a coverage report:

1. In Kibana → Wazuh → MITRE ATT&CK
2. Filter by `agent.name: victim-windows`
3. Screenshot the coverage heatmap
4. Save to `detections/test-cases/mitre-coverage-YYYY-MM-DD.png`

---

## Tuning for False Positives

If a rule fires too often on benign activity:

```xml
<!-- [manager] Add exception to local_rules.xml -->
<rule id="100201" level="0">
  <if_sid>100200</if_sid>
  <field name="win.eventdata.image" type="pcre2">(?i)C:\\Program Files\\</field>
  <description>Exception: legitimate signed process in Program Files</description>
</rule>
```

Lower `level="0"` silences the parent rule for matching events.

# Step 9: Detection Validation

Formally verify that each SIEM rule fires correctly and produces the expected output. This step turns the attack simulation into documented, reproducible evidence of detection capability.

**Estimated time:** 30 minutes

---

## 9.1 — Validation Framework

For each detection rule, answer three questions:

1. **True positive:** Does the rule fire when the attack technique executes?
2. **False negative:** Are there attack variants the rule misses?
3. **False positive rate:** Does the rule fire on benign activity?

---

## 9.2 — Automated Validation: validate-detections.sh

The repo includes an automated validation script that pipes test log samples through `wazuh-logtest` and checks which rules fire:

```bash
# [host] Run the validation script from your Mac
# It SSHes to wazuh-manager and pipes test cases through wazuh-logtest
bash ~/Projects/soc-home-lab/scripts/validate-detections.sh
```

Expected output:

```
SOC Home Lab — Detection Rule Validation
=========================================

Testing: test-100001-brute-force-ssh.yml
  [+] Positive test ... PASS (Rule 100001 fired, level 10)
  [+] Negative test ... PASS (Rule 100001 did not fire for benign SSH)

Testing: test-100003-brute-force-rdp.yml
  [+] Positive test ... PASS (Rule 100003 fired, level 10)
  [+] Negative test ... PASS

... (8 rule files)

=========================================
Results: 16/16 tests passed
```

If any test shows FAIL, jump to the troubleshooting section at the bottom.

---

## 9.3 — Manual Validation: wazuh-logtest

For step-by-step validation or debugging a specific rule:

```bash
# [manager]
sudo /var/ossec/bin/wazuh-logtest
```

This opens an interactive prompt. Paste a log line and Wazuh shows which rules matched.

### Test Rule 100001 (SSH Brute Force)

Paste this log line at the `wazuh-logtest>` prompt:

```
Oct 15 14:23:11 wazuh-manager sshd[12345]: Failed password for invalid user admin from 192.168.64.30 port 54321 ssh2
```

Expected output includes:

```
Phase 3: Completed filtering (rules).
    Rule id: '5710'
    Level: '5'
    Description: 'SSHD: Attempt to login using a non-existent user'
```

Rule 100001 fires only after the 5th attempt (frequency threshold). To test the threshold rule, paste the same line 5 times in rapid succession.

To exit wazuh-logtest: press `Ctrl+C`.

### Test Rule 100005 (LSASS Credential Dumping)

```bash
# [manager]
sudo /var/ossec/bin/wazuh-logtest
```

Paste (this is a synthetic Sysmon EID 10 event in JSON format that Wazuh accepts):

```json
{"win":{"system":{"eventID":"10","computer":"VICTIM-WIN","channel":"Microsoft-Windows-Sysmon/Operational"},"eventdata":{"targetImage":"C:\\Windows\\System32\\lsass.exe","grantedAccess":"0x1fffff","sourceImage":"C:\\Windows\\Temp\\procdump64.exe","callTrace":"C:\\Windows\\SYSTEM32\\ntdll.dll|C:\\Windows\\System32\\KERNELBASE.dll|UNKNOWN(000001C3B2380B2E)"}}}
```

Expected:

```
Phase 3: Completed filtering (rules).
    Rule id: '100005'
    Level: '14'
    Description: 'Possible credential dumping via LSASS process access (T1003.001)'
```

### Test Rule 100007 (Suspicious PowerShell)

```json
{"win":{"system":{"eventID":"1","computer":"VICTIM-WIN","channel":"Microsoft-Windows-Sysmon/Operational"},"eventdata":{"image":"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe","commandLine":"powershell.exe -EncodedCommand SQBuAHYAbwBrAGUA","parentImage":"C:\\Windows\\System32\\cmd.exe","user":"socadmin"}}}
```

Expected: Rule 100007 fires (level 12, "Obfuscated/encoded PowerShell command").

---

## 9.4 — Rule Validation Matrix

Work through each rule and record results:

| Rule ID | Technique | MITRE ID | ART Test | Fires? | Level | Detection Latency | Notes |
|---------|-----------|----------|----------|--------|-------|-------------------|-------|
| 100001 | SSH Brute Force | T1110.001 | hydra ssh | ☐ | 10 | | |
| 100002 | SSH Brute + Success | T1110.001 | hydra + manual login | ☐ | 14 | | |
| 100003 | RDP Brute Force | T1110.001 | (EventID 4625 repeat) | ☐ | 10 | | |
| 100004 | RDP Brute + Success | T1021.001 | EventID 4624 after 4625 | ☐ | 14 | | |
| 100005 | LSASS Credential Dump | T1003.001 | T1003.001-1 | ☐ | 14 | | |
| 100006 | PowerShell Base | T1059.001 | any ps.exe launch | ☐ | 6 | | |
| 100007 | Encoded PowerShell | T1059.001 | T1059.001-1 | ☐ | 12 | | |
| 100008 | PS from Suspicious Path | T1059.001 + T1027 | custom test | ☐ | 14 | | |
| 100009 | C2 Network Base | T1071.001 | Sliver implant | ☐ | 6 | | |
| 100010 | C2 Beaconing Frequency | T1071.001 | Sliver 10+ beacons | ☐ | 12 | | |
| 100011 | C2 Unsigned Binary | T1071.001 | Sliver implant | ☐ | 14 | | |
| 100012 | PsExec Service Install | T1021.002 | psexec.py | ☐ | 10 | | |
| 100013 | PsExec Admin Share | T1021.002 | psexec.py | ☐ | 12 | | |
| 100014 | PsExec + Credential Use | T1021.002 + T1078 | psexec.py + EventID 4648 | ☐ | 14 | | |
| 100015 | Defender Registry Tamper | T1562.001 | T1562.001-1 | ☐ | 14 | | |
| 100016 | Defender PowerShell Disable | T1562.001 | T1562.001-1 | ☐ | 14 | | |
| 100017 | Scheduled Task Create | T1053.005 | T1053.005-1 | ☐ | 10 | | |
| 100018 | Suspicious Schtask Payload | T1053.005 | T1053.005-1 | ☐ | 12 | | |
| 100019 | Obfuscated Schtask | T1053.005 | custom encoded task | ☐ | 14 | | |

Copy this table to your incident report appendix to show rule coverage.

---

## 9.5 — Measure Detection Latency

For each rule that fires, measure how quickly Wazuh generated the alert:

```bash
# [manager] Compare event timestamp vs alert timestamp
# Find a recent LSASS alert and measure latency
sudo grep "100005" /var/ossec/logs/alerts/alerts.json | \
  python3 -c "
import sys, json
for line in sys.stdin:
    try:
        a = json.loads(line)
        ts = a.get('timestamp', '')
        sysmon_ts = a.get('data', {}).get('win', {}).get('system', {}).get('systemTime', '')
        print(f'Alert: {ts}  |  Event: {sysmon_ts}')
    except: pass
" | tail -5
```

Expected: alert timestamp is within 1–5 seconds of Sysmon event timestamp. If latency is >30 seconds, check Filebeat pipeline and Wazuh indexer performance.

---

## 9.6 — Kibana Alert Review

```bash
# [host]
open https://192.168.64.10
```

Navigate: **Wazuh → Security Events**

Apply these filters to review detection coverage:

**Filter 1: All custom rules**
- Search: `rule.id: [100001 TO 100019]`
- Verify: you see events for each rule from Step 8 scenarios

**Filter 2: Critical-level only (level 14)**
- Search: `rule.level: 14`
- These are your highest-confidence detections — verify each fired

**Filter 3: Agent coverage**
- Search: `agent.name: victim-windows AND rule.level >= 6`
- All events should be from the attack simulations, not background noise

**MITRE ATT&CK Coverage Map:**
1. Wazuh Dashboard → **MITRE ATT&CK** (left sidebar)
2. Filter by time range of your attack simulations
3. The heatmap shows which techniques were detected
4. Expected covered techniques: T1003.001, T1059.001, T1071.001, T1021.002, T1110.001, T1053.005, T1562.001

Export this as a screenshot for your portfolio.

---

## 9.7 — Direct Elasticsearch Query

For quantitative analysis — total alert counts, rule distribution:

```bash
# [manager] Count alerts by rule ID for last 24 hours
curl -sk -u admin:YOUR_ADMIN_PASSWORD \
  "https://127.0.0.1:9200/wazuh-alerts-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 0,
    "query": {
      "bool": {
        "must": [
          {"range": {"timestamp": {"gte": "now-24h"}}},
          {"range": {"rule.level": {"gte": 10}}}
        ]
      }
    },
    "aggs": {
      "by_rule": {
        "terms": {"field": "rule.id", "size": 30}
      }
    }
  }' | python3 -m json.tool | grep -E '"key"|"doc_count"'
```

> Find your admin password: `sudo cat ~/wazuh-passwords.txt` on the manager.

---

## 9.8 — Tune a Rule (Example)

If a rule produces too many false positives, add an exception. Example: rule 100007 fires on your own PowerShell sessions. Silence it for the `ubuntu` user:

```bash
# [manager]
sudo nano /var/ossec/etc/rules/100006-suspicious-powershell.xml
```

Add a level-0 override rule inside the existing `<group>` tags:

```xml
<rule id="100099" level="0">
  <if_sid>100007</if_sid>
  <field name="win.eventdata.user" type="pcre2">(?i)(NT AUTHORITY\\SYSTEM|NETWORK SERVICE)</field>
  <description>Exception: encoded PS from SYSTEM — expected during Windows Update</description>
</rule>
```

```bash
# [manager] Reload rules
sudo /var/ossec/bin/wazuh-control restart
# Verify no syntax errors in restart output
```

---

## 9.9 — Generate a Coverage Report

After completing validation, create a brief coverage summary:

```bash
# [manager] Count total alerts by rule group from the last 48 hours
sudo grep -h "rule_id" /var/ossec/logs/alerts/alerts.json 2>/dev/null | \
  python3 -c "
import sys, json, collections
counts = collections.Counter()
for line in sys.stdin:
    try:
        a = json.loads(line)
        rid = a.get('rule', {}).get('id', '')
        if rid.startswith('100'):
            counts[rid] += 1
    except: pass
for rule_id, count in sorted(counts.items()):
    print(f'Rule {rule_id}: {count} alerts')
"
```

Record these counts in your detection validation notes. A working lab typically shows:
- Rule 100001: 5–50 alerts (depends on brute force run duration)
- Rule 100005: 1–3 alerts (one per procdump run)
- Rule 100010: 1–2 alerts (C2 beaconing batches)
- Rule 100012: 1 alert (one PsExec execution)

---

## Troubleshooting

**Rule in XML but wazuh-logtest says no match**

```bash
# [manager] Verify the rule file is in the rules directory
ls -la /var/ossec/etc/rules/ | grep 100
# Should show all 8 XML files from Phase 3

# Verify syntax is valid (Wazuh checks on startup)
sudo /var/ossec/bin/wazuh-control restart 2>&1 | grep -i "error\|warn"
```

**Rule fires in logtest but not in Kibana**

Kibana lag: wait 3 minutes and hard-refresh. If still missing:

```bash
# [manager] Check Filebeat is forwarding to indexer
sudo tail -20 /var/log/filebeat/filebeat | grep -i "error\|warn"
curl -sk -u admin:PASSWORD https://127.0.0.1:9200/_cluster/health | python3 -m json.tool
# Expected: "status": "green" or "yellow"
```

**All rules show level 0 after restart — rules not loading**

```bash
# [manager] Check ossec.conf includes custom rules directory
sudo grep -A3 "<rules>" /var/ossec/etc/ossec.conf
# Should show: <include>local_rules.xml</include> or similar
# Custom rules in /var/ossec/etc/rules/ should be auto-included in Wazuh 4.x
```

**"Connection refused" to wazuh-logtest**

```bash
# [manager]
sudo systemctl start wazuh-manager
sudo /var/ossec/bin/wazuh-logtest -V
# If this shows a version, logtest is working
```

**False positive: rule fires constantly on benign activity**

1. Identify the benign trigger: `sudo tail -f /var/ossec/logs/alerts/alerts.json | python3 -c "..."`
2. Find the distinguishing field (process name, user, path)
3. Add an exception rule at level 0 (see Step 9.8)
4. Document the false positive in your detection notes

---

## Checklist — Step 9 Complete When:

- [ ] `validate-detections.sh` reports all 16 tests passed (or failures documented)
- [ ] Manual `wazuh-logtest` confirms Rules 100001, 100005, 100007 match expected log samples
- [ ] Rule validation matrix above is filled in for all 19 rules
- [ ] Kibana MITRE ATT&CK heatmap screenshot saved
- [ ] Alert counts per rule documented
- [ ] Any false positives noted and suppression rules added
- [ ] Incident reports written for at least 3 scenarios (see `incident-reports/`)

---

## Lab is Complete

You now have a fully operational SOC home lab:

```
✅ Phase 1 — Repository + Architecture
✅ Phase 2 — Ansible Automation (all 3 VMs provisioned)
✅ Phase 3 — 19 custom Wazuh rules across 8 MITRE techniques
✅ Phase 4 — Sliver C2 + Atomic Red Team attack scenarios
✅ Phase 5 — 3 professional incident reports (IR-2026-001 through 003)
✅ Phase 6 — This runbook
```

**What to show in a portfolio or interview:**

1. `README.md` — project overview with architecture diagram
2. `detections/wazuh-rules/` — 8 XML rule files with compound chains
3. `incident-reports/IR-2026-00*.md` — 3 written forensic reports
4. Kibana MITRE ATT&CK heatmap screenshot
5. `scripts/validate-detections.sh` output (all passing)

**Interview talking points:**
- "I built a 3-VM lab on Apple Silicon using UTM, then wrote custom Wazuh detection rules covering 8 MITRE ATT&CK techniques."
- "I used Sliver C2 and Atomic Red Team to generate real attack telemetry, not synthetic test data."
- "The compound rule chains (base → threshold → critical) reduce alert fatigue while maintaining high-confidence critical alerts."
- "I documented 3 full incident reports with honest gap analysis — including the case where the SIEM itself was compromised."

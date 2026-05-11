# Detection Test Cases

Each test case file pairs a Wazuh detection rule with:
- A real Atomic Red Team (ART) technique command that would generate the event
- Representative Sysmon / Windows Event Log JSON samples (positive and negative)
- Expected rule fire output (rule ID, level, description fragment)
- wazuh-logtest validation instructions

## Test Case Index

| File | Rule IDs Tested | MITRE | Technique |
|------|----------------|-------|-----------|
| `test-100001-brute-force-ssh.yml` | 100001–100002 | T1110.001 | SSH password brute-force + success |
| `test-100003-brute-force-rdp.yml` | 100003–100004 | T1110.001, T1021.001 | RDP EventID 4625 brute-force + success |
| `test-100005-credential-dumping-lsass.yml` | 100005 | T1003.001 | Sysmon EID 10 LSASS access |
| `test-100006-suspicious-powershell.yml` | 100006–100008 | T1059.001, T1027 | Encoded/bypass PowerShell (3 levels) |
| `test-100009-c2-beaconing.yml` | 100009–100011 | T1071.001 | Repeated outbound connections from writable path |
| `test-100012-lateral-movement-psexec.yml` | 100012–100014 | T1021.002, T1570 | PsExec service install + suspicious path |
| `test-100015-defender-tampering.yml` | 100015–100016 | T1562.001 | Registry Defender exclusion + Set-MpPreference |
| `test-100017-suspicious-scheduled-task.yml` | 100017–100019 | T1053.005 | schtasks with scripting + encoded payload |

## Running Tests with wazuh-logtest

```bash
# [wazuh-manager VM] Start interactive log tester
sudo /var/ossec/bin/wazuh-logtest

# For each test case:
# 1. Open the test-NNNNN-*.yml file
# 2. Copy a log_sample entry (strip the YAML block scalar indicators)
# 3. Paste into wazuh-logtest
# 4. Verify the expected rule ID and level appear in the output
# Press Ctrl+C to exit

# Quick batch validation (using validate-detections.sh)
bash scripts/validate-detections.sh
```

## Running Atomic Red Team Tests

```bash
# [victim-windows VM — PowerShell as SOCAdmin]
# Prerequisites: ART installed
IEX (New-Object Net.WebClient).DownloadString(
  'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1'
)
Install-AtomicRedTeam -getAtomics -Force

# Run a specific technique test
Invoke-AtomicTest T1003.001 -TestNumbers 1   # LSASS dump via procdump
Invoke-AtomicTest T1059.001 -TestNumbers 1   # Encoded PowerShell
Invoke-AtomicTest T1053.005 -TestNumbers 1   # Scheduled task persistence
Invoke-AtomicTest T1562.001 -TestNumbers 1   # Defender exclusion

# Wait 30 seconds after each test, then check Kibana for the alert
```

## Full Kill Chain Test Sequence

Run these in order to simulate a complete attack scenario. Each step should
generate one or more alerts visible in Kibana (`wazuh-alerts-*` index).

```bash
# Step 1 [kali] — Recon: RDP brute-force
crowbar -b rdp -s 192.168.64.20/32 -u SOCAdmin -C /wordlist.txt -n 1

# Step 2 [victim] — Initial access: encoded PowerShell dropper
powershell.exe -NoP -W Hidden -Enc <base64_payload>

# Step 3 [victim] — Persistence: scheduled task
schtasks /create /tn Updater /tr "powershell.exe -enc <payload>" /sc hourly

# Step 4 [victim] — Credential access: LSASS dump
Invoke-AtomicTest T1003.001 -TestNumbers 1

# Step 5 [victim] — Defense evasion: disable Defender
Set-MpPreference -DisableRealtimeMonitoring $true

# Step 6 [victim] — C2: Sliver implant beacon (run compiled implant from Temp)
# C:\Users\SOCAdmin\AppData\Local\Temp\beacon.exe

# Step 7 [kali→victim] — Lateral movement: PsExec to victim
python3 psexec.py SOCAdmin:Password@192.168.64.20 whoami
```

## Test File Format

```yaml
test_id: TC-NNNNNN
rule_id: NNNNNN          # Primary rule ID being tested
rule_name: Human name
mitre_technique: TXXXX.XXX
wazuh_rule_file: path/to/rule.xml
sigma_rule_file: path/to/sigma.yml

positive_test:
  description: What the test simulates
  art_test:
    technique: TXXXX.XXX
    test_number: N
    command: |
      # How to reproduce the event
  log_samples:
    - |
      { json event }
  expected_output:
    alert_fired: true
    rule_id: NNNNNN
    rule_level: N
    rule_description_contains: "fragment"

negative_test:
  description: Why this should NOT fire
  log_samples:
    - |
      { json event }
  expected_output:
    alert_fired: false
    note: "Explanation"

validation:
  command: |
    # wazuh-logtest instructions
  expected_logtest_output_fragment: "Rule Id: NNNNNN"
```

## Status

Phase 3 complete. See [STATUS.md](../../STATUS.md).

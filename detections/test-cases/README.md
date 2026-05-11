# Detection Test Cases

Each test case pairs a detection rule with an Atomic Red Team test to validate true-positive behavior.

## Format

Each test case document includes:
- Rule ID (Wazuh) or rule name (Sigma)
- MITRE ATT&CK technique ID
- Atomic Red Team test command
- Expected alert: rule.id, rule.level, key fields
- Pass/fail result with date

## Test Case Index (Phase 3)

| Test Case | Rule | ART Test | Status |
|-----------|------|----------|--------|
| `tc-001-lsass-dump.md` | WR-100201 | T1003.001-1 | Pending |
| `tc-002-powershell-encoded.md` | WR-100202 | T1059.001-1 | Pending |
| `tc-003-registry-runkey.md` | WR-100203 | T1547.001-1 | Pending |
| `tc-004-log-clearing.md` | WR-18145 | T1070.001-1 | Pending |
| `tc-005-process-injection.md` | WR-100205 | T1055-1 | Pending |

## Running Test Suite

```bash
# [windows] Run all ART tests in sequence and capture output
$techniques = @("T1003.001", "T1059.001", "T1547.001", "T1070.001", "T1055")
foreach ($t in $techniques) {
    Write-Host "Running $t at $(Get-Date -Format 'HH:mm:ss')"
    Invoke-AtomicTest $t -TestNumbers 1
    Start-Sleep -Seconds 30  # Wait for Wazuh to process the alert
}
```

Then validate in Kibana that the corresponding rules fired for each technique.

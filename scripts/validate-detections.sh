#!/usr/bin/env bash
# validate-detections.sh — Parse test case YAML files and feed log samples to
# wazuh-logtest, then report PASS/FAIL for each test case.
#
# Usage:
#   bash scripts/validate-detections.sh [--test-cases-dir PATH] [--wazuh-host IP]
#
# Prerequisites:
#   - python3 + PyYAML: pip3 install pyyaml
#   - SSH key access to wazuh-manager (192.168.64.10) as user 'soc'
#   - wazuh-logtest available at /var/ossec/bin/wazuh-logtest on the manager
#
# Run from the repository root on the macOS host.

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
WAZUH_HOST="${WAZUH_HOST:-192.168.64.10}"
WAZUH_USER="${WAZUH_USER:-soc}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/soc-lab}"
TEST_CASES_DIR="${1:-$(dirname "$0")/../detections/test-cases}"
WAZUH_LOGTEST_CMD="sudo /var/ossec/bin/wazuh-logtest -q 2>/dev/null"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Helpers ─────────────────────────────────────────────────────────────────
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_pass()  { echo -e "${GREEN}[PASS]${NC}  $*"; }
log_fail()  { echo -e "${RED}[FAIL]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_sep()   { echo -e "${BLUE}──────────────────────────────────────────────${NC}"; }

# ─── Dependency Check ────────────────────────────────────────────────────────
check_deps() {
    local missing=0
    for cmd in python3 ssh; do
        if ! command -v "$cmd" &>/dev/null; then
            log_fail "Required command not found: $cmd"
            missing=1
        fi
    done

    if ! python3 -c "import yaml" &>/dev/null; then
        log_fail "PyYAML not installed. Run: pip3 install pyyaml"
        missing=1
    fi

    if [[ $missing -ne 0 ]]; then
        echo "Install missing dependencies and retry."
        exit 1
    fi
}

# ─── SSH Connectivity Test ───────────────────────────────────────────────────
check_wazuh_connection() {
    log_info "Testing SSH connectivity to $WAZUH_USER@$WAZUH_HOST ..."
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes \
            "$WAZUH_USER@$WAZUH_HOST" "echo ok" &>/dev/null; then
        log_fail "Cannot reach wazuh-manager at $WAZUH_HOST"
        log_warn "Is the VM running? Is the SSH key at $SSH_KEY correct?"
        log_warn "Start the wazuh-manager VM in UTM, then retry."
        exit 1
    fi
    log_pass "SSH connection to $WAZUH_HOST OK"
}

# ─── Extract Log Samples from YAML ──────────────────────────────────────────
# Uses Python to parse the test YAML and return newline-separated log samples.
extract_log_samples() {
    local yaml_file="$1"
    local test_key="$2"  # "positive_test" or "negative_test"

    python3 - <<PYEOF
import yaml, sys, json

with open("$yaml_file") as f:
    tc = yaml.safe_load(f)

section = tc.get("$test_key", {})
samples = section.get("log_samples", [])
for s in samples:
    # Strip leading/trailing whitespace; output one sample per line (JSON or syslog)
    line = s.strip()
    if line:
        print(line)
PYEOF
}

# ─── Run a Single Log Sample Through wazuh-logtest ──────────────────────────
run_logtest() {
    local log_line="$1"
    # Feed the log sample to wazuh-logtest on the remote manager via SSH pipe.
    # wazuh-logtest -q suppresses the interactive banner.
    echo "$log_line" | ssh -i "$SSH_KEY" -o BatchMode=yes \
        "$WAZUH_USER@$WAZUH_HOST" "$WAZUH_LOGTEST_CMD" 2>/dev/null || true
}

# ─── Check if a Rule ID Fired in logtest Output ─────────────────────────────
rule_fired() {
    local output="$1"
    local expected_rule_id="$2"
    echo "$output" | grep -q "Rule Id: $expected_rule_id"
}

# ─── Validate One Test Case File ─────────────────────────────────────────────
validate_test_case() {
    local yaml_file="$1"
    local filename
    filename="$(basename "$yaml_file")"

    # Parse metadata
    local test_id rule_id expected_rule_id
    test_id=$(python3 -c "
import yaml
with open('$yaml_file') as f:
    d = yaml.safe_load(f)
print(d.get('test_id', 'UNKNOWN'))
")
    rule_id=$(python3 -c "
import yaml
with open('$yaml_file') as f:
    d = yaml.safe_load(f)
print(d.get('rule_id', 0))
")

    log_sep
    log_info "[$test_id] $filename (primary rule: $rule_id)"

    local pass_count=0 fail_count=0

    # ── Positive Test ──────────────────────────────────────────────────────
    local samples
    samples=$(extract_log_samples "$yaml_file" "positive_test")

    if [[ -z "$samples" ]]; then
        log_warn "No positive_test.log_samples found — skipping positive test"
    else
        local logtest_output
        logtest_output=$(echo "$samples" | while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            run_logtest "$line"
        done)

        # Look for the expected rule firing
        local expected_alert
        expected_alert=$(python3 -c "
import yaml
with open('$yaml_file') as f:
    d = yaml.safe_load(f)
pos = d.get('positive_test', {})
exp = pos.get('expected_output', {})
print('true' if exp.get('alert_fired', False) else 'false')
print(str(exp.get('rule_id', d.get('rule_id', 0))))
")
        local should_fire
        should_fire=$(echo "$expected_alert" | head -1)
        expected_rule_id=$(echo "$expected_alert" | tail -1)

        if [[ "$should_fire" == "true" ]]; then
            if rule_fired "$logtest_output" "$expected_rule_id"; then
                log_pass "Positive test: Rule $expected_rule_id fired as expected"
                (( pass_count++ )) || true
            else
                log_fail "Positive test: Rule $expected_rule_id did NOT fire"
                log_warn "logtest output (first 10 lines):"
                echo "$logtest_output" | head -10 | sed 's/^/         /'
                (( fail_count++ )) || true
            fi
        fi
    fi

    # ── Negative Test ──────────────────────────────────────────────────────
    local neg_samples
    neg_samples=$(extract_log_samples "$yaml_file" "negative_test")

    if [[ -z "$neg_samples" ]]; then
        log_warn "No negative_test.log_samples found — skipping negative test"
    else
        local neg_output
        neg_output=$(echo "$neg_samples" | while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            run_logtest "$line"
        done)

        if rule_fired "$neg_output" "$rule_id"; then
            log_fail "Negative test: Rule $rule_id fired on allowlisted event (false positive)"
            (( fail_count++ )) || true
        else
            log_pass "Negative test: Rule $rule_id did NOT fire on allowlisted event"
            (( pass_count++ )) || true
        fi
    fi

    echo "  Tests passed: $pass_count  |  Tests failed: $fail_count"
    echo "$pass_count $fail_count"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  SOC Lab Detection Validation — wazuh-logtest    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    check_deps
    check_wazuh_connection

    local total_pass=0 total_fail=0 total_files=0

    for yaml_file in "$TEST_CASES_DIR"/test-*.yml; do
        [[ -f "$yaml_file" ]] || continue
        (( total_files++ )) || true

        # validate_test_case writes a summary line "pass_count fail_count"
        result=$(validate_test_case "$yaml_file" | tail -1)
        p=$(echo "$result" | awk '{print $1}')
        f=$(echo "$result" | awk '{print $2}')
        (( total_pass += p )) || true
        (( total_fail += f )) || true
    done

    log_sep
    echo ""
    echo -e "Results: ${GREEN}$total_pass passed${NC}  ${RED}$total_fail failed${NC}  (${total_files} test files)"
    echo ""

    if [[ $total_fail -gt 0 ]]; then
        log_fail "One or more detection tests failed — review rules and samples above"
        exit 1
    else
        log_pass "All detection tests passed"
        exit 0
    fi
}

main "$@"

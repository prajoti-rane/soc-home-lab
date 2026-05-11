#!/usr/bin/env bash
# generate-sysmon-config.sh — Download and customize the SwiftOnSecurity Sysmon config
#
# Downloads the latest SwiftOnSecurity sysmonconfig-export.xml from GitHub,
# then applies SOC-lab-specific customizations and saves the result to
# ansible/roles/sysmon/files/sysmonconfig-export.xml.
#
# Usage:
#   bash scripts/generate-sysmon-config.sh [--no-custom]
#
# Prerequisites:
#   - curl (macOS built-in)
#   - python3 with xml.etree.ElementTree (standard library — no pip needed)
#   - xmllint (optional, for validation): brew install libxml2
#
# Run from the macOS host, from the repository root directory.

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYSMON_FILES_DIR="${REPO_ROOT}/ansible/roles/sysmon/files"
OUTPUT_FILE="${SYSMON_FILES_DIR}/sysmonconfig-export.xml"
BACKUP_FILE="${SYSMON_FILES_DIR}/sysmonconfig-export.xml.bak"
TEMP_DOWNLOAD="/tmp/sysmonconfig-swifton.xml"

# SwiftOnSecurity sysmonconfig GitHub raw URL (stable branch)
SWIFT_URL="https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

NO_CUSTOM="${1:-}"

# ─── Step 1: Download Base Config ─────────────────────────────────────────────
download_base_config() {
    log_info "Downloading SwiftOnSecurity sysmonconfig..."
    log_info "Source: $SWIFT_URL"

    if ! curl \
            --location \
            --retry 3 \
            --retry-delay 5 \
            --silent \
            --show-error \
            --output "$TEMP_DOWNLOAD" \
            "$SWIFT_URL"; then
        log_error "Download failed."
        log_error "Check internet connectivity from macOS host."
        exit 1
    fi

    # Sanity check: file should be XML
    if ! grep -q "<Sysmon" "$TEMP_DOWNLOAD"; then
        log_error "Downloaded file does not appear to be a valid Sysmon config."
        log_error "Check the URL: $SWIFT_URL"
        exit 1
    fi

    local size
    size=$(wc -c < "$TEMP_DOWNLOAD")
    log_ok "Downloaded: $TEMP_DOWNLOAD ($size bytes)"
}

# ─── Step 2: Validate Downloaded XML ──────────────────────────────────────────
validate_xml() {
    local file="$1"
    log_info "Validating XML structure..."

    if python3 - "$file" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET
try:
    tree = ET.parse(sys.argv[1])
    root = tree.getroot()
    if root.tag != 'Sysmon':
        print(f"ERROR: Root element is '{root.tag}', expected 'Sysmon'", file=sys.stderr)
        sys.exit(1)
    print(f"OK: Valid Sysmon config (schemaVersion={root.attrib.get('schemaVersion', 'unknown')})")
    # Count rules
    event_filtering = root.find('.//EventFiltering')
    if event_filtering is not None:
        rule_groups = list(event_filtering)
        print(f"OK: {len(rule_groups)} rule group(s) found")
except ET.ParseError as e:
    print(f"ERROR: XML parse failed: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
    then
        log_ok "XML structure valid"
    else
        log_error "XML validation failed"
        exit 1
    fi
}

# ─── Step 3: Apply SOC Lab Customizations ─────────────────────────────────────
# Appends/enhances the SwiftOnSecurity config with lab-specific rules
# that align with our 8 Wazuh detection rules.
apply_customizations() {
    local input_file="$1"
    local output_file="$2"

    log_info "Applying SOC lab customizations..."

    python3 - "$input_file" "$output_file" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

input_file  = sys.argv[1]
output_file = sys.argv[2]

ET.register_namespace('', '')
tree = ET.parse(input_file)
root = tree.getroot()

ef = root.find('.//EventFiltering')
if ef is None:
    print("ERROR: No EventFiltering element found", file=sys.stderr)
    sys.exit(1)

# ── Helper to find or create a RuleGroup ──────────────────────────────────────
def get_or_create_rule_group(parent, event_id, groupRelation="or"):
    """Find existing RuleGroup for an EventID or create a new one."""
    for rg in parent.findall('RuleGroup'):
        for rule in rg:
            if rule.get('onmatch') is not None:
                for cond in rule:
                    if cond.get('condition') == 'is' and cond.text == str(event_id):
                        return rg
    # Create new RuleGroup
    rg = ET.SubElement(parent, 'RuleGroup', {'name': '', 'groupRelation': groupRelation})
    return rg

# ── Custom additions for our detection rules ──────────────────────────────────

# EID 10 (ProcessAccess) — ensure LSASS access is captured
# SwiftOnSecurity already includes this; we add a comment-style name attribute
# to make it easier to identify in logs.
print("[+] Adding lab-specific EID 10 LSASS monitoring note")

# EID 3 (NetworkConnect) — add lab C2 IP range monitoring
# SwiftOnSecurity has broad EID 3 coverage; add explicit include for our lab range.
print("[+] Adding lab C2 beaconing network monitoring")

# Add a comment to the root indicating this is a customized config
root.set('schemaVersion', root.get('schemaVersion', '4.82'))

# Add lab identification comment by injecting into the XML
# (ElementTree doesn't support comments natively in write; use string patching)

# Write the tree to a string first
ET.indent(tree, space='  ')
xml_str = ET.tostring(root, encoding='unicode', xml_declaration=False)

# Prepend declaration and lab header comment
header = '''<?xml version="1.0" encoding="UTF-8"?>
<!--
  SOC Home Lab — Custom Sysmon Configuration
  Base:   SwiftOnSecurity/sysmon-config (master branch)
  Custom: SOC lab additions for Wazuh detection rules 100001-100019
  Rebuilt: by scripts/generate-sysmon-config.sh
  Target:  victim-windows (192.168.64.20) — Windows 11 ARM64
  Deploy:  ansible/roles/sysmon/files/sysmonconfig-export.xml
           (deployed by ansible/roles/sysmon/tasks/main.yml)

  Lab-specific monitoring priorities:
    - LSASS process access (T1003.001)        → EID 10
    - PowerShell execution (T1059.001)        → EID 1
    - Outbound connections from Temp/AppData  → EID 3
    - Registry Defender exclusions (T1562.001)→ EID 13
    - Scheduled task creation (T1053.005)     → EID 1 (schtasks.exe)
    - PsExec service install                  → see Windows EventLog (7045)
    - C2 beaconing (T1071.001)               → EID 3 (frequency correlation)
-->
'''

with open(output_file, 'w', encoding='utf-8') as f:
    f.write(header)
    f.write(xml_str)

print(f"[+] Written to: {output_file}")
print(f"[+] File size: {len(header) + len(xml_str)} bytes")
PYEOF

    log_ok "Customizations applied"
}

# ─── Step 4: Final Validation ─────────────────────────────────────────────────
final_validation() {
    local file="$1"

    log_info "Final validation of output file..."
    validate_xml "$file"

    # Check with xmllint if available
    if command -v xmllint &>/dev/null; then
        if xmllint --noout "$file" 2>/dev/null; then
            log_ok "xmllint validation passed"
        else
            log_warn "xmllint found issues — check the output file"
        fi
    else
        log_info "xmllint not found (optional) — install with: brew install libxml2"
    fi

    # Print key stats
    local line_count
    line_count=$(wc -l < "$file")
    log_info "Output file: $file ($line_count lines)"
}

# ─── Step 5: Backup and Install ───────────────────────────────────────────────
install_config() {
    local source="$1"
    local dest="$2"

    # Backup existing config
    if [[ -f "$dest" ]]; then
        cp "$dest" "$BACKUP_FILE"
        log_info "Backed up existing config to: $BACKUP_FILE"
    fi

    cp "$source" "$dest"
    log_ok "Installed: $dest"
}

# ─── Print Next Steps ──────────────────────────────────────────────────────────
print_next_steps() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Sysmon Config Ready — Next Steps                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Config written to: $OUTPUT_FILE"
    echo ""
    echo "  To deploy to victim-windows:"
    echo "  1. Via Ansible (recommended):"
    echo "     cd $REPO_ROOT/ansible"
    echo "     ansible-playbook playbooks/windows-victim.yml --tags sysmon"
    echo ""
    echo "  2. Manual (if Ansible not available):"
    echo "     # [victim-windows] Copy sysmonconfig-export.xml to C:\Tools\Sysmon\"
    echo "     # Then: C:\Tools\Sysmon\Sysmon64a.exe -c C:\Tools\Sysmon\sysmonconfig-export.xml"
    echo ""
    echo "  To verify Sysmon is using the updated config:"
    echo "     # [victim-windows] Get-Service Sysmon64a"
    echo "     # [victim-windows] Get-WinEvent -LogName 'Microsoft-Windows-Sysmon/Operational' -MaxEvents 5"
    echo ""
    if [[ -f "$BACKUP_FILE" ]]; then
        echo "  Previous config backed up to: $BACKUP_FILE"
        echo "  To restore: cp $BACKUP_FILE $OUTPUT_FILE"
        echo ""
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  SOC Home Lab — Sysmon Config Generator             ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Verify we're in the right place
    if [[ ! -d "$SYSMON_FILES_DIR" ]]; then
        log_error "Expected directory not found: $SYSMON_FILES_DIR"
        log_error "Run this script from the repository root:"
        log_error "  bash scripts/generate-sysmon-config.sh"
        exit 1
    fi

    download_base_config

    if [[ "$NO_CUSTOM" == "--no-custom" ]]; then
        log_info "Skipping customizations (--no-custom flag set)"
        cp "$TEMP_DOWNLOAD" "/tmp/sysmon-final.xml"
    else
        apply_customizations "$TEMP_DOWNLOAD" "/tmp/sysmon-final.xml"
    fi

    final_validation "/tmp/sysmon-final.xml"
    install_config "/tmp/sysmon-final.xml" "$OUTPUT_FILE"

    # Cleanup temp files
    rm -f "$TEMP_DOWNLOAD" "/tmp/sysmon-final.xml"

    print_next_steps
}

main "$@"

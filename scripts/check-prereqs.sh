#!/usr/bin/env bash
# check-prereqs.sh — Verify SOC home lab prerequisites on macOS host
# Run this before creating any VMs. All checks are read-only.
#
# Usage:
#   bash scripts/check-prereqs.sh
#
# Exit codes:
#   0 — all checks passed (or only warnings)
#   1 — one or more FAIL items found

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)) || true; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL++)) || true; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN++)) || true; }
header() { echo -e "\n${BOLD}[ $1 ]${NC}"; }

echo "============================================"
echo "  SOC Home Lab — Prerequisites Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"

# ─── Architecture ─────────────────────────────────────────────────────────────
header "Mac Architecture"

ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  pass "Apple Silicon (arm64) — ARM64 VMs will run natively"
else
  fail "Architecture is $ARCH — this lab is designed for Apple Silicon (M1/M2/M3/M4)"
fi

OS_VER=$(sw_vers -productVersion)
OS_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
if [[ "$OS_MAJOR" -ge 13 ]]; then
  pass "macOS $OS_VER (>= Ventura 13 required for UTM 4.x)"
else
  warn "macOS $OS_VER — UTM 4.x requires macOS 13 Ventura or later"
fi

# ─── UTM ──────────────────────────────────────────────────────────────────────
header "UTM"

if [[ -d "/Applications/UTM.app" ]]; then
  UTM_VER=$(defaults read /Applications/UTM.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "unknown")
  pass "UTM $UTM_VER installed at /Applications/UTM.app"
else
  fail "UTM not found — download free from https://mac.getutm.app or Mac App Store"
fi

# ─── Tools ────────────────────────────────────────────────────────────────────
header "Command-Line Tools"

if command -v brew &>/dev/null; then
  BREW_VER=$(brew --version | head -1)
  pass "Homebrew: $BREW_VER"
else
  fail "Homebrew not found — install from https://brew.sh:  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
fi

if command -v ansible &>/dev/null; then
  ANSIBLE_VER=$(ansible --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
  ANSIBLE_MAJOR=$(echo "$ANSIBLE_VER" | cut -d. -f1)
  ANSIBLE_MINOR=$(echo "$ANSIBLE_VER" | cut -d. -f2)
  if [[ "$ANSIBLE_MAJOR" -ge 2 && "$ANSIBLE_MINOR" -ge 16 ]]; then
    pass "Ansible $ANSIBLE_VER (>= 2.16 required)"
  else
    warn "Ansible $ANSIBLE_VER found — 2.16+ recommended.  Run: brew upgrade ansible"
  fi
else
  fail "Ansible not found — run: brew install ansible"
fi

if command -v git &>/dev/null; then
  GIT_VER=$(git --version | awk '{print $3}')
  pass "Git $GIT_VER"
else
  fail "Git not found — run: brew install git  (or install Xcode Command Line Tools)"
fi

if command -v gh &>/dev/null; then
  GH_VER=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
  pass "GitHub CLI $GH_VER"
else
  fail "GitHub CLI not found — run: brew install gh"
fi

if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1 | awk '{print $2}')
  PY_MAJOR=$(echo "$PY_VER" | cut -d. -f1)
  PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
  if [[ "$PY_MAJOR" -ge 3 && "$PY_MINOR" -ge 11 ]]; then
    pass "Python $PY_VER (>= 3.11 required)"
  else
    warn "Python $PY_VER found — 3.11+ recommended.  Run: brew install python@3.11"
  fi
else
  fail "Python 3 not found — run: brew install python3"
fi

# ─── SSH Keys ─────────────────────────────────────────────────────────────────
header "SSH Keys"

SSH_FOUND=false
for keyfile in ~/.ssh/soc-lab.pub ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
  if [[ -f "$keyfile" ]]; then
    KEY_TYPE=$(ssh-keygen -l -f "$keyfile" 2>/dev/null | awk '{print $4}' || echo "")
    pass "SSH public key: $keyfile  ($KEY_TYPE)"
    SSH_FOUND=true
    break
  fi
done

if ! $SSH_FOUND; then
  fail "No SSH public key found.  Run: ssh-keygen -t ed25519 -C 'soc-lab' -f ~/.ssh/soc-lab"
fi

if ssh-add -l &>/dev/null; then
  pass "SSH agent has key(s) loaded"
else
  warn "SSH agent has no keys loaded.  Run: ssh-add ~/.ssh/soc-lab (or your key path)"
fi

# ─── Disk Space ───────────────────────────────────────────────────────────────
header "Disk Space"

FREE_KB=$(df -k ~ 2>/dev/null | awk 'NR==2 {print $4}')
FREE_GB=$((FREE_KB / 1024 / 1024))
if [[ "$FREE_GB" -ge 150 ]]; then
  pass "Free disk: ${FREE_GB} GB  (150 GB minimum for all 3 VMs)"
elif [[ "$FREE_GB" -ge 100 ]]; then
  warn "Free disk: ${FREE_GB} GB  — 150 GB recommended; you may run out of space during Windows install"
else
  fail "Free disk: ${FREE_GB} GB  — need 150 GB free (wazuh-manager 60 GB + Windows 40 GB + Kali 40 GB + ISOs 15 GB)"
fi

# ─── RAM ──────────────────────────────────────────────────────────────────────
header "Memory"

MEMSIZE_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
MEMSIZE_GB=$((MEMSIZE_BYTES / 1024 / 1024 / 1024))
if [[ "$MEMSIZE_GB" -ge 16 ]]; then
  pass "RAM: ${MEMSIZE_GB} GB  (16 GB minimum)"
elif [[ "$MEMSIZE_GB" -ge 8 ]]; then
  warn "RAM: ${MEMSIZE_GB} GB  — 16 GB recommended.  With 8 GB, run only 2 VMs simultaneously (start Windows last)"
else
  fail "RAM: ${MEMSIZE_GB} GB  — 16 GB minimum to run all 3 VMs at once"
fi

# ─── Repository ───────────────────────────────────────────────────────────────
header "Repository"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$REPO_ROOT/ansible/requirements.yml" ]]; then
  pass "Repository root: $REPO_ROOT"
else
  fail "Cannot locate repo root.  Run this script from inside the soc-home-lab directory."
fi

if command -v ansible-galaxy &>/dev/null && ansible-galaxy collection list 2>/dev/null | grep -q "ansible.windows"; then
  pass "Ansible collection ansible.windows installed"
else
  warn "Ansible collection ansible.windows not found.  Run: cd $REPO_ROOT && ansible-galaxy install -r ansible/requirements.yml"
fi

# ─── ISO Files ────────────────────────────────────────────────────────────────
header "ISO Downloads  (warnings only — can download later)"

ISO_DIR="$HOME/Downloads/SOC-Lab-ISOs"

if [[ -d "$ISO_DIR" ]]; then
  UBUNTU_ISO=$(ls "$ISO_DIR"/ubuntu-*arm64*.iso 2>/dev/null | head -1 || true)
  if [[ -n "$UBUNTU_ISO" ]]; then
    pass "Ubuntu ARM64 ISO: $(basename "$UBUNTU_ISO")"
  else
    warn "Ubuntu ARM64 ISO not found in $ISO_DIR  — run: bash $REPO_ROOT/scripts/download-isos.sh"
  fi

  KALI_ISO=$(ls "$ISO_DIR"/kali-*arm64*.iso 2>/dev/null | head -1 || true)
  if [[ -n "$KALI_ISO" ]]; then
    pass "Kali ARM64 ISO: $(basename "$KALI_ISO")"
  else
    warn "Kali ARM64 ISO not found in $ISO_DIR  — download from https://www.kali.org/get-kali/#kali-installer-images"
  fi

  WIN_IMG=$(ls "$ISO_DIR"/*.vhdx "$ISO_DIR"/*Windows*.iso 2>/dev/null | head -1 || true)
  if [[ -n "$WIN_IMG" ]]; then
    pass "Windows 11 ARM64 image: $(basename "$WIN_IMG")"
  else
    warn "Windows 11 ARM64 image not found in $ISO_DIR  — see runbook/01-prerequisites.md for UUPDump instructions"
  fi
else
  warn "ISO directory $ISO_DIR does not exist.  Run: bash $REPO_ROOT/scripts/download-isos.sh"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo
echo "============================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC} · ${YELLOW}${WARN} warnings${NC} · ${RED}${FAIL} failed${NC}"
echo "============================================"
echo

if [[ "$FAIL" -gt 0 ]]; then
  echo "  Fix all [FAIL] items above before proceeding to VM creation."
  echo "  See runbook/01-prerequisites.md for installation instructions."
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo "  All required items passed.  Review [WARN] items — they may cause problems later."
  echo "  When ready, proceed to: runbook/02-utm-vm-creation.md"
  exit 0
else
  echo "  All checks passed.  Proceed to: runbook/02-utm-vm-creation.md"
  exit 0
fi

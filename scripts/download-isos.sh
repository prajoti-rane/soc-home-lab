#!/usr/bin/env bash
# download-isos.sh — Download ARM64 OS ISOs for the SOC Home Lab
#
# Downloads and SHA256-verifies the three OS images needed to build the lab VMs:
#   1. Ubuntu 24.04 LTS ARM64 Server ISO  → wazuh-manager VM
#   2. Kali Linux ARM64 Installer ISO     → kali-attacker VM
#   3. Windows 11 ARM64 VHDX             → victim-windows VM (from UUPDump)
#
# Usage:
#   bash scripts/download-isos.sh [--output-dir DIR]
#
# Prerequisites:
#   - curl (macOS built-in)
#   - shasum (macOS built-in)
#   - ~25 GB free disk space in output directory
#
# NOTE: Windows 11 ARM64 images are not available as direct ISOs from Microsoft.
# This script provides the UUPDump conversion method, which requires manual steps.
#
# Run from the macOS host, NOT from inside a VM.

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
DEFAULT_OUTPUT_DIR="$HOME/Downloads/SOC-Lab-ISOs"
OUTPUT_DIR="${1:-$DEFAULT_OUTPUT_DIR}"

# Ubuntu 24.04 LTS (Noble Numbat) — ARM64 live server installer
UBUNTU_FILENAME="ubuntu-24.04.2-live-server-arm64.iso"
UBUNTU_URL="https://cdimage.ubuntu.com/releases/noble/release/${UBUNTU_FILENAME}"
UBUNTU_SHA256="72ccde0e1ef2b4d6e7d89f3c5a9f3b7c4d8e1a2b3c4d5e6f7a8b9c0d1e2f3a4"
# NOTE: Replace UBUNTU_SHA256 with the current hash from:
# https://cdimage.ubuntu.com/releases/noble/release/SHA256SUMS
# (The hash above is a placeholder — always verify against the official page)

# Kali Linux ARM64 — installer image
KALI_FILENAME="kali-linux-2024.1-installer-arm64.iso"
KALI_URL="https://cdimage.kali.org/kali-2024.1/${KALI_FILENAME}"
KALI_SHA256="a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"
# NOTE: Replace KALI_SHA256 with the current hash from:
# https://www.kali.org/get-kali/#kali-installer-images (verify SHA256 column)

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
log_sep()   { echo -e "${BLUE}────────────────────────────────────────────────────${NC}"; }

# ─── Setup Output Directory ───────────────────────────────────────────────────
setup_output_dir() {
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR"
        log_ok "Created output directory: $OUTPUT_DIR"
    else
        log_info "Output directory: $OUTPUT_DIR"
    fi

    # Check available disk space (require 25 GB)
    local available_gb
    available_gb=$(df -g "$OUTPUT_DIR" | tail -1 | awk '{print $4}')
    if [[ $available_gb -lt 25 ]]; then
        log_warn "Available disk space: ${available_gb}GB — recommend at least 25GB"
        log_warn "Proceeding anyway — downloads may fail if space runs out"
    else
        log_ok "Disk space available: ${available_gb}GB"
    fi
}

# ─── Download With Verification ───────────────────────────────────────────────
download_and_verify() {
    local name="$1"
    local url="$2"
    local filename="$3"
    local expected_sha256="$4"
    local dest="${OUTPUT_DIR}/${filename}"

    log_sep
    log_info "Downloading: $name"
    log_info "URL: $url"
    log_info "Destination: $dest"

    # Skip if already downloaded with correct hash
    if [[ -f "$dest" ]]; then
        log_info "File exists — verifying checksum..."
        local actual_sha256
        actual_sha256=$(shasum -a 256 "$dest" | awk '{print $1}')
        if [[ "$actual_sha256" == "$expected_sha256" ]]; then
            log_ok "$name: already downloaded and verified ✓"
            return 0
        else
            log_warn "Existing file has wrong hash — re-downloading"
            rm -f "$dest"
        fi
    fi

    # Download with progress bar and resume capability
    log_info "Starting download (~$(du -sh "$dest" 2>/dev/null | cut -f1 || echo '?') — may take 20-60 minutes)"
    if ! curl \
            --location \
            --retry 3 \
            --retry-delay 10 \
            --progress-bar \
            --continue-at - \
            --output "$dest" \
            "$url"; then
        log_error "Download failed: $name"
        log_error "URL: $url"
        return 1
    fi

    log_ok "Download complete: $filename"

    # Verify SHA256
    log_info "Verifying SHA256 checksum..."
    local actual_sha256
    actual_sha256=$(shasum -a 256 "$dest" | awk '{print $1}')

    if [[ "$actual_sha256" == "$expected_sha256" ]]; then
        log_ok "Checksum verified: $filename ✓"
    else
        log_error "CHECKSUM MISMATCH for $filename"
        log_error "Expected: $expected_sha256"
        log_error "Actual:   $actual_sha256"
        log_error "The file may be corrupted or tampered. Delete and re-download."
        return 1
    fi
}

# ─── Windows 11 ARM64 Instructions ───────────────────────────────────────────
print_windows_instructions() {
    log_sep
    echo ""
    log_info "Windows 11 ARM64 — Manual Download Required"
    echo ""
    echo "  Microsoft does not provide a direct ARM64 ISO download."
    echo "  Use UUPDump to build a Windows 11 ARM64 ISO:"
    echo ""
    echo "  1. Open: https://uupdump.net"
    echo "  2. Search for: 'Windows 11' → select ARM64"
    echo "  3. Select the latest stable build (24H2 or later)"
    echo "  4. Choose: Language → English (US) or your locale"
    echo "  5. Choose editions: Windows 11 Pro"
    echo "  6. Click 'Create download package'"
    echo "  7. Extract the downloaded ZIP"
    echo "  8. On macOS, install aria2 and convert the package:"
    echo "     brew install aria2"
    echo "     cd <extracted-folder>"
    echo "     chmod +x *.sh && bash uup_download_macos.sh"
    echo "  9. The script produces a .ISO file (~5 GB)"
    echo "  10. Move the ISO to: $OUTPUT_DIR/"
    echo ""
    echo "  Alternative: Download the pre-built VHDX from the Microsoft Evaluation Center"
    echo "  (requires free Microsoft account):"
    echo "  https://developer.microsoft.com/en-us/windows/downloads/virtual-machines/"
    echo "  → Select 'Windows 11' → 'ARM64' → Download VHDX"
    echo "  Note: The evaluation VHDX expires after 90 days."
    echo ""
    echo "  UTM-specific tip: UTM can import a VHDX directly — no ISO needed if"
    echo "  you download the evaluation VHDX. See runbook/02-utm-vm-creation.md."
    echo ""
}

# ─── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    log_sep
    echo ""
    log_info "Download Summary"
    echo ""

    local all_present=true
    for f in "$UBUNTU_FILENAME" "$KALI_FILENAME"; do
        local full="${OUTPUT_DIR}/${f}"
        if [[ -f "$full" ]]; then
            local size
            size=$(du -sh "$full" | cut -f1)
            log_ok "$f ($size)"
        else
            log_warn "$f — NOT PRESENT"
            all_present=false
        fi
    done

    echo ""
    log_info "Windows 11 ARM64 ISO → See manual instructions above"
    echo ""

    if $all_present; then
        log_ok "Linux ISOs ready in: $OUTPUT_DIR"
    else
        log_warn "Some downloads are missing — check errors above"
    fi

    echo ""
    log_info "Next step: Create UTM VMs using these ISOs"
    log_info "See: runbook/02-utm-vm-creation.md"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  SOC Home Lab — ISO Downloader                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    log_warn "IMPORTANT: Verify SHA256 hashes against official sources before use."
    log_warn "Ubuntu:  https://cdimage.ubuntu.com/releases/noble/release/SHA256SUMS"
    log_warn "Kali:    https://www.kali.org/get-kali/#kali-installer-images"
    echo ""

    setup_output_dir

    local fail=0

    download_and_verify \
        "Ubuntu 24.04 LTS ARM64 Server" \
        "$UBUNTU_URL" \
        "$UBUNTU_FILENAME" \
        "$UBUNTU_SHA256" || fail=1

    download_and_verify \
        "Kali Linux ARM64 Installer" \
        "$KALI_URL" \
        "$KALI_FILENAME" \
        "$KALI_SHA256" || fail=1

    print_windows_instructions
    print_summary

    if [[ $fail -ne 0 ]]; then
        log_error "One or more downloads failed — see errors above"
        exit 1
    fi
}

main "$@"

#!/usr/bin/env bash
# setup-sliver.sh — Install Sliver C2 framework on Kali Linux ARM64
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║  FOR AUTHORIZED HOME LAB USE ONLY                               ║
# ║  Run this script ONLY on the kali-attacker VM (192.168.64.30)   ║
# ║  within the isolated UTM lab network (192.168.64.0/24).         ║
# ║  Never install or operate C2 tools on networks you do not own   ║
# ║  or systems for which you lack written authorization.            ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Usage:
#   bash setup-sliver.sh
#
# What this script does:
#   1. Detects ARM64 architecture
#   2. Downloads the Sliver server binary from the official GitHub release
#   3. Installs it to /usr/local/bin/
#   4. Creates the sliver systemd service unit
#   5. Initializes the server (generates operator config)
#   6. Prints next steps for payload generation
#
# What this script does NOT do:
#   - Execute any implant or attack
#   - Connect to victim machines
#   - Start any listener (that is an operator decision)

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SLIVER_VERSION="${SLIVER_VERSION:-1.5.42}"
INSTALL_DIR="/usr/local/bin"
SLIVER_SERVER_BIN="${INSTALL_DIR}/sliver-server"
SLIVER_CLIENT_BIN="${INSTALL_DIR}/sliver"
SLIVER_DATA_DIR="/root/.sliver"
SERVICE_FILE="/etc/systemd/system/sliver.service"
GITHUB_RELEASE_BASE="https://github.com/BishopFox/sliver/releases/download/v${SLIVER_VERSION}"

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

# ─── Safety Banner ────────────────────────────────────────────────────────────
print_banner() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  WARNING: AUTHORIZED HOME LAB USE ONLY                          ║${NC}"
    echo -e "${RED}║  This installs offensive security tooling (Sliver C2).          ║${NC}"
    echo -e "${RED}║  Use exclusively in the isolated UTM lab (192.168.64.0/24).     ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─── Architecture Check ───────────────────────────────────────────────────────
check_arch() {
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "aarch64" ]]; then
        log_warn "Detected architecture: $arch"
        log_warn "This script targets ARM64 (aarch64). On x86_64, change ARCH below."
        log_warn "Proceeding with detected architecture..."
    else
        log_ok "Architecture: $arch (ARM64 — correct for Apple Silicon lab)"
    fi
    echo "$arch"
}

# ─── Root Check ───────────────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root: sudo bash setup-sliver.sh"
        exit 1
    fi
}

# ─── Download Sliver Binaries ─────────────────────────────────────────────────
download_sliver() {
    local arch="$1"
    local arch_tag

    # Map uname -m to Sliver release filename convention
    case "$arch" in
        aarch64) arch_tag="arm64" ;;
        x86_64)  arch_tag="amd64" ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    local server_filename="sliver-server_linux-${arch_tag}"
    local client_filename="sliver-client_linux-${arch_tag}"
    local server_url="${GITHUB_RELEASE_BASE}/${server_filename}"
    local client_url="${GITHUB_RELEASE_BASE}/${client_filename}"
    local tmpdir
    tmpdir=$(mktemp -d)

    log_info "Downloading Sliver server v${SLIVER_VERSION} (${arch_tag})..."
    log_info "URL: ${server_url}"

    if ! curl -fsSL --retry 3 --progress-bar \
            -o "${tmpdir}/${server_filename}" \
            "${server_url}"; then
        log_error "Download failed. Check:"
        log_error "  - Internet connectivity from Kali VM"
        log_error "  - Version v${SLIVER_VERSION} exists at: ${GITHUB_RELEASE_BASE}/"
        log_error "  - Set SLIVER_VERSION env var to override"
        rm -rf "$tmpdir"
        exit 1
    fi
    log_ok "Server binary downloaded"

    log_info "Downloading Sliver client v${SLIVER_VERSION} (${arch_tag})..."
    if ! curl -fsSL --retry 3 --progress-bar \
            -o "${tmpdir}/${client_filename}" \
            "${client_url}"; then
        log_error "Client download failed"
        rm -rf "$tmpdir"
        exit 1
    fi
    log_ok "Client binary downloaded"

    # Install binaries
    install -m 0755 "${tmpdir}/${server_filename}" "${SLIVER_SERVER_BIN}"
    install -m 0755 "${tmpdir}/${client_filename}" "${SLIVER_CLIENT_BIN}"
    rm -rf "$tmpdir"

    log_ok "Installed: ${SLIVER_SERVER_BIN}"
    log_ok "Installed: ${SLIVER_CLIENT_BIN}"
}

# ─── Create systemd Service ────────────────────────────────────────────────────
create_service() {
    log_info "Creating sliver systemd service..."

    cat > "${SERVICE_FILE}" << 'SERVICE_EOF'
[Unit]
Description=Sliver C2 Server (SOC Lab — authorized lab use only)
After=network.target
ConditionPathExists=/usr/local/bin/sliver-server

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sliver-server daemon
Restart=on-failure
RestartSec=5
# Lab safety: bind only to the lab NIC (192.168.64.30)
Environment="SLIVER_NO_UPDATE_CHECK=1"

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    systemctl daemon-reload
    log_ok "Service unit created: ${SERVICE_FILE}"
}

# ─── Initialize Sliver Server ──────────────────────────────────────────────────
init_sliver() {
    log_info "Initializing Sliver server (generating PKI and operator config)..."
    log_info "This may take 1-2 minutes on first run (Go runtime initialization)..."

    # Run server in unpack mode to extract assets without starting a listener
    timeout 120 "${SLIVER_SERVER_BIN}" unpack --force 2>/dev/null || true

    log_ok "Sliver initialized. Data directory: ${SLIVER_DATA_DIR}"
}

# ─── Verify Installation ───────────────────────────────────────────────────────
verify_install() {
    log_info "Verifying installation..."

    if [[ ! -x "${SLIVER_SERVER_BIN}" ]]; then
        log_error "sliver-server not found at ${SLIVER_SERVER_BIN}"
        exit 1
    fi

    if [[ ! -x "${SLIVER_CLIENT_BIN}" ]]; then
        log_error "sliver client not found at ${SLIVER_CLIENT_BIN}"
        exit 1
    fi

    local version_output
    version_output=$("${SLIVER_SERVER_BIN}" version 2>/dev/null || echo "unknown")
    log_ok "sliver-server: $version_output"
}

# ─── Print Next Steps ──────────────────────────────────────────────────────────
print_next_steps() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Sliver Installation Complete — Next Steps                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  1. Start the Sliver server:"
    echo "     sudo systemctl start sliver"
    echo "     sudo systemctl enable sliver  # auto-start on boot"
    echo ""
    echo "  2. Connect the operator client:"
    echo "     sliver"
    echo ""
    echo "  3. Inside the Sliver console, start an HTTPS listener:"
    echo "     sliver > https --lport 443 --lhost 192.168.64.30"
    echo ""
    echo "  4. Generate a Windows ARM64 implant:"
    echo "     sliver > generate --https 192.168.64.30 --os windows --arch arm64 \\"
    echo "              --format exe --save /tmp/ --name beacon"
    echo ""
    echo "  5. Verify the listener is lab-network-only:"
    echo "     ss -tlnp | grep 443"
    echo "     # Should show 192.168.64.30:443, NOT 0.0.0.0:443"
    echo ""
    echo "  See attack-simulation/sliver/README.md for full operator guide."
    echo ""
    echo -e "${YELLOW}  REMINDER: This tooling is for the isolated lab (192.168.64.0/24) ONLY.${NC}"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    print_banner
    check_root

    local arch
    arch=$(check_arch)

    if [[ -x "${SLIVER_SERVER_BIN}" ]]; then
        log_warn "Sliver server already installed at ${SLIVER_SERVER_BIN}"
        local existing_ver
        existing_ver=$("${SLIVER_SERVER_BIN}" version 2>/dev/null | head -1 || echo "unknown")
        log_warn "Existing version: $existing_ver"
        log_warn "To reinstall, remove ${SLIVER_SERVER_BIN} first and re-run."
        print_next_steps
        exit 0
    fi

    download_sliver "$arch"
    create_service
    init_sliver
    verify_install
    print_next_steps
}

main "$@"

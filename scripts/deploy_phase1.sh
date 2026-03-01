#!/bin/bash
# ==============================================================================
# TRAVEL ROUTER DEPLOYMENT - PHASE 1: PREPARATION & BUILD (V5)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PROJECT_ROOT}/config.env"
source "${SCRIPT_DIR}/lib/logging.sh"

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true; log_info "DRY-RUN MODE ENABLED. No changes will be made." ;;
  esac
done
export DRY_RUN

if [[ $EUID -ne 0 ]]; then
    if [ "$DRY_RUN" = "true" ]; then
        log_warn "Not running as root — dry-run only, no changes will be made."
    else
        die "This script must be run as root. Please use 'sudo ./deploy_phase1.sh'"
    fi
fi

_INSTALL_STARTED=false
cleanup_on_failure() {
    if ! $_INSTALL_STARTED; then
        log_warn "A preflight check failed before any installation began. No cleanup needed."
        return
    fi
    log_warn "================================================================"
    log_warn "Phase 1 encountered an error and exited prematurely."
    log_warn "  - Docker:    $(command -v docker    &>/dev/null && echo installed || echo 'not installed')"
    log_warn "  - Tailscale: $(command -v tailscale &>/dev/null && echo installed || echo 'not installed')"
    log_warn "To reset: sudo apt-get remove --purge docker-ce tailscale && sudo rm -rf /opt/covert-router"
    log_warn "================================================================"
}
trap cleanup_on_failure ERR

source "${SCRIPT_DIR}/lib/sys_prep.sh"
source "${SCRIPT_DIR}/lib/tailscale.sh"
source "${SCRIPT_DIR}/lib/rustdesk.sh"
source "${SCRIPT_DIR}/lib/alfa_driver.sh"
source "${SCRIPT_DIR}/lib/openwrt_build.sh"
source "${SCRIPT_DIR}/lib/phase2_stage.sh"

clear
echo "================================================================"
echo "   COVERT SD-WAN LAB: PHASE 1 DEPLOYMENT (ONLINE PREP)"
echo "================================================================"
log_info "Running pre-flight checks..."

if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    die "No internet connection detected. Please connect before running Phase 1."
fi
if ! lsusb | grep -qE "0bda:|0e8d:|148f:"; then
    log_warn "No known ALFA adapter detected. Make sure it is plugged in!"
fi
if ! apt-cache show "linux-headers-$(uname -r)" &>/dev/null; then
    log_warn "Kernel headers for $(uname -r) may not be available. DKMS compilation may fail."
fi

echo "This script will:"
echo "  1. Install system dependencies (Docker, git, build tools)"
echo "  2. Compile the ALFA Wi-Fi driver for the host kernel"
echo "  3. Install and authenticate Tailscale & RustDesk (OOB Access)"
echo "  4. Compile a custom OpenWrt image with ImageBuilder"
echo "  5. Stage the Phase 2 systemd Takeover service"
echo "================================================================"

if ! prompt_confirm "Are you ready to begin Phase 1?"; then
    log_warn "Deployment aborted by user."; exit 0
fi

_INSTALL_STARTED=true

log_info "Starting System Preparation...";      install_system_dependencies
log_info "Compiling ALFA Wi-Fi DKMS Driver..."; compile_alfa_driver
log_info "Setting up Tailscale (OOB)...";       install_and_auth_tailscale
log_info "Setting up RustDesk (OOB)...";        install_rustdesk
log_info "Building Custom OpenWrt RootFS...";   build_openwrt_image
log_info "Staging Phase 2 Systemd Service...";  stage_phase2_service

echo ""
echo "================================================================"
echo -e "${COLOR_WARNING}*** WARNING ***${COLOR_RESET}"
echo "Phase 1 complete. Proceeding will disable host network managers"
echo "and REBOOT to initiate Phase 2 (Dark Boot)."
echo "================================================================"

if prompt_confirm "Acknowledge and proceed with network lockdown & reboot?"; then
    log_info "Disabling Host Networking Services..."
    exec_or_log systemctl disable NetworkManager wpa_supplicant systemd-networkd dhcpcd >/dev/null 2>&1 || true
    log_success "Phase 1 Complete. Initiating System Reboot..."
    trap - ERR
    exec_or_log reboot
else
    log_info "Aborting final lockdown. System remains in Phase 1 state."; exit 0
fi

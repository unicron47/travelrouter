#!/bin/bash
# ==============================================================================
# TRAVEL ROUTER DEPLOYMENT - PHASE 1: PREPARATION & BUILD (V5)
# ==============================================================================
# Description: This is the master controller script for Phase 1. It must be run
# while the Raspberry Pi has active internet access (e.g., via eth0). 
# It prepares the host OS, compiles drivers, builds the custom OpenWrt image,
# and sets up the OOB management (Tailscale/RustDesk).
# ==============================================================================

# --- Safety Enforcements ---
# Exit immediately if a pipeline fails (-e), if an undefined variable is used (-u),
# and ensure pipeline errors are caught (-o pipefail).
set -euo pipefail

# --- Path Resolution ---
# Ensure we are executing from the scripts directory, regardless of where the user called it from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# --- Import Modules ---
# We source the global configuration and our function libraries.
source "${PROJECT_ROOT}/config.env"
source "${SCRIPT_DIR}/lib/logging.sh"

source "${SCRIPT_DIR}/lib/sys_prep.sh"
source "${SCRIPT_DIR}/lib/tailscale.sh"
source "${SCRIPT_DIR}/lib/rustdesk.sh"
source "${SCRIPT_DIR}/lib/alfa_driver.sh"
source "${SCRIPT_DIR}/lib/openwrt_build.sh"
source "${SCRIPT_DIR}/lib/phase2_stage.sh"

# ==============================================================================
# PRE-FLIGHT CHECKS
# ==============================================================================
# Ensure the script is run as root (required for apt, dkms, systemd).
if [[ $EUID -ne 0 ]]; then
   die "This script must be run as root. Please use 'sudo ./deploy_phase1.sh'"
fi

clear
echo "================================================================"
echo "   COVERT SD-WAN LAB: PHASE 1 DEPLOYMENT (ONLINE PREP)"
echo "================================================================"
echo "This script will:"
echo "  1. Install system dependencies (Docker, git, build tools)"
echo "  2. Compile the ALFA Wi-Fi driver for the host kernel"
echo "  3. Install and authenticate Tailscale & RustDesk (OOB Access)"
echo "  4. Compile a custom OpenWrt image with ImageBuilder"
echo "  5. Stage the Phase 2 systemd Takeover service"
echo "================================================================"

if ! prompt_confirm "Are you ready to begin Phase 1?"; then
    log_warn "Deployment aborted by user."
    exit 0
fi

# ==============================================================================
# MAIN EXECUTION FLOW
# ==============================================================================

log_info "Starting System Preparation..."
install_system_dependencies

log_info "Compiling ALFA Wi-Fi DKMS Driver..."
compile_alfa_driver

log_info "Setting up Out-of-Band Management (Tailscale)..."
install_and_auth_tailscale

log_info "Setting up Out-of-Band Management (RustDesk)..."
install_rustdesk

log_info "Building Custom OpenWrt RootFS via ImageBuilder..."
log_info "Target Packages: ${OPENWRT_PACKAGES}"
build_openwrt_image

log_info "Staging Phase 2 Systemd Service..."
stage_phase2_service

# ==============================================================================
# THE POINT OF NO RETURN
# ==============================================================================
echo ""
echo "================================================================"
echo -e "${COLOR_WARNING}                  *** WARNING ***${COLOR_RESET}"
echo "Phase 1 is complete. The next step will permanently disable"
echo "the Host Pi OS network managers (NetworkManager, wpa_supplicant)."
echo "You will lose standard SSH access."
echo ""
echo "The system will then REBOOT to initiate Phase 2 (Dark Boot)."
echo "================================================================"

if prompt_confirm "Acknowledge and proceed with network lockdown & reboot?"; then
    log_info "Disabling Host Networking Services..."
    sudo systemctl disable NetworkManager wpa_supplicant systemd-networkd dhcpcd >/dev/null 2>&1 || true
    log_info "Services disabled."
    
    log_success "Phase 1 Complete. Initiating System Reboot..."
    sudo reboot
else
    log_info "Aborting final lockdown. System remains in Phase 1 state."
    exit 0
fi

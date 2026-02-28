#!/bin/bash
# ==============================================================================
# MODULE: RUSTDESK
# ==============================================================================

install_rustdesk() {
    log_info "Checking for RustDesk..."
    if ! command -v rustdesk &> /dev/null; then
        log_info "Installing RustDesk..."
        # RUSTDESK_DEB_URL is defined in config.env
        wget "${RUSTDESK_DEB_URL}" -O /tmp/rustdesk.deb
        sudo apt-get install -y /tmp/rustdesk.deb
        rm /tmp/rustdesk.deb
        log_success "RustDesk installed successfully."
    else
        log_info "RustDesk is already installed."
    fi

    log_info "Configuring RustDesk for Direct IP Access via Tailscale..."
    # RustDesk stores its configuration in the user's home directory.
    # We must ensure the directory exists and set the 'direct-server' option to 'Y'.
    # Because this script runs as root, we need to target the primary user (e.g., 'pi' or the user who invoked sudo).
    local TARGET_USER=${SUDO_USER:-$(whoami)}
    local RUSTDESK_CONF_DIR="/home/${TARGET_USER}/.config/rustdesk"
    local RUSTDESK_CONF_FILE="${RUSTDESK_CONF_DIR}/RustDesk2.toml"

    mkdir -p "${RUSTDESK_CONF_DIR}"
    
    if [ ! -f "${RUSTDESK_CONF_FILE}" ]; then
        touch "${RUSTDESK_CONF_FILE}"
    fi

    # Check if direct-server is already set, if not, append it.
    if ! grep -q "^direct-server=" "${RUSTDESK_CONF_FILE}"; then
        echo "direct-server='Y'" >> "${RUSTDESK_CONF_FILE}"
    else
        sed -i "s/^direct-server=.*/direct-server='Y'/" "${RUSTDESK_CONF_FILE}"
    fi
    
    # Ensure correct ownership
    chown -R "${TARGET_USER}:${TARGET_USER}" "${RUSTDESK_CONF_DIR}"

    # Restart and enable the RustDesk service so the config takes effect and survives reboots
    sudo systemctl enable --now rustdesk 2>/dev/null || true

    log_success "RustDesk configured for Direct IP Access."
    
    echo "================================================================"
    echo -e "${COLOR_WARNING}*** RUSTDESK REMINDER ***${COLOR_RESET}"
    echo "To connect to this Pi later, you MUST install RustDesk on your"
    echo "personal laptop/desktop. Once the Pi is on the VPN, you will"
    echo "connect by entering the Pi's Tailscale IP address into the"
    echo "'Enter Remote ID' box in the RustDesk app on your laptop."
    echo "================================================================"
    
    if ! prompt_confirm "Have you installed RustDesk on your laptop and do you understand how to connect?"; then
        log_warn "Please install RustDesk on your laptop before proceeding to Phase 2."
    fi
}

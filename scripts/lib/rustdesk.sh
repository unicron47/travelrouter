#!/bin/bash
# ==============================================================================
# MODULE: RUSTDESK
# ==============================================================================

install_rustdesk() {
    log_info "Checking for RustDesk..."
    if ! command -v rustdesk &> /dev/null; then
        if [ "${DRY_RUN:-false}" = "true" ]; then
            log_info "[DRY-RUN] Would download and verify RustDesk from ${RUSTDESK_DEB_URL}"
        else
            wget "${RUSTDESK_DEB_URL}" -O /tmp/rustdesk.deb
            if ! echo "${RUSTDESK_DEB_SHA256}  /tmp/rustdesk.deb" | sha256sum -c - >/dev/null 2>&1; then
                rm -f /tmp/rustdesk.deb
                die "RustDesk checksum mismatch — update RUSTDESK_DEB_SHA256 in config.env."
            fi
            apt-get install -y /tmp/rustdesk.deb
            rm -f /tmp/rustdesk.deb
        fi
        log_success "RustDesk installed."
    else
        log_info "RustDesk already installed."
    fi

    local TARGET_USER=${SUDO_USER:-$(whoami)}
    local CONF_DIR="/home/${TARGET_USER}/.config/rustdesk"
    local CONF_FILE="${CONF_DIR}/RustDesk2.toml"

    exec_or_log mkdir -p "${CONF_DIR}"
    [ ! -f "${CONF_FILE}" ] && exec_or_log touch "${CONF_FILE}"
    if ! grep -q "^direct-server=" "${CONF_FILE}" 2>/dev/null; then
        exec_or_log sh -c "echo \"direct-server='Y'\" >> \"${CONF_FILE}\""
    else
        exec_or_log sed -i "s/^direct-server=.*/direct-server='Y'/" "${CONF_FILE}"
    fi
    exec_or_log chown -R "${TARGET_USER}:${TARGET_USER}" "${CONF_DIR}"
    exec_or_log systemctl enable --now rustdesk 2>/dev/null || true
    log_success "RustDesk configured for Direct IP Access."

    echo "================================================================"
    echo -e "${COLOR_WARNING}*** RUSTDESK REMINDER ***${COLOR_RESET}"
    echo "Install RustDesk on your laptop and connect via the Pi's Tailscale IP."
    echo "================================================================"
    prompt_confirm "Have you installed RustDesk on your laptop?"         || log_warn "Install RustDesk on your laptop before Phase 2."
}

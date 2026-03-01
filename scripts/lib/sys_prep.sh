#!/bin/bash
# ==============================================================================
# MODULE: SYS_PREP
# ==============================================================================

install_system_dependencies() {
    log_info "Updating package lists..."
    exec_or_log apt-get update

    log_info "Installing required packages..."
    exec_or_log apt-get install -y "linux-headers-$(uname -r)" build-essential dkms git bc curl wget jq zstd

    log_info "Installing Docker Engine..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        # SECURITY NOTE: fetched over HTTPS from docker.com. For production, pin and verify.
        exec_or_log sh /tmp/get-docker.sh
        exec_or_log usermod -aG docker "$USER"
        rm -f /tmp/get-docker.sh
        log_success "Docker installed."
    else
        log_info "Docker already installed."
    fi
    log_success "System dependencies installed."
}

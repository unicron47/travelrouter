#!/bin/bash
# ==============================================================================
# MODULE: SYS_PREP
# ==============================================================================

install_system_dependencies() {
    log_info "Updating package lists..."
    sudo apt-get update

    log_info "Installing basic required packages..."
    sudo apt-get install -y "linux-headers-$(uname -r)" build-essential dkms git bc curl wget jq

    log_info "Installing Docker Engine..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        sudo usermod -aG docker "$USER"
        rm /tmp/get-docker.sh
        log_success "Docker installed successfully."
    else
        log_info "Docker is already installed."
    fi

    log_success "System dependencies installed."
}

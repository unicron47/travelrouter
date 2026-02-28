#!/bin/bash
# ==============================================================================
# MODULE: TAILSCALE
# ==============================================================================

install_and_auth_tailscale() {
    log_info "Checking for Tailscale..."
    if ! command -v tailscale &> /dev/null; then
        log_info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
        log_success "Tailscale installed successfully."
    else
        log_info "Tailscale is already installed."
    fi

    log_info "Bringing up Tailscale..."
    # Enable the systemd service to ensure it starts on boot
    sudo systemctl enable --now tailscaled
    
    # We do NOT advertise as an exit node. The travel router will *use* an exit node.
    sudo tailscale up
    
    log_success "Tailscale is installed."
    log_info "If this is your first time, please follow the Tailscale authentication prompt above."
    log_info "Remember: You must configure a stationary device at your home to act as your Exit Node."
}

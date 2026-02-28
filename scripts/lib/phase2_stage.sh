#!/bin/bash
# ==============================================================================
# MODULE: STAGE PHASE 2 (DARK BOOT)
# ==============================================================================

stage_phase2_service() {
    log_info "Staging Phase 2 (Dark Boot) Systemd Service..."

    # Ensure the destination directory exists
    sudo mkdir -p /opt/covert-router

    # Copy the orchestrator script
    log_info "Deploying orchestrator script to /opt/covert-router/covert_takeover.sh..."
    sudo cp "${PROJECT_ROOT}/scripts/covert_takeover.sh" /opt/covert-router/
    sudo chmod +x /opt/covert-router/covert_takeover.sh

    # Copy the systemd service file
    log_info "Deploying systemd service unit..."
    sudo cp "${PROJECT_ROOT}/systemd/covert-router.service" /etc/systemd/system/

    # Reload systemd and enable the service to start on boot
    log_info "Enabling covert-router.service..."
    sudo systemctl daemon-reload
    sudo systemctl enable covert-router.service

    log_success "Phase 2 Service staged successfully. It will activate on the next boot."
}

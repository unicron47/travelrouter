#!/bin/bash
# ==============================================================================
# MODULE: STAGE PHASE 2 (DARK BOOT)
# ==============================================================================

_integrity_check() {
    local src="$1" dst="$2" label="$3"
    local expected actual
    expected=$(sha256sum "$src" | awk '{print $1}')
    cp "$src" "$dst"
    actual=$(sha256sum "$dst" | awk '{print $1}')
    [ "$expected" = "$actual" ] || die "SECURITY ERROR: $label integrity check failed!"
}

stage_phase2_service() {
    log_info "Staging Phase 2 (Dark Boot) Systemd Service..."
    exec_or_log mkdir -p /opt/covert-router

    log_info "Deploying orchestrator script..."
    if [ "${DRY_RUN:-false}" = "true" ]; then
        exec_or_log cp "${PROJECT_ROOT}/scripts/covert_takeover.sh" /opt/covert-router/
        exec_or_log chmod +x /opt/covert-router/covert_takeover.sh
    else
        _integrity_check "${PROJECT_ROOT}/scripts/covert_takeover.sh"             /opt/covert-router/covert_takeover.sh "covert_takeover.sh"
        chmod +x /opt/covert-router/covert_takeover.sh
    fi

    log_info "Deploying systemd service unit..."
    exec_or_log cp "${PROJECT_ROOT}/systemd/covert-router.service" /etc/systemd/system/

    log_info "Deploying config.env..."
    if [ "${DRY_RUN:-false}" = "true" ]; then
        exec_or_log cp "${PROJECT_ROOT}/config.env" /opt/covert-router/
        exec_or_log chmod 600 /opt/covert-router/config.env
    else
        _integrity_check "${PROJECT_ROOT}/config.env" /opt/covert-router/config.env "config.env"
        chmod 600 /opt/covert-router/config.env
    fi

    log_info "Deploying logging library..."
    if [ "${DRY_RUN:-false}" = "true" ]; then
        exec_or_log cp "${PROJECT_ROOT}/scripts/lib/logging.sh" /opt/covert-router/
        exec_or_log chmod 644 /opt/covert-router/logging.sh
    else
        _integrity_check "${PROJECT_ROOT}/scripts/lib/logging.sh"             /opt/covert-router/logging.sh "logging.sh"
        chmod 644 /opt/covert-router/logging.sh
    fi

    log_info "Enabling covert-router.service..."
    exec_or_log systemctl daemon-reload
    exec_or_log systemctl enable covert-router.service

    log_success "Phase 2 Service staged. It will activate on next boot."
}

#!/bin/bash
# ==============================================================================
# MODULE: TAILSCALE
# ==============================================================================

install_and_auth_tailscale() {
    log_info "Checking for Tailscale..."
    if ! command -v tailscale &> /dev/null; then
        if [ "${DRY_RUN:-false}" = "true" ]; then
            log_info "[DRY-RUN] Would download and verify Tailscale GPG key and add APT repo."
        else
            curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bookworm.noarmor.gpg                 -o /tmp/tailscale-keyring.gpg
            rm -f /tmp/ts-check.gpg
            gpg --dearmor < /tmp/tailscale-keyring.gpg                 | gpg --no-default-keyring --keyring /tmp/ts-check.gpg --import 2>/dev/null
            local fp
            fp=$(gpg --no-default-keyring --keyring /tmp/ts-check.gpg                 --fingerprint 2>/dev/null | grep -A1 "pub" | tail -1 | tr -d ' ')
            if [ "$fp" != "2596A99EAAB33821893C0A79458CA832957F5868" ]; then
                rm -f /tmp/tailscale-keyring.gpg /tmp/ts-check.gpg
                die "Tailscale GPG fingerprint mismatch — possible supply chain attack!"
            fi
            tee /usr/share/keyrings/tailscale-archive-keyring.gpg                 < /tmp/tailscale-keyring.gpg >/dev/null
            rm -f /tmp/tailscale-keyring.gpg /tmp/ts-check.gpg

            curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bookworm.tailscale-keyring.list                 -o /tmp/tailscale.list
            local unexpected
            unexpected=$(grep -vE "^(deb |#|$)" /tmp/tailscale.list                 | grep -v "pkgs.tailscale.com" || true)
            [ -n "$unexpected" ] && die "Unexpected content in Tailscale repo list: $unexpected"
            mv /tmp/tailscale.list /etc/apt/sources.list.d/tailscale.list
            apt-get update && apt-get install -y tailscale
        fi
        log_success "Tailscale installed."
    else
        log_info "Tailscale already installed."
    fi

    exec_or_log systemctl enable --now tailscaled
    exec_or_log tailscale up
    log_success "Tailscale is up."
    log_info "Configure a home device as your Exit Node."
}

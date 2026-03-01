#!/bin/bash
# ==============================================================================
# MODULE: ALFA_DRIVER
# ==============================================================================

compile_alfa_driver() {
    log_info "Determining ALFA adapter model..."
    echo "================================================================"
    echo "Which ALFA Network adapter do you have?"
    echo "1) AWUS036AC  (Realtek RTL8812AU)"
    echo "2) AWUS036ACH (Realtek RTL8812AU)"
    echo "3) AWUS036ACM (MediaTek MT7612U)"
    echo "================================================================"
    read -r -p "Enter choice [1-3]: " alfa_choice

    case $alfa_choice in
        1|2)
            log_info "Selected RTL8812AU. Compiling via DKMS..."
            if ! dkms status | grep -q "8812au"; then
                local repo_dir
                repo_dir="/tmp/$(basename "${ALFA_DRIVER_REPO_8812AU}" .git)"
                rm -rf "$repo_dir"
                git clone "${ALFA_DRIVER_REPO_8812AU}" "$repo_dir"
                exec_or_log "$repo_dir/install-driver.sh" NoPrompt                     || die "Failed to compile ALFA driver."
                log_success "RTL8812AU driver installed."
            else
                log_info "RTL8812AU driver already installed via DKMS."
            fi
            ;;
        3)
            log_info "Selected MT7612U (AWUS036ACM) — native kernel support."
            exec_or_log apt-get install -y firmware-misc-nonfree
            export OPENWRT_PACKAGES="${OPENWRT_PACKAGES} ${OPENWRT_PACKAGES_ACM}"
            log_success "Host firmware verified. OpenWrt packages updated."
            ;;
        *)
            die "Invalid choice — re-run and select 1, 2, or 3."
            ;;
    esac
}

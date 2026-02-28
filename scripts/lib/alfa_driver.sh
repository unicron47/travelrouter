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
            log_info "Selected RTL8812AU adapter. Compiling driver via DKMS..."
            if ! dkms status | grep -q "8812au"; then
                (
                    cd /tmp
                    rm -rf 8812au-20210820
                    git clone https://github.com/morrownr/8812au-20210820.git
                    cd 8812au-20210820
                    # Run the installation script in non-interactive mode
                    sudo ./install-driver.sh NoPrompt
                ) || die "Failed to compile ALFA driver."
                log_success "RTL8812AU driver successfully compiled and installed."
            else
                log_info "RTL8812AU driver is already installed via DKMS."
            fi
            ;;
        3)
            log_info "Selected MT7612U adapter (AWUS036ACM)."
            log_info "This chipset is supported natively by the Linux kernel."
            log_info "Ensuring firmware packages are installed on the host..."
            sudo apt-get install -y firmware-misc-nonfree
            
            # We also need to ensure OpenWrt has the module baked in.
            # We append it to the global variable so the image builder catches it.
            export OPENWRT_PACKAGES="${OPENWRT_PACKAGES} ${OPENWRT_PACKAGES_ACM}"
            log_success "Host firmware verified. OpenWrt build packages updated."
            ;;
        *)
            die "Invalid choice. Please re-run the script and select a valid adapter."
            ;;
    esac
}

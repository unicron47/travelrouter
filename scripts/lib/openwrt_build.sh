#!/bin/bash
# ==============================================================================
# MODULE: OPENWRT_BUILD
# ==============================================================================

build_openwrt_image() {
    local IMAGEBUILDER_TAR="openwrt-imagebuilder-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}.Linux-x86_64.tar.zst"
    local IMAGEBUILDER_DIR="openwrt-imagebuilder-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}.Linux-x86_64"

    log_info "Preparing OpenWrt ImageBuilder..."
    cd "${PROJECT_ROOT}" || return

    if [ ! -d "${IMAGEBUILDER_DIR}" ]; then
        if [ ! -f "${IMAGEBUILDER_TAR}" ]; then
            log_info "Downloading OpenWrt ImageBuilder..."
            wget "https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}/${IMAGEBUILDER_TAR}"
        fi
        log_info "Extracting ImageBuilder..."
        sudo apt-get install -y zstd
        tar -I zstd -xf "${IMAGEBUILDER_TAR}"
    fi

    log_info "Building custom OpenWrt rootfs..."
    cd "${IMAGEBUILDER_DIR}" || return

    # We build the rootfs.tar.gz for Docker
    make image PROFILE="generic" PACKAGES="${OPENWRT_PACKAGES}" FILES="${PROJECT_ROOT}/assets/openwrt_files"

    log_success "OpenWrt custom image built."
}

#!/bin/bash
# ==============================================================================
# MODULE: OPENWRT_BUILD
# ==============================================================================

build_openwrt_image() {
    local host_arch
    host_arch=$(uname -m)

    # Select the correct ImageBuilder for the host architecture.
    # The x86-64 ImageBuilder cannot run on ARM64 — OpenWrt provides a native
    # ARM64 ImageBuilder for building on Raspberry Pi / aarch64 hosts.
    local IB_ARCH
    if [ "$host_arch" = "x86_64" ]; then
        IB_ARCH="Linux-x86_64"
    elif [ "$host_arch" = "aarch64" ]; then
        IB_ARCH="Linux-aarch64"
    else
        die "Unsupported host architecture: $host_arch. Must be x86_64 or aarch64."
    fi

    local IMAGEBUILDER_TAR="openwrt-imagebuilder-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}.${IB_ARCH}.tar.zst"
    local IMAGEBUILDER_DIR="openwrt-imagebuilder-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}.${IB_ARCH}"
    local BASE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}"

    log_info "Preparing OpenWrt ImageBuilder (arch: ${IB_ARCH})..."
    cd "${PROJECT_ROOT}" || die "Cannot cd to PROJECT_ROOT: ${PROJECT_ROOT}"

    if [ ! -d "${IMAGEBUILDER_DIR}" ]; then
        if [ "${DRY_RUN:-false}" = "true" ]; then
            log_info "[DRY-RUN] Would download, GPG-verify, and checksum ImageBuilder."
            log_info "[DRY-RUN]   Source: ${BASE_URL}/${IMAGEBUILDER_TAR}"
        else
            if [ ! -f "${IMAGEBUILDER_TAR}" ]; then
                log_info "Downloading OpenWrt ImageBuilder for ${IB_ARCH}..."
                wget "${BASE_URL}/${IMAGEBUILDER_TAR}"
            fi

            log_info "Verifying ImageBuilder checksum and signature..."
            wget "${BASE_URL}/sha256sums"     -O /tmp/openwrt-sha256sums
            wget "${BASE_URL}/sha256sums.asc" -O /tmp/openwrt-sha256sums.asc

            if ! gpg --verify /tmp/openwrt-sha256sums.asc /tmp/openwrt-sha256sums >/dev/null 2>&1; then
                log_warn "GPG signature verification failed."
                log_warn "See: https://openwrt.org/docs/guide-user/security/signatures"
                if ! prompt_confirm "Continue without GPG verification? (sha256 still checked)"; then
                    rm -f /tmp/openwrt-sha256sums /tmp/openwrt-sha256sums.asc
                    die "Aborted. Import the OpenWrt GPG key and retry."
                fi
            fi

            if ! grep "${IMAGEBUILDER_TAR}" /tmp/openwrt-sha256sums | sha256sum -c - >/dev/null 2>&1; then
                rm -f /tmp/openwrt-sha256sums /tmp/openwrt-sha256sums.asc
                die "ImageBuilder checksum verification FAILED!"
            fi
            rm -f /tmp/openwrt-sha256sums /tmp/openwrt-sha256sums.asc

            log_info "Extracting ImageBuilder..."
            tar -I zstd -xf "${IMAGEBUILDER_TAR}"
        fi
    fi

    log_info "Building custom OpenWrt rootfs..."
    cd "${IMAGEBUILDER_DIR}" || die "Cannot cd to ImageBuilder dir: ${IMAGEBUILDER_DIR}"

    # Install ImageBuilder host dependencies if missing
    if [ "${DRY_RUN:-false}" != "true" ]; then
        log_info "Ensuring ImageBuilder host dependencies are installed..."
        apt-get install -y -qq \
            build-essential libncurses5-dev libncursesw5-dev \
            zlib1g-dev gawk git gettext libssl-dev xsltproc \
            wget unzip python3 rsync 2>/dev/null || true
    fi

    exec_or_log make -j"$(nproc)" image PROFILE="generic" \
        PACKAGES="${OPENWRT_PACKAGES}" \
        FILES="${PROJECT_ROOT}/assets/openwrt_files"

    log_success "OpenWrt custom image built."
    log_info "Built images are in: $(pwd)/bin/targets/"
}
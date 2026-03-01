#!/bin/bash
# ==============================================================================
# MODULE: OPENWRT_BUILD
# ==============================================================================

build_openwrt_image() {
    local IMAGEBUILDER_TAR="openwrt-imagebuilder-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}.Linux-x86_64.tar.zst"
    local IMAGEBUILDER_DIR="openwrt-imagebuilder-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}.Linux-x86_64"

    log_info "Preparing OpenWrt ImageBuilder..."
    cd "${PROJECT_ROOT}" || die "Cannot cd to PROJECT_ROOT: ${PROJECT_ROOT}"

    if [ ! -d "${IMAGEBUILDER_DIR}" ]; then
        local BASE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}"

        if [ "${DRY_RUN:-false}" = "true" ]; then
            log_info "[DRY-RUN] Would download, GPG-verify, and checksum ImageBuilder."
            log_info "[DRY-RUN]   Source: ${BASE_URL}/${IMAGEBUILDER_TAR}"
        else
            [ ! -f "${IMAGEBUILDER_TAR}" ] && wget "${BASE_URL}/${IMAGEBUILDER_TAR}"

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

            tar -I zstd -xf "${IMAGEBUILDER_TAR}"
        fi
    fi

    log_info "Building custom OpenWrt rootfs..."
    cd "${IMAGEBUILDER_DIR}" || die "Cannot cd to ImageBuilder dir."

    # Detect if we are running on a non-x86-64 host (e.g. Raspberry Pi ARM64).
    # The ImageBuilder ships x86-64 host tools and cannot run natively on ARM.
    # We use a Docker x86-64 container with QEMU binfmt emulation as a workaround.
    local host_arch
    host_arch=$(uname -m)

    if [ "$host_arch" = "x86_64" ]; then
        # Native — run directly
        exec_or_log make -j"$(nproc)" image PROFILE="generic" \
            PACKAGES="${OPENWRT_PACKAGES}" \
            FILES="${PROJECT_ROOT}/assets/openwrt_files"
    else
        log_warn "Non-x86-64 host detected ($host_arch). Using Docker + QEMU emulation to run ImageBuilder..."

        # Register QEMU binfmt handlers so x86-64 binaries run under emulation
        if ! $DRY_RUN; then
            if ! docker run --rm --privileged multiarch/qemu-user-static --reset -p yes >/dev/null 2>&1; then
                die "Failed to register QEMU binfmt handlers. Is Docker installed and running?"
            fi
        fi

        # Run make inside an x86-64 Ubuntu container with the ImageBuilder dir mounted
        exec_or_log docker run --rm --platform linux/amd64 \
            -v "$(pwd):/build" \
            -w /build \
            ubuntu:22.04 \
            bash -c "
                apt-get update -qq && \
                apt-get install -y -qq make python3 libncurses5 zlib1g libssl-dev wget unzip && \
                make -j$(nproc) image PROFILE=generic \
                    PACKAGES='${OPENWRT_PACKAGES}' \
                    FILES='${PROJECT_ROOT}/assets/openwrt_files'
            "
    fi

    log_success "OpenWrt custom image built."
}
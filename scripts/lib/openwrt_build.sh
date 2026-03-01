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
    # We install qemu-user-static via apt and run the build inside a Docker
    # x86-64 container, which the kernel will transparently emulate via binfmt.
    local host_arch
    host_arch=$(uname -m)

    if [ "$host_arch" = "x86_64" ]; then
        # Native x86-64 — run make directly
        exec_or_log make -j"$(nproc)" image PROFILE="generic" \
            PACKAGES="${OPENWRT_PACKAGES}" \
            FILES="${PROJECT_ROOT}/assets/openwrt_files"
    else
        log_warn "Non-x86-64 host detected ($host_arch). Using Docker + QEMU to run ImageBuilder..."

        if [ "${DRY_RUN:-false}" != "true" ]; then
            # Step 1: install qemu-user-static so the kernel can run x86-64 binaries
            log_info "Installing qemu-user-static for x86-64 emulation..."
            apt-get install -y qemu-user-static

            # Step 2: verify binfmt_misc is mounted (required for transparent emulation)
            if ! mount | grep -q binfmt_misc; then
                log_info "Mounting binfmt_misc..."
                mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || true
            fi

            # Step 3: register x86-64 binfmt handler if not already registered
            if [ ! -f /proc/sys/fs/binfmt_misc/qemu-x86_64 ]; then
                log_info "Registering x86-64 binfmt handler..."
                update-binfmts --enable qemu-x86_64 2>/dev/null || \
                    log_warn "update-binfmts not available — emulation may rely on Docker's built-in support."
            fi
        fi

        # Step 4: locate the docker binary explicitly.
        # 'sudo' uses a restricted PATH that often excludes /usr/local/bin
        # where Docker is installed — so we search known locations directly.
        local DOCKER_BIN
        DOCKER_BIN=$(command -v docker 2>/dev/null \
            || ls /usr/local/bin/docker /usr/bin/docker 2>/dev/null | head -1 \
            || true)
        if [ -z "$DOCKER_BIN" ]; then
            die "Docker binary not found. Make sure Docker is installed and try: sudo $(realpath "$0")"
        fi
        log_info "Using Docker at: $DOCKER_BIN"

        # Step 5: run the build inside an x86-64 Docker container
        # Docker + qemu-user-static handles the emulation transparently
        exec_or_log "$DOCKER_BIN" run --rm --platform linux/amd64 \
            -v "${PROJECT_ROOT}:/project" \
            -v "$(pwd):/build" \
            -w /build \
            ubuntu:22.04 \
            bash -c "
                export DEBIAN_FRONTEND=noninteractive && \
                apt-get update -qq && \
                apt-get install -y -qq \
                    make python3 libncurses5 zlib1g libssl-dev \
                    wget unzip rsync gawk gettext xsltproc && \
                make -j$(nproc) image PROFILE=generic \
                    PACKAGES='${OPENWRT_PACKAGES}' \
                    FILES='/project/assets/openwrt_files'
            "

        log_info "Copying build output back to host..."
        # The built image lands in bin/targets inside the ImageBuilder dir
        log_info "Built images are in: $(pwd)/bin/targets/"
    fi

    log_success "OpenWrt custom image built."
}
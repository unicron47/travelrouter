#!/bin/bash
# ==============================================================================
# COVERT ROUTER: NAMESPACE TAKEOVER & LIFELINE ORCHESTRATOR
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "/opt/covert-router/logging.sh" ]; then
    source "/opt/covert-router/logging.sh"
elif [ -f "${PROJECT_ROOT}/scripts/lib/logging.sh" ]; then
    source "${PROJECT_ROOT}/scripts/lib/logging.sh"
else
    # NOTE: exec_or_log here duplicates logging.sh. Keep in sync if logging.sh changes.
    log_info()    { echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"; }
    log_warn()    { echo "$(date '+%Y-%m-%d %H:%M:%S') - [WARN] $1"; }
    die()         { echo "$(date '+%Y-%m-%d %H:%M:%S') - [FATAL] $1" >&2; exit 1; }
    exec_or_log() {
        if [ "${DRY_RUN:-false}" = "true" ]; then log_info "[DRY-RUN] Would execute: $*"
        else "$@"; fi
    }
fi

CONFIG_PATH=""
for cfg in "/opt/covert-router/config.env" "${PROJECT_ROOT}/config.env"; do
    [ -f "$cfg" ] && CONFIG_PATH="$cfg" && break
done

if [ -n "$CONFIG_PATH" ]; then
    config_perms=$(stat -c "%U %a" "$CONFIG_PATH")
    config_owner=$(echo "$config_perms" | cut -d' ' -f1)
    config_mode=$(echo "$config_perms" | cut -d' ' -f2)
    [ "$config_owner" != "root" ] && die "config.env must be owned by root. Owner: $config_owner"
    group_w=$(( (8#$config_mode >> 3) & 2 ))
    other_w=$(( 8#$config_mode & 2 ))
    { [ "$group_w" -ne 0 ] || [ "$other_w" -ne 0 ]; } && die "config.env is group/world-writable. Run: chmod 600 ${CONFIG_PATH}"
    source "$CONFIG_PATH"
else
    log_warn "config.env not found. Using hardcoded fallback values — check /opt/covert-router/."
    HOST_LIFELINE_IP="192.168.10.254/24"
fi

CONTAINER_NAME="openwrt_router"
IMAGE_NAME="openwrt-24-stable"
INTERFACES=("eth0" "wlan0" "wlan1")
DRY_RUN=false
ACTION="start"

return_interfaces_to_host() {
    log_info "Returning interfaces to host PID 1..."
    local cpid
    cpid=$(docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null || echo "0")
    if [ "$cpid" != "0" ]; then
        for iface in "${INTERFACES[@]}"; do
            if nsenter -t "$cpid" -n ip link show "$iface" >/dev/null 2>&1; then
                log_info "Returning $iface..."
                exec_or_log nsenter -t "$cpid" -n ip link set "$iface" netns 1 || true
            fi
        done
        exec_or_log docker stop -t 5 "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    exec_or_log ip link delete veth_host >/dev/null 2>&1 || true
    exec_or_log systemctl start NetworkManager wpa_supplicant systemd-networkd >/dev/null 2>&1 || true
    log_info "Host interfaces restored."
}

start_and_inject() {
    log_info "Ensuring container $CONTAINER_NAME is running..."
    if [ -z "$(docker ps -q -f name="^/${CONTAINER_NAME}$")" ]; then
        if [ -n "$(docker ps -aq -f status=exited -f name="^/${CONTAINER_NAME}$")" ]; then
            exec_or_log docker start "$CONTAINER_NAME"
        else
            exec_or_log docker run -d --name "$CONTAINER_NAME" --restart always --privileged                 --network none "$IMAGE_NAME" /sbin/init
        fi
    fi

    local cpid=0
    if $DRY_RUN; then
        log_info "[DRY-RUN] Skipping PID wait."; cpid=99999
    else
        local retries=0
        while [ "$cpid" -eq 0 ] && [ $retries -lt 30 ]; do
            cpid=$(docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null || echo 0)
            [ "$cpid" -eq 0 ] && { sleep 1; retries=$((retries+1)); }
        done
        [ "$cpid" -eq 0 ] && die "Failed to get container PID after 30s."
    fi

    log_info "PID $cpid — injecting interfaces..."
    for iface in "${INTERFACES[@]}"; do
        if ip link show "$iface" >/dev/null 2>&1; then
            exec_or_log ip link set "$iface" down
            exec_or_log ip link set "$iface" netns "$cpid"
        else
            log_info "Warning: $iface not on host — may already be injected."
        fi
    done

    exec_or_log ip link delete veth_host >/dev/null 2>&1 || true
    exec_or_log ip link add veth_host type veth peer name veth_router
    exec_or_log ip addr add "$HOST_LIFELINE_IP" dev veth_host || true
    exec_or_log ip link set veth_host up
    exec_or_log ip link set veth_router netns "$cpid"

    if command -v resolvconf >/dev/null 2>&1; then
        echo "nameserver 1.1.1.1" | resolvconf -a lo.ts
    else
        echo "nameserver 1.1.1.1" > /etc/resolv.conf
    fi

    local bridge_ready=0 bridge_retries=0
    if $DRY_RUN; then
        log_info "[DRY-RUN] Skipping br-lan poll."; bridge_ready=1
    else
        while [ "$bridge_ready" -eq 0 ] && [ "$bridge_retries" -lt 30 ]; do
            docker exec "$CONTAINER_NAME" ip link show br-lan >/dev/null 2>&1                 && bridge_ready=1 || { sleep 1; bridge_retries=$((bridge_retries+1)); }
        done
    fi

    exec_or_log docker exec "$CONTAINER_NAME" ip link set veth_router up
    if [ "$bridge_ready" -eq 1 ]; then
        exec_or_log docker exec "$CONTAINER_NAME" ip link set veth_router master br-lan
    else
        log_warn "br-lan not found after 30s — using emergency direct IP."
        exec_or_log docker exec "$CONTAINER_NAME" ip addr add 192.168.10.1/24 dev veth_router || true
    fi

    exec_or_log docker exec "$CONTAINER_NAME" sh -c 'wifi detect > /etc/config/wireless'
    exec_or_log docker exec "$CONTAINER_NAME" /etc/init.d/network reload

    if $DRY_RUN; then
        log_info "[DRY-RUN] Skipping smoke test."
    else
        sleep 3
        if docker exec "$CONTAINER_NAME" ping -c2 -W3 1.1.1.1 >/dev/null 2>&1; then
            log_info "Smoke test PASSED."
        else
            log_warn "Smoke test FAILED — check upstream connection."
        fi
    fi
    log_info "Injection complete."
}

# ENTRY POINT
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true; log_info "DRY-RUN MODE ENABLED." ;;
    stop)      ACTION="stop" ;;
    *)         log_warn "Unknown argument: $arg" ;;
  esac
done

[ "$ACTION" == "stop" ] && { return_interfaces_to_host; exit 0; }

exec_or_log systemctl stop NetworkManager wpa_supplicant systemd-networkd >/dev/null 2>&1 || true
start_and_inject

log_info "Entering monitoring loop..."
fail_count=0
while true; do
    if [ -z "$(docker ps -q -f name="^/${CONTAINER_NAME}$")" ]; then
        log_warn "Container $CONTAINER_NAME stopped unexpectedly!"
        fail_count=$((fail_count+1))
        backoff=$((fail_count * 5)); [ "$backoff" -gt 60 ] && backoff=60
        log_info "Recovery in ${backoff}s (attempt ${fail_count})..."
        sleep "$backoff"
        if start_and_inject; then fail_count=0; log_info "Recovery successful."
        else log_warn "Recovery attempt ${fail_count} failed. Will retry."; fi
    fi
    sleep 10
done

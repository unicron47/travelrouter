#!/bin/bash
# ==============================================================================
# COVERT ROUTER: NAMESPACE TAKEOVER & LIFELINE ORCHESTRATOR
# ==============================================================================
# This script is executed by the covert-router.service systemd unit.
# ==============================================================================

set -euo pipefail

# Ensure we have absolute paths since systemd runs this
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source variables (LIFELINE_HOST_IP, etc.)
if [ -f "${PROJECT_ROOT}/config.env" ]; then
    source "${PROJECT_ROOT}/config.env"
else
    LIFELINE_HOST_IP="192.168.10.254/24"
fi

CONTAINER_NAME="openwrt_router"
IMAGE_NAME="openwrt-24-stable"
INTERFACES=("eth0" "wlan0" "wlan1")

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

return_interfaces_to_host() {
    log "Initiating return of interfaces to host PID 1..."
    
    # We must find the container PID to reach into its namespace
    local cpid
    cpid=$(docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null || echo "0")
    
    if [ "$cpid" != "0" ]; then
        for iface in "${INTERFACES[@]}"; do
            # We use nsenter to jump into the container's network namespace, 
            # find the interface, and push it back to the host (PID 1)
            if nsenter -t "$cpid" -n ip link show "$iface" >/dev/null 2>&1; then
                log "Returning $iface to host..."
                nsenter -t "$cpid" -n ip link set "$iface" netns 1 || true
            fi
        done
        
        log "Stopping container gracefully..."
        docker stop -t 5 "$CONTAINER_NAME" >/dev/null 2>&1 || true
    else
        log "Container PID not found. Interfaces may already be on the host or container is dead."
        # Fallback: if container is dead but namespace somehow lingered, 
        # restarting docker or the pi is the only true fix, but usually docker cleans up.
    fi

    # Cleanup lifeline veth from host side
    ip link delete veth_host >/dev/null 2>&1 || true

    log "Restarting Host Network Managers to regain connectivity..."
    systemctl start NetworkManager wpa_supplicant systemd-networkd >/dev/null 2>&1 || true
    log "Host interfaces should now be restored."
}

start_and_inject() {
    log "Ensuring container $CONTAINER_NAME is running..."
    
    if ! docker ps -q -f name="^/${CONTAINER_NAME}$" >/dev/null; then
        if docker ps -aq -f status=exited -f name="^/${CONTAINER_NAME}$" >/dev/null; then
            log "Container exists but is stopped. Starting it..."
            docker start "$CONTAINER_NAME"
        else
            log "Container does not exist. Launching new instance..."
            docker run -d --name "$CONTAINER_NAME" --restart always --privileged \
                --network none \
                "$IMAGE_NAME" /sbin/init
        fi
    fi

    # Wait for the container to actually register a PID
    local cpid=0
    local retries=0
    while [ "$cpid" -eq 0 ] && [ $retries -lt 30 ]; do
        cpid=$(docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null || echo 0)
        if [ "$cpid" -eq 0 ]; then
            sleep 1
            retries=$((retries+1))
        fi
    done

    if [ "$cpid" -eq 0 ]; then
        log "FATAL: Failed to get PID for container $CONTAINER_NAME."
        exit 1
    fi
    
    log "Container PID is $cpid. Injecting interfaces..."

    # Inject Physical Interfaces
    for iface in "${INTERFACES[@]}"; do
        if ip link show "$iface" >/dev/null 2>&1; then
            log "Injecting $iface into OpenWrt namespace..."
            ip link set "$iface" down
            ip link set "$iface" netns "$cpid"
        else
            log "Warning: $iface not found on host. It may already be injected."
        fi
    done

    # Create the VETH Lifeline
    log "Establishing VETH Lifeline..."
    ip link delete veth_host >/dev/null 2>&1 || true
    ip link add veth_host type veth peer name veth_router
    
    # Configure Host side
    ip addr add "$LIFELINE_HOST_IP" dev veth_host || true
    ip link set veth_host up
    
    # Inject Router side
    ip link set veth_router netns "$cpid"
    
    # Provide Host with DNS resolution so Tailscale can connect
    log "Configuring Host DNS via OpenWrt..."
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    
    # Wait for OpenWrt to settle, then bridge veth_router into the LAN
    log "Waiting for OpenWrt to initialize before bridging veth_router..."
    
    # Robust polling: wait up to 30 seconds for br-lan to appear
    local bridge_ready=0
    local bridge_retries=0
    while [ "$bridge_ready" -eq 0 ] && [ $bridge_retries -lt 30 ]; do
        if docker exec "$CONTAINER_NAME" ip link show br-lan >/dev/null 2>&1; then
            bridge_ready=1
        else
            sleep 1
            bridge_retries=$((bridge_retries+1))
        fi
    done
    
    # Tell OpenWrt to bring the interface up
    docker exec "$CONTAINER_NAME" ip link set veth_router up
    
    if [ "$bridge_ready" -eq 1 ]; then
        log "Attaching veth_router to existing br-lan..."
        docker exec "$CONTAINER_NAME" ip link set veth_router master br-lan
    else
        log "br-lan not found after 30 seconds. Setting veth_router IP directly for emergency access..."
        docker exec "$CONTAINER_NAME" ip addr add 192.168.10.1/24 dev veth_router || true
    fi

    # Trigger OpenWrt to detect the newly injected wlan0 and wlan1 radios
    log "Generating OpenWrt Wireless configuration..."
    docker exec "$CONTAINER_NAME" sh -c 'wifi detect > /etc/config/wireless'
    # Reload network to apply
    docker exec "$CONTAINER_NAME" /etc/init.d/network reload
    
    log "Injection complete."
}

# ==============================================================================
# ENTRY POINT
# ==============================================================================

if [ "${1:-}" == "stop" ]; then
    log "Received STOP signal. Returning interfaces and shutting down."
    return_interfaces_to_host
    exit 0
fi

# Make sure host network managers are disabled before we start stealing interfaces
log "Disabling host network managers to prevent conflicts..."
systemctl stop NetworkManager wpa_supplicant systemd-networkd >/dev/null 2>&1 || true

start_and_inject

# Time-based continuous monitoring loop
log "Entering monitoring loop. Checking container health every 10 seconds..."
while true; do
    if ! docker ps -q -f name="^/${CONTAINER_NAME}$" >/dev/null; then
        log "WARNING: Container $CONTAINER_NAME crashed or stopped unexpectedly!"
        log "Attempting recovery..."
        start_and_inject
    fi
    sleep 10
done

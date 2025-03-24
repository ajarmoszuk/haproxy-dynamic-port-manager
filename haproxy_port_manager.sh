#!/bin/bash

START_PORT=25566
END_PORT=45566
PRIVATE_IP=127.0.0.1
CONFIG_FILE="/etc/haproxy/haproxy.cfg"
TMP_CONFIG="/tmp/haproxy.cfg.tmp"
CHECK_INTERVAL_NEW=10    # Check for new ports every 10 seconds
CHECK_INTERVAL_ACTIVE=60  # Re-check active ports every 60 seconds

declare -A ACTIVE_PORTS
declare -A LAST_CHECKED

log_debug() {
    echo "🔎 DEBUG: $1"
}

generate_config() {
    log_debug "Generating HAProxy configuration..."
    echo "global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private
    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-bind-options no-sslv3

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http
" > "$TMP_CONFIG"

    for port in "${!ACTIVE_PORTS[@]}"; do
        echo "frontend port_frontend_$port
    mode tcp
    option tcplog
    bind *:$port transparent
    default_backend port_backend_$port

backend port_backend_$port
    mode tcp
    balance roundrobin
    server private_server_$port $PRIVATE_IP:$port check send-proxy
" >> "$TMP_CONFIG"
    done
}

reload_haproxy() {
    log_debug "Attempting to reload HAProxy..."
    cp "$TMP_CONFIG" "$CONFIG_FILE" && log_debug "Config copied successfully."

    # Validate before reload
    if haproxy -c -f "$CONFIG_FILE"; then
        log_debug "Config validation passed. Reloading HAProxy via systemctl..."
        if systemctl reload haproxy; then
            echo "✅ HAProxy reloaded via systemctl at $(date)."
        else
            log_debug "systemctl reload failed. Attempting direct haproxy reload..."
            haproxy -f "$CONFIG_FILE" -sf $(pidof haproxy) && echo "✅ HAProxy reloaded directly at $(date)."
        fi
    else
        echo "❌ HAProxy config validation failed at $(date)."
    fi
}

scan_ports_parallel() {
    log_debug "Starting parallel port scan..."
    local changed=0

    # 1) Run nmap on the port range
    #    -T4 is "aggressive" timing; adjust as you like
    #    --min-rate=10000 tries to send at least 10k packets/sec (may be overkill on some networks)
    local nmap_output
    nmap_output="$(nmap -p ${START_PORT}-${END_PORT} ${PRIVATE_IP} -T4 --min-rate 10000 2>/dev/null)"

    # 2) Parse nmap's output to find all open ports
    #    nmap usually won't list all closed ports individually; we'll store the open ones in a map
    declare -A open_ports=()
    while IFS= read -r line; do
        # Look for lines like: "37973/tcp open  unknown"
        if [[ "$line" =~ ([0-9]+)/tcp[[:space:]]+open ]]; then
            port="${BASH_REMATCH[1]}"
            open_ports[$port]=1
        fi
    done <<< "$nmap_output"

    # 3) Compare the open_ports set to our ACTIVE_PORTS array
    for ((port=START_PORT; port<=END_PORT; port++)); do
        if [[ -n "${open_ports[$port]}" ]]; then
            # Port is open
            if [[ -z "${ACTIVE_PORTS[$port]}" ]]; then
                ACTIVE_PORTS[$port]=1
                LAST_CHECKED[$port]=$(date +%s)
                echo "🟢 Port $port became active!"
                changed=1
            fi
        else
            # Port is not open (or not listed)
            if [[ -n "${ACTIVE_PORTS[$port]}" ]]; then
                unset ACTIVE_PORTS[$port]
                unset LAST_CHECKED[$port]
                echo "🔴 Port $port is no longer active!"
                changed=1
            fi
        fi
    done

    # 4) Trigger a reload if we had any changes
    if ((changed == 1)); then
        log_debug "Changes detected. Triggering reload..."
        generate_config
        reload_haproxy
    else
        log_debug "No port changes detected."
    fi
}

echo "🚀 Starting Real-Time HAProxy Dynamic Port Manager..."
while true; do
    scan_ports_parallel
    sleep "$CHECK_INTERVAL_NEW"
done
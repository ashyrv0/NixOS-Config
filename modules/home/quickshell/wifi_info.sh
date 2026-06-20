#!/usr/bin/env bash
CACHE_DIR="/tmp/quickshell_network_cache"
mkdir -p "$CACHE_DIR"

get_icon() {
    local signal=$1
    if   [[ $signal -ge 80 ]]; then echo "󰤨"
    elif [[ $signal -ge 60 ]]; then echo "󰤥"
    elif [[ $signal -ge 40 ]]; then echo "󰤢"
    elif [[ $signal -ge 20 ]]; then echo "󰤟"
    else echo "󰤯"; fi
}

is_ethernet_connected() {
    local iface="$1"
    ip link show "$iface" 2>/dev/null | grep -q "UP"
}

# ── name-only mode (fast, for bar label) ──────────────────────────────────
if [[ "$1" == "name" ]]; then
    # Check ethernet first
    ETH_IFACE=$(nmcli -t -f DEVICE,TYPE d 2>/dev/null | awk -F: '$2=="ethernet"{print $1;exit}')
    if [[ -n "$ETH_IFACE" ]] && is_ethernet_connected "$ETH_IFACE"; then
        echo "Ethernet"
        exit 0
    fi
    
    POWER=$(nmcli radio wifi 2>/dev/null)
    if [[ "$POWER" != "enabled" ]]; then
        echo "Disconnected"
        exit 0
    fi
    SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2- | head -1)
    if [[ -z "$SSID" ]]; then
        echo "Disconnected"
    else
        echo "$SSID"
    fi
    exit 0
fi

# ── full JSON mode ─────────────────────────────────────────────────────────
POWER=$(nmcli radio wifi 2>/dev/null)
if [[ "$POWER" != "enabled" ]]; then
    echo '{"power":"off","connected":null,"networks":[]}'
    exit 0
fi

# Connected network
CURRENT_RAW=$(nmcli -t -f active,ssid,signal,security dev wifi 2>/dev/null | grep "^yes")
if [[ -n "$CURRENT_RAW" ]]; then
    # Use awk to safely split — avoids colon-in-SSID issues
    active=$(echo "$CURRENT_RAW" | awk -F: '{print $1}')
    ssid=$(echo "$CURRENT_RAW"   | awk -F: '{print $2}')
    signal=$(echo "$CURRENT_RAW" | awk -F: '{print $3}')
    security=$(echo "$CURRENT_RAW" | awk -F: '{print $4}')
    icon=$(get_icon "$signal")

    SAFE_SSID="${ssid//[^a-zA-Z0-9]/_}"
    CACHE_FILE="$CACHE_DIR/wifi_$SAFE_SSID"

    if [[ -f "$CACHE_FILE" ]]; then
        source "$CACHE_FILE"
    fi

    if [[ -z "$IP" || "$IP" == "No IP" || -z "$FREQ" ]]; then
        IFACE=$(nmcli -t -f DEVICE,TYPE d 2>/dev/null | awk -F: '$2=="wifi"{print $1;exit}')
        IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        [[ -z "$IP" ]] && IP="No IP"
        FREQ=$(iw dev "$IFACE" link 2>/dev/null | grep freq | awk '{print $2}')
        [[ -n "$FREQ" ]] && FREQ="${FREQ} MHz" || FREQ="Unknown"
        echo "IP=\"$IP\""   > "$CACHE_FILE"
        echo "FREQ=\"$FREQ\"" >> "$CACHE_FILE"
    fi

    CONNECTED_JSON=$(jq -n \
        --arg id       "$ssid"     \
        --arg ssid     "$ssid"     \
        --arg icon     "$icon"     \
        --arg signal   "$signal"   \
        --arg security "$security" \
        --arg ip       "$IP"       \
        --arg freq     "$FREQ"     \
        '{id:$id,ssid:$ssid,icon:$icon,signal:$signal,security:$security,ip:$ip,freq:$freq}')
else
    CONNECTED_JSON="null"
fi

# Available networks (no rescan so it's instant)
NETWORKS_JSON=$(nmcli -t -f active,ssid,signal,security dev wifi list --rescan no 2>/dev/null | \
    awk -F: '!seen[$2]++ && $2!="" && $1!="yes" {print $2":"$3":"$4}' | \
    head -n 20 | \
    while IFS=':' read -r ssid signal security; do
        icon=$(get_icon "$signal")
        jq -n \
            --arg id       "$ssid"     \
            --arg ssid     "$ssid"     \
            --arg icon     "$icon"     \
            --arg signal   "$signal"   \
            --arg security "$security" \
            '{id:$id,ssid:$ssid,icon:$icon,signal:$signal,security:$security}'
    done | jq -s '.')

jq -n \
    --arg power "on" \
    --argjson connected  "${CONNECTED_JSON:-null}" \
    --argjson networks   "${NETWORKS_JSON:-[]}" \
    '{power:$power,connected:$connected,networks:$networks}'

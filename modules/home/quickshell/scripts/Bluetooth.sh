#!/usr/bin/env bash
# Check if bluetoothctl is available
if ! command -v bluetoothctl &>/dev/null; then
    echo '{"powered":"unknown","devices":[]}'
    exit 0
fi

# Get power state
POWER=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')

# If Bluetooth is off, return early
if [[ "$POWER" != "yes" ]]; then
    echo '{"powered":"off","devices":[]}'
    exit 0
fi

# Get connected devices
CONNECTED=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')

# Get all paired devices with their names and connected status
DEVICES=$(bluetoothctl devices Paired 2>/dev/null | while read -r line; do
    MAC=$(echo "$line" | awk '{print $2}')
    NAME=$(echo "$line" | cut -d' ' -f3-)
    
    if echo "$CONNECTED" | grep -q "$MAC"; then
        STATE="connected"
    else
        STATE="disconnected"
    fi
    
    echo "{\"mac\":\"$MAC\",\"name\":\"$NAME\",\"state\":\"$STATE\"}"
done | jq -s '.')

# Output final JSON
jq -n \
    --arg power "$POWER" \
    --argjson devices "$DEVICES" \
    '{powered:$power,devices:$devices}'

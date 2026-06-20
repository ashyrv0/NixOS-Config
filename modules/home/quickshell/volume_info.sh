#!/usr/bin/env bash
vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
vol=$(echo "$vol_raw" | awk '{print int($2 * 100)}')

if echo "$vol_raw" | grep -q MUTED; then
    muted=true
else
    muted=false
fi

if [ "$muted" = true ] || [ "$vol" -eq 0 ]; then
    icon="󰝟"
elif [ "$vol" -ge 70 ]; then
    icon="󰕾"
elif [ "$vol" -ge 30 ]; then
    icon="󰖀"
else
    icon="󰕿"
fi

printf '{"vol":%d,"icon":"%s"}\n' "$vol" "$icon"
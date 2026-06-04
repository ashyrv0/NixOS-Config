#!/usr/bin/env bash
WALL_DIR="$HOME/.config/hypr/wallpapers"
THEME="$HOME/.config/rofi/wallpaper.rasi"

[ ! -d "$WALL_DIR" ] && exit 0

choice=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -print0 |
while IFS= read -r -d '' img; do
    name=$(basename "$img")
    printf "%s\0icon\x1f%s\n" "$name" "$img"
done | rofi -dmenu -show-icons -theme "$THEME" -p "Wallpaper" -i)

[ -z "$choice" ] && exit 0

SELECTED_WALL="$WALL_DIR/$choice"

# Generate wal colors
wal -i "$SELECTED_WALL" -n -q

# Set wallpaper
swww img "$SELECTED_WALL" --transition-type grow --transition-fps 60

# Reload Hyprland
hyprctl reload

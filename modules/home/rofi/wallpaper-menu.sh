#!/usr/bin/env bash
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="/run/current-system/sw/bin:/home/yurxi/.nix-profile/bin:$PATH"

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

matugen image "$SELECTED_WALL" -m dark --source-color-index 0
awww img "$SELECTED_WALL" --transition-type wave --transition-angle 30 --transition-wave "60,30" --transition-step 90 --transition-fps 60
hyprctl reload
sleep 0.5
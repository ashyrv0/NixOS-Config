{ config, pkgs, vars, ... }:
let
  wallpaper-menu = pkgs.writeShellScriptBin "wallpaper-menu" ''
    WALL_DIR="$HOME/.config/hypr/wallpapers"
    THEME="$HOME/.config/rofi/wallpaper.rasi"
    [ ! -d "$WALL_DIR" ] && exit 0
    choice=$(find "$WALL_DIR" -maxdepth 1 -follow -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -print0 | while IFS= read -r -d $'\0' img; do
      name=$(basename "$img")
      printf '%s\0icon\x1f%s\n' "$name" "$img"
    done | ${pkgs.rofi}/bin/rofi -dmenu -show-icons -theme "$THEME" -p "Wallpaper" -i)
    [ -z "$choice" ] && exit 0
    SELECTED_WALL="$WALL_DIR/$choice"
    ${pkgs.pywal}/bin/wal -i "$SELECTED_WALL" -n -q
    ${pkgs.awww}/bin/awww img "$SELECTED_WALL" --transition-type grow --transition-fps 60
    ${pkgs.hyprland}/bin/hyprctl reload
  '';
in
{
  home.packages = [ pkgs.rofi wallpaper-menu ];

  xdg.configFile."rofi/config.rasi".source = ./config.rasi;
  xdg.configFile."rofi/colors.rasi".source = ./colors.rasi;
  xdg.configFile."rofi/wallpaper.rasi".source = ./wallpaper.rasi;
  xdg.configFile."rofi/wallpaper-base.rasi".source = ./wallpaper-base.rasi;
}
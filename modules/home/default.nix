{ pkgs, inputs, vars, ... }:

let
  awww = inputs.awww;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    ./btop.nix
    ./cava.nix
    ./fastfetch.nix
    ./nvim.nix
    ./spicetify/spicetify.nix
    ./alacritty/alacritty.nix
    ./fish/config.nix
    ./rofi/default.nix
    ./quickshell/default.nix
    ./hypr/default.nix
  ];

  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";
  home.stateVersion = "26.05";
  home.enableNixpkgsReleaseCheck = false;

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    wl-clipboard
    libnotify
    dunst
    waybar
    hyprpaper
    awww.packages.${system}.awww
  ];
}
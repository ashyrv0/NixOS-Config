{ config, pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  quickshell = inputs.quickshell;
  awww = inputs.awww;
  nix-gaming = inputs.nix-gaming;
in
{
  environment.systemPackages =
    [
      quickshell.packages.${system}.default
      awww.packages.${system}.awww
      nix-gaming.packages.${system}.osu-lazer-bin
    ]
    ++ (with pkgs; [
      # Core system utilities
      bash
      git
      ripgrep
      fd
      jq
      tree-sitter

      # Networking and security
      proton-vpn
      librewolf
      brave

      # Media tools
      vlc
      yt-dlp
      playerctl

      # Wayland and Hyprland ecosystem
      hyprlock
      hypridle
      eww
      slurp
      grim
      rofi
      nwg-look

      # Terminal and shell
      alacritty
      fish
      starship
      btop

      # Development stack
      vscode
      rustc
      cargo
      nodejs
      qt6.qtwayland
      gcc
      gnumake
      pkg-config
      yazi
      
      # Graphics and rendering
      mesa
      mesa-demos
      libglvnd

      # Theming and icons
      papirus-icon-theme
      nordic
      pywal16
      
      # fun tools
      fastfetch
      cbonsai
      cmatrix
      cava
      peaclock

      # File management
      thunar
      unzip
    ]);
}
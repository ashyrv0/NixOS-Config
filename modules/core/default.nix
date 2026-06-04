{ inputs, host, ... }:
{
  imports = [
    ./bootloader.nix
    ./networking.nix
    ./services.nix
    ./system.nix
    ./fonts.nix
    ./packages.nix
    ./user.nix
    ./ly.nix
    ./hyprland.nix
  ];
}

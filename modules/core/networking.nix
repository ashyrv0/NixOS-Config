{ config, pkgs, ... }:
{
  networking.hostName = "lychee";
  networking.networkmanager.enable = true;
  networking.wireguard.enable = true;
}
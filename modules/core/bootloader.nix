{ config, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 30;
  
  boot.kernelPackages = pkgs.linuxPackages_latest;
}

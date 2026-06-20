{ config, pkgs, lib, ... }:

{ 
  xdg.configFile."rofi".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home/rofi/";
}
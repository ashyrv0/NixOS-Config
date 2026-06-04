{ config, pkgs, ... }:
{
  home.packages = [ pkgs.rofi ];

  xdg.configFile."quickshell" = {
    source = ./quickshell;
    recursive = true;
  };
}
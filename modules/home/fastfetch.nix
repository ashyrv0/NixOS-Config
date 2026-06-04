{ pkgs, ... }:
{
  programs.fastfetch.enable = true;
  programs.fastfetch.settings = {
    modules = [
      "title"
      "separator"
      "os"
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "wm"
      "terminal"
      "cpu"
      "gpu"
      "memory"
      "disk"
      "battery"
      "poweradapter"
      "break"
      "colors"
    ];
  };
}
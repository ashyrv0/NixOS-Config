{ ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      terminal.shell = {
        program = "/run/current-system/sw/bin/fish";
      };
      general = {
        import = [ "~/.cache/wal/colors-alacritty.toml" "fonts.toml" ];
        live_config_reload = true;
      };
      window = {
        decorations = "none";
        opacity = 0.9;
      };
      cursor = {
        blink_interval = 550;
        unfocused_hollow = false;
        thickness = 0.15;
        style = {
          blinking = "On";
          shape = "Beam";
        };
      };
    };
  };

  home.file.".config/alacritty/colors.toml".source = ./colors.nix;
  home.file.".config/alacritty/fonts.toml".source = ./fonts.nix;
}
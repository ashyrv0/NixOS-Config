{ config, pkgs, ... }:
{
  programs.fish.enable = true;
  programs.fish.interactiveShellInit = ''
    # Load pywal colors if available
    if test -f ~/.cache/wal/colors.fish
        source ~/.cache/wal/colors.fish
    end
    starship init fish | source

    set -Ux PATH $HOME/.local/bin $PATH

    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
  '';

  programs.fish.functions = {
    y = {
      description = "Yazi file manager with directory change";
      body = ''
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        command yazi $argv --cwd-file="$tmp"
        if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
          builtin cd -- "$cwd"
        end
        command rm -f -- "$tmp"
      '';
    };
  };

  home.packages = with pkgs; [
    starship
    yazi
  ];
}

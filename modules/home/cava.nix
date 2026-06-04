{ ... }:
{
  programs.cava.enable = true;

  home.file.".config/cava/config".text = ''
    [general]
    live-config = 1
    framerate = 90
    autosens = 1
    overshoot = 0
    sensitivity = 75

    [color]
    gradient = 1
    gradient_color_1 = '#445A74'
    gradient_color_2 = '#4E6378'
    gradient_color_3 = '#2c4060'
    gradient_color_4 = '#375E83'
    gradient_color_5 = '#466F8F'
    gradient_color_6 = '#5E7D9F'
    gradient_color_7 = '#6081A1'
    gradient_color_8 = '#698AAC'
    gradient_color_9 = '#7e8b97'
    gradient_color_10 = '#a0b2c8'

    [smoothing]
    monstercat = 0
    gravity = 100
  '';
}

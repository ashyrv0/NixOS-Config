{ vars, pkgs, ... }:
{
  users.users.${vars.username} = {
    isNormalUser = true;
    description = "Grace";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" ];
  };
}
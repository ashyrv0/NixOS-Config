{
  description = "Ash Nix configuration for NixOS";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    awww.url = "git+https://codeberg.org/LGFae/awww?ref=main";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    quickshell.url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-gaming.inputs.nixpkgs.follows = "nixpkgs";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { self, nixpkgs, spicetify-nix, awww, zen-browser, quickshell, nix-gaming, home-manager, ... } @ inputs:
  let
    lib = nixpkgs.lib;
    vars = import ./modules/core/vars.nix { inherit lib; };
  in
  {
    nixosConfigurations.${vars.hostname} = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs vars; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs vars; };
          home-manager.users.${vars.username} = {
            imports = [
              ./modules/home/default.nix
              spicetify-nix.homeManagerModules.default
            ];
          };
        }
      ];
    };
  };
}
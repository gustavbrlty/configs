{
  description = "Nixos config flake";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    pkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    mistral-vibe.url = "github:mistralai/mistral-vibe";
    mistral-vibe.inputs.nixpkgs.follows = "nixpkgs";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, pkgs-unstable, ... }@inputs: 
  let
    system = "x86_64-linux";
    pkgs-unstable-imported = import pkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations = {
      default = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit inputs;
          pkgs-unstable = pkgs-unstable-imported; 
        };

        modules = [
          ./OS.nix
          ./hardware/pc_HP.nix
	  inputs.sops-nix.nixosModules.sops
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            
            # 2. IMPORTANT : On doit passer 'inputs' à Home Manager aussi
            # pour que gustav.nix puisse voir 'inputs.nixpak'
            home-manager.extraSpecialArgs = { 
              inherit inputs; 
              pkgs-unstable = pkgs-unstable-imported;
            };
          }
        ];
      };
    };
  };
}

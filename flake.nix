{
  description = "Nixos config flake";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    pkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # --- Paquets épinglés individuellement ---
    # Un "paquet épinglé" est un paquet dont la version est gérée
    # indépendamment du reste du système, via son propre input nixpkgs.
    # Au lieu de partager l'input commun `pkgs-unstable` (où tout bouge
    # ensemble dès qu'on le met à jour), chaque paquet épinglé a son input
    # dédié, verrouillé à part dans flake.lock. On peut ainsi figer ou
    # mettre à jour ce paquet seul, sans impacter les autres.
    #
    # Chaque paquet ci-dessous a son propre input nixpkgs, verrouillé
    # séparément dans flake.lock. Cela permet de mettre à jour UN SEUL
    # paquet à la fois sans toucher aux autres :
    #
    #   nix flake update pin-opencode    # met à jour seulement opencode
    #   nix flake update pin-tailscale   # met à jour seulement tailscale
    #
    # Les URLs pointent vers la branche nixos-unstable. C'est le flake.lock
    # qui verrouille le commit exact de chaque input.
    #
    # POUR AJOUTER UN PAQUET ÉPINGLÉ :
    #   1. ajoutez sa ligne `pin-<nom>.url` ci-dessous ;
    #   2. ajoutez une entrée correspondante dans `pinnedSpecs` (plus bas).
    # Le reste (pinnedPkgs + menu sys-update) est généré automatiquement.
    pin-opencode.url  = "github:nixos/nixpkgs/nixos-unstable";
    pin-llamacpp.url  = "github:nixos/nixpkgs/nixos-unstable";
    pin-tailscale.url = "github:nixos/nixpkgs/nixos-unstable";
    pin-cursor.url    = "github:nixos/nixpkgs/nixos-unstable";
    pin-neovim.url    = "github:nixos/nixpkgs/nixos-unstable";

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
    lib = nixpkgs.lib;

    # Helper pour importer un input nixpkgs avec allowUnfree.
    mkPkgs = src: import src {
      inherit system;
      config.allowUnfree = true;
    };

    pkgs-unstable-imported = mkPkgs pkgs-unstable;

    # ============================================================
    #   SOURCE UNIQUE DE VÉRITÉ : paquets épinglés individuellement
    # ============================================================
    # Pour ajouter un paquet épinglé, il suffit de :
    #   1. ajouter la ligne `pin-<nom>.url` dans les `inputs` ci-dessus
    #      (obligatoire : Nix exige des inputs déclarés statiquement) ;
    #   2. ajouter une entrée dans cette liste `pinnedSpecs`.
    # Tout le reste (pinnedPkgs + menu de sys-update) est généré
    # automatiquement à partir de cette liste.
    #
    #   attr  : nom de l'attribut exposé dans `pinnedPkgs`
    #   input : clé de l'input flake correspondant
    #   pkg   : attribut à piocher dans le nixpkgs de l'input
    #           (null = on expose tout le pkgs importé, ex. pour cursor/neovim)
    #   desc  : description affichée dans le menu sys-update
    pinnedSpecs = [
      { attr = "opencode";    input = "pin-opencode";  pkg = "opencode";    desc = "opencode"; }
      { attr = "llama-cpp";   input = "pin-llamacpp";  pkg = "llama-cpp";   desc = "llama-cpp"; }
      { attr = "tailscale";   input = "pin-tailscale"; pkg = "tailscale";   desc = "tailscale"; }
      { attr = "cursor-pkgs"; input = "pin-cursor";    pkg = null;          desc = "code-cursor (Cursor)"; }
      { attr = "neovim-pkgs"; input = "pin-neovim";    pkg = null;          desc = "Toolchain Neovim / NvChad"; }
    ];

    # Génération automatique de pinnedPkgs depuis pinnedSpecs.
    pinnedPkgs = lib.listToAttrs (map (spec:
      lib.nameValuePair spec.attr (
        let imported = mkPkgs inputs.${spec.input};
        in if spec.pkg == null then imported else imported.${spec.pkg}
      )
    ) pinnedSpecs);

    # Inputs "globaux" sélectionnables dans sys-update (non épinglés par paquet).
    #   key  : clé de l'input flake
    #   desc : description affichée dans le menu
    globalInputs = [
      { key = "nixpkgs";       desc = "Paquets stables (nixos-26.05)"; }
      { key = "pkgs-unstable"; desc = "Paquets unstable partagés (reste du système)"; }
      { key = "home-manager";  desc = "home-manager"; }
      { key = "nixpak";        desc = "nixpak"; }
      { key = "sops-nix";      desc = "sops-nix"; }
    ];

    # Liste finale (clé, desc) injectée dans le menu de sys-update.
    # = inputs globaux + inputs des paquets épinglés.
    sysUpdateInputs = globalInputs
      ++ (map (spec: { key = spec.input; desc = spec.desc; }) pinnedSpecs);

    sys-update = import ./pkgs/scripts/sys-update.nix {
      pkgs = mkPkgs nixpkgs;
      selectableInputs = sysUpdateInputs;
    };
  in {
    nixosConfigurations = {
      default = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit inputs pinnedPkgs sys-update;
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
              inherit inputs pinnedPkgs sys-update; 
              pkgs-unstable = pkgs-unstable-imported;
            };
          }
        ];
      };
    };
  };
}

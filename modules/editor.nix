{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

with lib;

let

  cfg = config.programs.editor;

  # Liste des dépendances pour NvChad.
  nvchadDependencies = with pkgs-unstable; [

    neovim
    # git # on a dit de prendre la version pkgs stable dans gustav.nix
    gcc           # Requis par Treesitter.
    gnumake
    unzip
    wget
    curl
    ripgrep       # Requis par Telescope.
    fd
    xclip         # Presse-papier X11.
    
    # Fonts & LSP
    nerd-fonts.dejavu-sans-mono
    rustc
    cargo
    lldb          # Le débogueur (requis pour debugger dans Neovim).
    rust-analyzer # Le serveur de langage (plus stable via Nix que Mason).

    # Pour ne pas avoir de warning Lua (indispensable pour configurer NvChad).
    lua-language-server
    
    # Pour ne pas avoir de warnings HTML et CSS (tout est dans ce paquet unique).
    vscode-langservers-extracted

  ];

  # On importe Cursor sous Bubblewrap (NixPak).
  sandboxed-cursor = import ../pkgs/unfree/cursor.nix {
    inherit pkgs pkgs-unstable inputs;
  };

in

{
  options.programs.editor = {
    enable = mkEnableOption "Outils d'édition (NvChad, Cursor).";
  };

  config = mkIf cfg.enable {
    
    home.packages = nvchadDependencies ++ [ 
      sandboxed-cursor.config.env  # Cursor.
    ];

    # Variables pour définir Neovim comme éditeur par défaut
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # Alias pratique pour l'installation initiale de NvChad.
    home.shellAliases = {
      install-nvchad = "git clone https://github.com/NvChad/starter ~/.config/nvim && nvim";
    };
  };
}

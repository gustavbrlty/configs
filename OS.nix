# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      hardware/common.nix
      hardware/pc_HP.nix
      modules/network.nix
      inputs.home-manager.nixosModules.default
    ];

  # --- CONFIGURATION SOPS ---
  sops.defaultSopsFile = ./secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  # La clé privée utilisée pour déchiffrer au boot (celle de l'hôte)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Définition des secrets
  sops.secrets.partage_de_connexion = { };
  sops.secrets."V.Sardou" = { };
  sops.secrets.Flandrin = { };
  sops.secrets.Blonville = { };
  sops.secrets.espace_perso_EPITA = { };
  
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n.defaultLocale = "fr_FR.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  security.polkit.enable = true; 

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.autorun = false;
  services.xserver.exportConfiguration = true;

  services.dbus.enable = true;
  services.gnome.glib-networking.enable = true;

  services.xserver.displayManager.startx.enable = true;

  # Active le démon Udisks2 pour la gestion des périphériques de stockage
  services.udisks2.enable = true;

  # Active GVFS pour permettre aux gestionnaires de fichiers (comme Thunar ou PCManFM) de monter les disques
  services.gvfs.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  nixpkgs.config.allowUnfree = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Liste optionnelle : en général la liste par défaut suffit,
    # mais si un LSP spécifique plante, c'est ici qu'on ajoute les libs manquantes.
  ];

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.gustav = {
    isNormalUser = true;
    description = "Gustav";
    extraGroups = [ 
      "wheel" 
      "video" 
      "input" 
      "plugdev"
      "audio"
      "pipewire"
      "lp"
      "scanner"
    ];
  };

  users.groups.plugdev = {}; 
  # Création explicite du groupe plugdev avec GID fixe
  users.groups.plugdev = {
    gid = 984;  # Utilise le même GID que celui affiché
  };

  # Configuration PCSCD renforcée
  services.pcscd = {
    enable = true;
  };

  services.udev = {
    enable = true;
    packages = with pkgs; [ 
      yubikey-personalization 
      libu2f-host 
      libfido2
    ];
  };

  # Agent GnuPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
  };

  services.getty.autologinUser = "gustav";

  home-manager = {
      extraSpecialArgs = {
        inherit inputs;
      };
      users = {
        "gustav" = import ./gustav.nix;
      };
  };

  # Virtualisation
  boot.kernelModules = [ "kvm" "kvm-intel" ];
  virtualisation.libvirtd.enable = true;
  users.groups.libvirtd.members = ["gustav"];
  programs.dconf.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  services.tailscale.enable = true;

  # Packages système
  environment.systemPackages = with pkgs; [

    tree

    # necessaire pour polkit
    bitwarden-desktop

    /* Packages YubiKey complets
    yubikey-manager
    yubikey-personalization
    yubico-piv-tool
    opensc
    pcsclite
    pcsc-tools
    usbutils
    */
  ];

  services.gpm.enable = true;

  # Gemini says to absolutely not edit this.
  # because he says that it corresponds
  # to the NixOS version that was first installed
  # on this computer (see also home.stateVersion).
  system.stateVersion = "25.05";
}

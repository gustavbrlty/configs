# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, pkgs-unstable, pinnedPkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      hardware/common.nix
      hardware/pc_HP.nix
      modules/network.nix
      modules/AP.nix
      modules/virtualization.nix
      modules/password_manager.nix
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
  sops.secrets."La Permanence" = { };
  sops.secrets."Neutralivie" = { };
  sops.secrets."Grand Riviera Suite" = { };
  sops.secrets."30 Second Coffee Shop - Manille" = { };
  sops.secrets."ap-psk" = {
    mode = "0400";
    restartUnits = [ "accesspoint.service" ];
  };

  # ==========================================
  # 3. Configuration WebDAV (Davfs2) 
  # ==========================================
  sops.secrets.webdav = {
    owner = "root";    # Root doit posséder le fichier pour le montage système
    group = "root";
    mode = "0600"; 
  };

  services.davfs2.enable = true;

  # On lie le fichier de secrets attendu par davfs2 vers le fichier déchiffré par SOPS.
  environment.etc."davfs2/secrets".source = config.sops.secrets.webdav.path;
  # ==========================================
  
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Utilise le prompt LUKS classique (script bash) au lieu de l'initrd
  # systemd, qui affiche les caractères tapés / des astérisques lors du
  # déchiffrement et oblige à appuyer sur Tab pour les masquer.
  # Avec l'initrd classique, aucun caractère n'est affiché par défaut.
  boot.initrd.systemd.enable = false;

  # Pour pouvoir monter facilement certains disques durs externes
  boot.supportedFilesystems = [ "apfs" ];

  systemd.tmpfiles.rules = [
    "d /etc/nixos 0775 gustav users -"
  ];
  
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

  # security.polkit.enable = true;

  # Permettre à gustav d'exécuter xinit sans mot de passe (pour start-my-x automatique)
  security.sudo.extraRules = [
    {
      users = [ "gustav" ];
      commands = [
        {
          command = "${pkgs.xinit}/bin/xinit";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

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
  services.printing.drivers = [ pkgs.gutenprint ];

  # Découverte des imprimantes réseau (mDNS/DNS-SD)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

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
      "davfs2"
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

  # Active slock avec le wrapper setuid nécessaire (corrige l'erreur OOM killer)
  programs.slock.enable = true;

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

  nixpkgs.overlays = [ # temporary, to use the relative new Mullvad feature.
    (self: super: {
      tailscale = pinnedPkgs.tailscale;
    })
  ];
  services.tailscale.enable = true;

  # Packages système
  environment.systemPackages = with pkgs; [

    tree

    # necessaire pour polkit
    # bitwarden-desktop

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
  services.blueman.enable = true;

  # Gemini says to absolutely not edit this.
  # because he says that it corresponds
  # to the NixOS version that was first installed
  # on this computer (see also home.stateVersion).
  system.stateVersion = "25.05";
}

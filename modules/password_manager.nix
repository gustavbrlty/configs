{ config, pkgs, ... }:

let
  # --- Variables pour la configuration du Cloud ---
  user = "gustav";
  mountPoint = "/mnt/keepass";
  davUrl = "https://c.tail4868dc.ts.net:8443/keepass/"; # The password manager cloud URL.

in {
  # ==========================================
  # 1. Logiciels
  # ==========================================
  environment.systemPackages = with pkgs; [
    killall
    keepassxc          # Le gestionnaire de mots de passe
    
    # Outils optionnels pour YubiKey 
    yubikey-manager    # CLI (ykman)
    yubioath-flutter   # GUI (Yubico Authenticator)
  ];

  home-manager.users.${user} = {
    # On assigne directement le script (string) au lieu d'un objet complexe.
    home.activation.setupKeepassConfig = ''
      CONFIG_DIR="/home/${user}/.config/keepassxc"
      CONFIG_FILE="$CONFIG_DIR/keepassxc.ini"
      
      # Si le fichier n'existe pas, on le met en place
      if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p "$CONFIG_DIR"
        cp ${../.config/keepassxc.ini} "$CONFIG_FILE"
        chmod 644 "$CONFIG_FILE"
      fi
    '';
  };

  # ==========================================
  # 4. Montage du disque (pour le WebDAV)
  # ==========================================
  
  # Création du dossier de montage avec les bonnes permissions
  systemd.tmpfiles.rules = [
    "d ${mountPoint} 0750 ${user} users -"
  ];

  # Définition du système de fichiers
  fileSystems."${mountPoint}" = {
    device = davUrl;
    fsType = "davfs";
    options = [ 
      "rw" 
      "uid=${user}"    # L'utilisateur devient propriétaire des fichiers montés
      "gid=users" 
      "_netdev"        # Attend que le réseau (Tailscale) soit prêt
      "auto"           # Monte au démarrage
      "x-systemd.automount" # Monte à la demande (évite de bloquer le boot)
    ];
  };
}

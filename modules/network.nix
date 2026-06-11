{ config, pkgs, lib, ... }: 

# On utilise NetworkManager (pas wpa_supplicant).
# NetworkManager est 'mieux' que wpa_supplicant (bien qu'il puisse paraitre
# plus complique a mettre en place) car il gere intelligement le Split-DNS
# par exemple: avec NetworkManager je peux utiliser la wifi d'EPITA, mais
# en utilisant wpa_supplicant ca ne marche pas car wpa_supplicant ne gere pas
# aussi bien le Split-DNS.
# NetworkManager peut etre utilise via cli avec : nmcli, nmtui, nm-applet,
# ou nm-connection-editor.

let

  # Cette fonction génère un attribut complet pour sops.templates
  # Arguments : 
  #   filename : le nom du fichier (sans .nmconnection)
  #   ssid     : le nom du réseau Wifi
  #   secret   : le placeholder SOPS (ex: config.sops.placeholder.mon_secret)
  #   priority : la priorité (ex: 1 ou 0)
  mkWifi = filename: ssid: secret: priority: {
    "${filename}.nmconnection" = {
      path = "/etc/NetworkManager/system-connections/${filename}.nmconnection";
      mode = "0600";
      content = ''
        [connection]
        id=${ssid}
        type=wifi
        autoconnect=true
        ${if priority > 0 then "autoconnect-priority=${toString priority}" else ""}

        [wifi]
        ssid=${ssid}
        mode=infrastructure

        [wifi-security]
        key-mgmt=wpa-psk
        psk=${secret}
      '';
    };
  };

in {

  networking.hostName = "pc";

  networking.networkmanager.enable = true;

  # Pour que NetworkManager puisse envoyer des DNS à resolved.
  networking.networkmanager.dns = "systemd-resolved";

  # Active systemd-resolved pour une gestion DNS moderne (Split-DNS)
  services.resolved.enable = true;

  # On fusionne (//) les résultats de la fonction pour chaque réseau.
  sops.templates = 
    # 1. Réseaux personnels (WPA-PSK) via la fonction
    (mkWifi "Partage de connexion" "Ani ben Hashem" config.sops.placeholder.partage_de_connexion 1) //
    (mkWifi "V.Sardou"             "Livebox-DA90"   config.sops.placeholder."V.Sardou"           0) //
    (mkWifi "Flandrin"             "Bbox-7E26F9C4"  config.sops.placeholder.Flandrin             0) //
    (mkWifi "Blonville"            "Karin"          config.sops.placeholder.Blonville            0) //

    # 2. Réseau EPITA (WPA-EAP) - Trop spécifique pour la fonction générique, on le laisse en manuel
    {
      "IONIS.nmconnection" = {
        path = "/etc/NetworkManager/system-connections/IONIS.nmconnection";
        mode = "0600";
        content = ''
          [connection]
          id=IONIS
          type=wifi
          autoconnect=true

          [wifi]
          ssid=IONIS
          mode=infrastructure

          [wifi-security]
          key-mgmt=wpa-eap

          [802-1x]
          eap=peap;
          identity=gustav.berloty@epita.fr
          phase2-auth=mschapv2
          password=${config.sops.placeholder.espace_perso_EPITA}
          # system-ca-certs=false # Si jamais le certificat de l'ecole devient auto-signe ou prive, il faudra decommente cette ligne.
        '';
      };
    };

  # 3. Définition des réseaux publics (Profils)
  networking.networkmanager.ensureProfiles.profiles = 

  let free_wifi = ssid: {
      connection = {
        id = ssid;
        type = "wifi";
      };
      wifi = {
        ssid = ssid; 
        mode = "infrastructure";

      };
    };
    
  in {

    "BnF Francois Mitterand"  = free_wifi "BNF"; 

    "BPI Bercy Lumiere (1)"  = free_wifi "WIFI-BPI"; 
    # "BPI Bercy Lumiere (2)"  = free_wifi1 "Lumiere_Visiteurs"; n'a pas marche (le 16/12). 

    "La Permanence" = free_wifi "La Permanence";
  };
}

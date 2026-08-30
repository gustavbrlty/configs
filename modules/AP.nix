# Ce fichier de configuration est pour partager la connexion internet de la machine avec d'autres.
# AP.nix — point d'accès Wi-Fi concurrent (client + AP sur la même carte Intel)
#
# Import :  imports = [ ./AP.nix ];   dans configuration.nix
# Secret  :  echo -n 'monmotdepasse' | sudo tee /etc/ap-psk && sudo chmod 600 /etc/ap-psk
# Usage   :  ap up | ap down | ap clients | ap status | ap log
#
# Contrainte matérielle : la carte n'accepte qu'un seul canal radio
# (#channels <= 1), donc l'AP se cale automatiquement sur le canal du
# réseau auquel wlp0s20f3 est déjà connecté. Il faut donc être connecté
# en client AVANT de lancer l'AP — c'est aussi ce qui rend l'émission
# légale en 5 GHz ici, via le flag IR-CONCURRENT du domaine SA.

{ config, lib, pkgs, ... }:

let
  # ------------------------------------------------------------------
  # Paramètres — c'est la seule section à éditer
  # ------------------------------------------------------------------
  wan     = "wlp0s20f3";          # interface cliente (sortie Internet)
  apIf    = "ap0";                # interface AP virtuelle (créée à la volée)
  apMac   = "02:11:22:33:44:55";  # MAC locale, doit différer de celle du client
  ssid    = "MonAP";
  # Secret sops : la valeur ne transite jamais par le store Nix.
  pskFile = config.sops.secrets."ap-psk".path;   # -> /run/secrets/ap-psk
  subnet  = "192.168.12";         # /24 ; la passerelle sera .1
  country = "SA";

  # ------------------------------------------------------------------
  # Préparation : création de l'interface + génération de hostapd.conf
  # ------------------------------------------------------------------
  apSetup = pkgs.writeShellApplication {
    name = "ap-setup";
    # shellcheck tourne au build dans un sandbox sans locale : sans ceci,
    # tout caractere non-ASCII fait planter l'affichage de ses diagnostics.
    derivationArgs.LC_ALL = "C.UTF-8";
    runtimeInputs = with pkgs; [ iw iproute2 gawk coreutils ];
    text = ''
      WAN=${wan}
      AP=${apIf}

      # Le canal de l'AP est imposé par le lien client : sans lien, pas d'AP.
      # iw affiche la frequence avec une decimale (ex: 5240.0) : int() la retire,
      # bash ne sachant faire ni comparaison ni division sur un flottant.
      FREQ=$(iw dev "$WAN" link | awk '/freq:/ {print int($2)}')
      if [ -z "$FREQ" ]; then
        echo "ERREUR : $WAN n'est connecté à aucun réseau." >&2
        echo "L'AP doit partager le canal du lien client (#channels <= 1)." >&2
        exit 1
      fi

      if [ "$FREQ" -ge 5000 ]; then
        CHAN=$(( (FREQ - 5000) / 5 )); HW=a
      else
        CHAN=$(( (FREQ - 2407) / 5 )); HW=g
      fi
      echo "Lien client sur $FREQ MHz -> AP sur le canal $CHAN (hw_mode=$HW)"

      # hostapd refuse tout canal marque "no IR" (interdiction d'emettre en
      # premier). Autant le dire ici clairement plutot que de laisser hostapd
      # sortir un "Hardware does not support configured channel" trompeur.
      if iw phy | grep -F "$FREQ.0 MHz" | grep -q "no IR"; then
        echo "ERREUR : canal $CHAN ($FREQ MHz) interdit a l'emission (no IR)." >&2
        echo "Reconnecter le lien client en 2.4 GHz :" >&2
        echo "  nmcli connection modify <SSID> wifi.band bg && nmcli connection up <SSID>" >&2
        exit 1
      fi

      if [ ! -r ${pskFile} ]; then
        echo "ERREUR : ${pskFile} introuvable ou illisible." >&2
        echo "  Verifier : sops decrypt --extract '[\"ap-psk\"]' secrets/ap.yaml" >&2
        exit 1
      fi
      PSK=$(tr -d '\n' < ${pskFile})
      if [ "''${#PSK}" -lt 8 ]; then
        echo "ERREUR : la passphrase WPA doit faire au moins 8 caractères." >&2
        exit 1
      fi

      # Interface AP : on repart toujours d'un état propre
      iw dev "$AP" del 2>/dev/null || true
      iw dev "$WAN" interface add "$AP" type __ap
      ip link set "$AP" address ${apMac}
      ip link set "$AP" up
      ip addr flush dev "$AP"
      ip addr add ${subnet}.1/24 dev "$AP"

      umask 077
      cat > /run/ap/hostapd.conf <<EOF
      interface=$AP
      driver=nl80211
      ssid=${ssid}
      hw_mode=$HW
      channel=$CHAN
      country_code=${country}
      ieee80211d=1
      ieee80211n=1
      wmm_enabled=1
      auth_algs=1
      wpa=2
      wpa_key_mgmt=WPA-PSK
      rsn_pairwise=CCMP
      wpa_passphrase=$PSK
      EOF
    '';
  };

  apTeardown = pkgs.writeShellApplication {
    name = "ap-teardown";
    derivationArgs.LC_ALL = "C.UTF-8";
    runtimeInputs = with pkgs; [ iw coreutils ];
    text = ''
      iw dev ${apIf} del 2>/dev/null || true
      rm -f /run/ap/hostapd.conf
    '';
  };

  # ------------------------------------------------------------------
  # CLI
  # ------------------------------------------------------------------
  apCtl = pkgs.writeShellApplication {
    name = "ap";
    derivationArgs.LC_ALL = "C.UTF-8";
    runtimeInputs = with pkgs; [ iw iproute2 gawk systemd coreutils ];
    text = ''
      AP=${apIf}
      LEASES=/run/ap-dnsmasq/leases

      need_root() {
        if [ "$(id -u)" -ne 0 ]; then exec sudo -- "$0" "$@"; fi
      }

      case "''${1:-}" in
        up)
          need_root "$@"
          systemctl start accesspoint.service || true
          # hostapd ne sait pas signaler son etat a systemd (pas de sd_notify)
          # et Type=exec considere le demarrage reussi des l'exec du binaire.
          # On laisse donc le temps a hostapd d'echouer avant de conclure.
          sleep 2
          if systemctl is-active --quiet accesspoint.service; then
            echo "AP '${ssid}' actif sur $AP (${subnet}.1)"
          else
            echo "Echec au demarrage :" >&2
            journalctl -u accesspoint.service -n 12 --no-pager -o cat >&2
            exit 1
          fi
          ;;

        down)
          need_root "$@"
          systemctl stop accesspoint.service
          echo "AP arrêté."
          ;;

        clients)
          # iw station dump exige CAP_NET_ADMIN, et le fichier de baux est en 0700.
          need_root "$@"
          if ! ip link show "$AP" >/dev/null 2>&1; then
            echo "L'AP n'est pas actif."; exit 1
          fi
          MACS=$(iw dev "$AP" station dump | awk '/^Station/ {print $2}')
          if [ -z "$MACS" ]; then echo "Aucun client connecté."; exit 0; fi
          printf '%-18s %-15s %-20s %s\n' "MAC" "IP" "NOM" "SIGNAL"
          for MAC in $MACS; do
            IP=$(awk -v m="$MAC" 'tolower($2)==tolower(m) {print $3}' "$LEASES" 2>/dev/null)
            NAME=$(awk -v m="$MAC" 'tolower($2)==tolower(m) {print $4}' "$LEASES" 2>/dev/null)
            SIG=$(iw dev "$AP" station get "$MAC" | awk '/signal:/ {print $2" dBm"; exit}')
            printf '%-18s %-15s %-20s %s\n' "$MAC" "''${IP:--}" "''${NAME:--}" "''${SIG:--}"
          done
          ;;

        status)
          systemctl status accesspoint.service --no-pager || true
          echo
          iw dev "$AP" info 2>/dev/null || echo "Interface $AP absente."
          ;;

        log)
          journalctl -u accesspoint.service -u ap-dnsmasq.service -f
          ;;

        *)
          echo "usage: ap {up|down|clients|status|log}" >&2
          exit 1
          ;;
      esac
    '';
  };

in {
  # NetworkManager doit ignorer ap0 : sinon il la reprend, la repasse en
  # type « managed » et lui colle une MAC aléatoire, ce qui viole la
  # combinaison d'interfaces autorisée par le pilote.
  networking.networkmanager.unmanaged = [ "interface-name:${apIf}" ];

  # DHCP (67) et DNS (53) doivent être joignables depuis les clients.
  networking.firewall.interfaces.${apIf} = {
    allowedUDPPorts = [ 53 67 ];
    allowedTCPPorts = [ 53 ];
  };

  # NAT + ip_forward. Reste chargé en permanence mais sans effet tant
  # qu'aucun paquet n'entre par ap0.
  networking.nat = {
    enable = true;
    externalInterface = wan;
    internalInterfaces = [ apIf ];
  };

  systemd.services.accesspoint = {
    description = "Point d'accès Wi-Fi (hostapd sur ${apIf})";
    wantedBy = [ ];                 # démarrage manuel uniquement
    after = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "exec";
      RuntimeDirectory = "ap";
      RuntimeDirectoryMode = "0700";
      ExecStartPre = lib.getExe apSetup;
      ExecStart = "${pkgs.hostapd}/bin/hostapd /run/ap/hostapd.conf";
      ExecStopPost = lib.getExe apTeardown;
      Restart = "no";
    };
  };

  systemd.services.ap-dnsmasq = {
    description = "DHCP/DNS pour ${apIf}";
    after = [ "accesspoint.service" ];
    bindsTo = [ "accesspoint.service" ];   # ne demarre pas si l'AP a echoue
    partOf = [ "accesspoint.service" ];    # suit les stop/restart
    wantedBy = [ "accesspoint.service" ];  # demarre avec l'AP
    serviceConfig = {
      Type = "exec";
      # Repertoire distinct de celui de accesspoint.service, qui est
      # supprime des que cette unite s'arrete.
      RuntimeDirectory = "ap-dnsmasq";
      RuntimeDirectoryMode = "0700";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.dnsmasq}/bin/dnsmasq"
        "--keep-in-foreground"
        "--interface=${apIf}"
        "--bind-interfaces"
        "--listen-address=${subnet}.1"
        "--no-hosts"
        "--no-resolv"
        "--server=1.1.1.1"
        "--server=9.9.9.9"
        "--dhcp-range=${subnet}.50,${subnet}.150,12h"
        "--dhcp-option=option:router,${subnet}.1"
        "--dhcp-option=option:dns-server,${subnet}.1"
        "--dhcp-leasefile=/run/ap-dnsmasq/leases"
      ];
      Restart = "on-failure";
    };
  };

  environment.systemPackages = [ apCtl pkgs.iw ];
}

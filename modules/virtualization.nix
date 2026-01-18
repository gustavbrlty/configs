{ config, pkgs, ... }:
{

  # PODMAN
  virtualisation.podman = {
    enable = true;

    # Optionnel : permet d'utiliser `docker` comme alias pour `podman`
    dockerCompat = true; 

    # Optionnel : active les mises à jour DNS automatiques pour les conteneurs
    defaultNetwork.settings.dns_enabled = true;
  };

  # Pour ne pas avoir l'erreur:
  # Error: OCI runtime error: crun: sd-bus call: Process org.freedesktop.systemd1 exited with status 1: Input/output. 
  virtualisation.containers.containersConf.settings = {
    engine = {
      cgroup_manager = "cgroupfs";
    };
  };

  # VIRT-MANAGER 
  # Active dconf au niveau système
  programs.dconf.enable = true;

  # Injecte la config virt-manager pour les sessions utilisateurs
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = ["qemu:///system"];
          uris = ["qemu:///system"];
        };
      };
    }
  ];
 
 # QEMU
  environment.systemPackages = with pkgs; [

    qemu
    virt-manager
    usbutils

    # 1. Script de DÉMARRAGE (Avec alerte SUDO + Info Exclusivité)
    (writeShellScriptBin "vm-start" ''
        DISK="''${1:-hdd.qcow2}"

        # Gestion des arguments
        if [ -f "$DISK" ]; then
            shift
        else
            DISK="hdd.qcow2"
        fi

        if [ ! -f "$DISK" ]; then
            echo "Erreur : Le disque '$DISK' est introuvable."
            exit 1
        fi

        # --- PANEL D'INFORMATIONS ---
        echo -e "\n\033[1;33m=== INFOS UTILES (USB) ===\033[0m"
        
        # SECTION 1 : USB
        echo -e "\n🔌 \033[1;32mPOUR L'USB :\033[0m"
        echo -e "   ℹ️  \033[1;36mNote : Accès exclusif (VM ou Hôte).\033[0m"

        # Vérification des droits root (Reformulé)
        if [ "$EUID" -ne 0 ]; then
            echo -e "   ⚠️  \033[1;31mATTENTION :\033[0m L'accès USB nécessite les droits root, il faut relancer avec : \033[1msudo vm-start\033[0m"
        fi

        echo -e "   1. Hôte : \033[1;32mlsusb\033[0m (trouver les IDs VEN:PROD, ex: 0951:1666) + \033[1;31mdémonter\033[0m la clé si elle a été monté."
        echo -e "   2. QEMU : \033[1;36mCtrl + Alt + 2\033[0m (Console)"
        echo -e "   3. Taper : \033[1mdevice_add usb-host,vendorid=0xVEN,productid=0xPROD\033[0m"
        echo -e "   4. Retour : \033[1;36mCtrl + Alt + 1\033[0m\n"
        echo -e "\033[1;33m==========================================\033[0m\n"

        echo "Démarrage..."

        ${pkgs.qemu}/bin/qemu-system-x86_64 \
          -enable-kvm \
          -cpu host \
          -m 8G \
          -smp 3 \
          -drive file="$DISK",format=qcow2,if=virtio \
          -vga virtio \
          -display gtk,gl=on \
          -device qemu-xhci \
          -device usb-tablet \
          "$@"
    '')

    # 2. Script d'INSTALLATION
    (writeShellScriptBin "vm-install" ''
        ISO="$1"
        DISK="''${2:-hdd.qcow2}"

        if [ -z "$ISO" ]; then
            echo "Usage: vm-install <iso> [disque]"
            exit 1
        fi

        if [ ! -f "$DISK" ]; then
            ${pkgs.qemu}/bin/qemu-img create -f qcow2 "$DISK" 50G
        fi

        ${pkgs.qemu}/bin/qemu-system-x86_64 \
          -enable-kvm \
          -cpu host \
          -m 8G \
          -smp 3 \
          -drive file="$DISK",format=qcow2,if=virtio \
          -vga virtio \
          -display gtk,gl=on \
          -device qemu-xhci \
          -device usb-tablet \
          -cdrom "$ISO"
    '')

    (writeShellScriptBin "qemu-system-x86_64-uefi" ''
        qemu-system-x86_64 \
          -bios ${pkgs.OVMF.fd}/FV/OVMF.fd \
          "$@"
    '')
  ];
}

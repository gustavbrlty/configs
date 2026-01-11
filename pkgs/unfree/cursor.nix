{ pkgs, pkgs-unstable, inputs }:

let
  mkNixPak = inputs.nixpak.lib.nixpak {
    inherit (pkgs) lib;
    inherit pkgs;
  };
in
mkNixPak {
  config = { sloth, ... }: {
    
    app.package = pkgs-unstable.code-cursor;
    flatpak.appId = "com.cursor.Cursor";
    
    # 1. Activation indispensable de DBus (Communication système)
    dbus.enable = true;
    dbus.policies = {
      "org.freedesktop.DBus" = "talk";
      "org.freedesktop.Notifications" = "talk";
      "org.freedesktop.secrets" = "talk"; # Pour le trousseau de clés (login GitHub)
    };

    bubblewrap = {
      network = true;
      bind.dev = [ "/dev/dri" ]; # GPU

      bind.ro = [
        "/nix/store"
        "/run/current-system/sw/share/X11/fonts"
        "/run/current-system/sw/share/icons"
        "/run/current-system/sw/share/themes"
        "/etc/fonts" # Parfois nécessaire pour la config des polices

        # Permet à Cursor de trouver bash, ls, grep, etc.
        "/run/current-system/sw/bin"
      ];

      bind.rw = [
        (sloth.env "XDG_RUNTIME_DIR")
        "/tmp/.X11-unix"
        "/dev/shm"
        
        # 2. Ajout critique : Le Cache (Shaders GPU, etc.)
        # Sans accès au cache, Electron affiche souvent des fenêtres noires/cassées
        (sloth.concat' sloth.homeDir "/.cache")

        # Configs et Données
        (sloth.concat' sloth.homeDir "/.config/Cursor")
        (sloth.concat' sloth.homeDir "/.cursor")
        (sloth.concat' sloth.homeDir "/.cursor-server")
        
        # Vos dossiers
        (sloth.concat' sloth.homeDir "/cursor") 
      ];
    };
  };
}

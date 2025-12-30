{ pkgs }:

let
  my-x-session = pkgs.writeShellApplication {
    name = "my-x-session";
    
    runtimeInputs = with pkgs; [ 
      dbus 
      gnome-keyring 
      polkit_gnome 
      libinput-gestures  # <--- RAJOUTÉ
      openbox 
      bash
      coreutils
    ];

    text = ''
      # 1. ACTIVATION DES LOGS
      exec > /tmp/xsession.log 2>&1
      
      echo ":: Démarrage de la session X..."
      date

      USER_ID="$(id -u)"
      export XDG_RUNTIME_DIR="/run/user/$USER_ID"
      echo ":: XDG_RUNTIME_DIR défini à $XDG_RUNTIME_DIR"

      # On nettoie les anciens agents s'ils trainent (optionnel mais propre)
      killall ssh-agent || true

      # On démarre l'agent SSH officiel du système
      # La commande 'eval' va exécuter les exports de variables (SSH_AUTH_SOCK, etc.)
      eval "$(ssh-agent -s)"

      # 2. Démarrage des services
      echo ":: Lancement de gnome-keyring..."
      # On retire 'ssh' des composants pour ne pas qu'il prenne la main
      eval "$(gnome-keyring-daemon --start --components=secrets)"

      # On fait un echo "" car la precedente commande
      # ne fait pas de retour a la ligne. 
      printf "\n"

      # echo ":: Lancement de Polkit..."
      # "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1" &
      
      echo ":: Lancement de libinput-gestures..."
      libinput-gestures & 

      if [ -x "/run/current-system/sw/libexec/dconf-service" ]; then
        "/run/current-system/sw/libexec/dconf-service" &
      fi

      # 3. Lancement de l'application optionnelle
      # Note: On utilise ''$ pour échapper le dollar pour Nix
      if [ -n "''${1:-}" ]; then
          echo ":: Lancement de l'application demandée : $1"
          "$1" &
      fi

      # 4. Lancement d'Openbox
      if [ ! -f "$HOME/.config/openbox/rc.xml" ]; then
          echo "!! ERREUR CRITIQUE : Fichier de config Openbox introuvable !"
          ls -la "$HOME/.config/openbox/"
          echo ":: Tentative de lancement Openbox sans config..."
          exec openbox
      else
          echo ":: Lancement d'Openbox avec config..."
          exec openbox --config-file "$HOME/.config/openbox/rc.xml"
      fi
    '';
  };

in
pkgs.writeShellApplication {
  name = "start-my-x";
  
  runtimeInputs = with pkgs; [ 
    xorg.xinit 
    my-x-session 
    dbus 
  ];

  text = ''
    APP_PATH=""
    
    if [ -n "''${1:-}" ]; then
        APP_PATH="$(command -v "$1")"
        if [ -z "$APP_PATH" ]; then
             echo "Application '$1' not found."
             exit 1
        fi
    fi

    # Lancement via xinit AVEC dbus-run-session
    sudo xinit /usr/bin/env bash -c "su $USER -c 'dbus-run-session ${my-x-session}/bin/my-x-session \"$APP_PATH\"'" -- :0 vt1
  '';
}

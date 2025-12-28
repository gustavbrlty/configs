
{ config, pkgs, pkgs-unstable, ... }:

let

  my-x-scripts = import pkgs/scripts/x-session.nix { inherit pkgs; };
  sys-update = import pkgs/scripts/sys-update.nix { inherit pkgs; };

  configs = "/etc/nixos/configs";

  # Fonction raccourci pour lier un dossier ou un fichier
  # %h sera remplacé par /home/gustav
  link = name: "L+ %h/.config/${name} - - - - ${configs}/${name}";

in {

  # We want the user to be able to use qemu.
  imports = [
    modules/virtualization.nix
    modules/editor.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "gustav";
  home.homeDirectory = "/home/gustav";


  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [ 

    # prmt # If I want to custom the shell prompt.

    # vscode

    # Regarding launching GUI from CLI, x11docker doesn't use the 
    # binary on the machine but use a new one at each new launch,
    # also since x11docker launch the application in a container,
    # the application may take more time to load, and to finish
    # it was tricky to try x11docker.

    # To be able to use GUI.
    pkgs.xorg.xinit
    pkgs.gnome-terminal
    pkgs.xorg.twm
    pkgs.openbox # Windows manager.
    # obconf not that useful.
    pkgs.libinput-gestures
    pkgs.sops

    pkgs-unstable.bitwarden-cli
    pkgs.gnome-keyring # pour bitwarden, pour ne plus avoir d'erreur dans les logs
    pkgs.polkit_gnome # pour le debloquage par biometrie.

    # Ajoutez ces deux lignes :
    pkgs.arandr      # Interface graphique pour gérer les écrans (HDMI)
    pkgs.autorandr   # (Optionnel) Pour sauvegarder/restaurer les profils

    pkgs.zotero

    my-x-scripts
    sys-update # Pour maj le systeme proprement.

    pkgs.libreoffice-fresh

    /*
    # Mes clés SSH sont stockées sur YubiKey.
    yubikey-manager
    yubikey-personalization
    yubico-piv-tool
    pcsc-tools
    opensc
    */
    
    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    pkgs.flameshot # To be able to take screenshots.
  
  ];

  # Mes configs.
  systemd.user.tmpfiles.rules = [

    # Ajouter le terminal.

    (link "nvim")

    # Ajouter firefox

  ];

  services.gnome-keyring.enable = true;

  # 2. Configuration de Firefox pour "voir" l'application Bitwarden
  # Cela permet de déverrouiller l'extension Firefox avec la biométrie/PIN de l'appli Desktop
  programs.firefox = {
    enable = true;
    
    # C'est cette ligne magique qui fait le lien
    # entre Firefox et Bitwarden. 
    nativeMessagingHosts = [ 
      pkgs.bitwarden-desktop 
    ];
  };

  # Création manuelle du fichier de config ~/.config/libinput-gestures.conf
  xdg.configFile."libinput-gestures.conf".text = ''
    # 3 doigts vers la DROITE -> Bureau suivant
    gesture swipe right 3 ${pkgs.xdotool}/bin/xdotool set_desktop --relative 1

    # 3 doigts vers la GAUCHE -> Bureau précédent
    gesture swipe left 3 ${pkgs.xdotool}/bin/xdotool set_desktop --relative -- -1
  '';
  # libinput-gestures est lance dans le fichier x-session.nix.

  programs.git = {
    enable = true;
    settings = {
      url."git@github-kylak:kylak".insteadOf = "git@github.com:kylak";
      url."git@github-gustavbrlty:gustavbrlty".insteadOf = "git@github.com:gustavbrlty";
      safe.directory = "/etc/nixos"; # To save the NixOS config.
    };
  };

  programs.editor.enable = true;

  programs.ssh.enable = true;
  programs.ssh.enableDefaultConfig = false;
  programs.ssh.matchBlocks = {
    "github-kylak" = {
      hostname = "github.com";
      user = "git";
      # identityFile = "~/.ssh/kylak_ssh";
      # identitiesOnly = true;
    };
    "github-gustavbrlty" = {
      hostname = "github.com";
      user = "git";
      # identityFile = "~/.ssh/id_rsa";
      # identitiesOnly = true;
    };
    "c" = {
      hostname = "c";
      user = "git";
      # identityFile = "~/.ssh/id_rsa";
      # identitiesOnly = true;
    };
  };

  /*
  # Configure SSH pour utiliser la clé PIV stockée sur la YubiKey.
  programs.ssh.extraConfig = ''
    PKCS11Provider ${pkgs.opensc}/lib/opensc-pkcs11.so
    '';
  */

  # Configuration bash complète avec traçage automatique des alias
  programs.bash = {
    enable = true;
    
    # Configuration de l'historique
    shellOptions = [
      "histappend"   # Append to history file
      "checkwinsize" # Check window size after each command
      "extglob"      # Extended pattern matching
      "globstar"     # Enable ** pattern
      "checkjobs"    # Check jobs before exit
    ];
    
    historyControl = [ "ignoreboth" ]; # Ignore duplicates and spaces
    historyFileSize = 2000;
    historySize = 1000;
    
    # Variables d'environnement
    sessionVariables = {
      HISTFILESIZE = "100000";
      HISTSIZE = "10000";
      PGDATA = "$HOME/postgres_data";
      PGHOST = "/tmp";
      PGPORT = "5432";
    };
    
    # Alias - ils seront automatiquement tracés
    shellAliases = {

      # Navigation
      ll = "ls -alhF";
      la = "ls -Ah";
      l = "ll";
      c = "cd";
      "c.." = "cd ..";
      clear = "clear_n_bottom";
      cl = "clear";
      clr = "clear";
      cll = "clear && ls";
      o = "open .";
      
      # Git
      "?" = "git status";
      ga = "git add";
      gc = "git commit -m";
      gp = "git push";
      gl = "git log";
      gs = "git switch";
      gd = "git diff";
      gb = "git branch -a";
      
      # Cargo
      cr="cargo run";
      cb="cargo build";
      ca="cargo add";
      ct="cargo test";
      cc="cargo check";
      
      # Applications
      j = "jobs";
      d = "date";
      ytm = "musique";
      mu = "musique";
      msq = "musique";
      music = "musique";
      m = "man";
      e="nvim";

      # If we want to check what 
      # is inside the .bashrc.
      bashrc="e ~/.bashrc";
      b="bashrc";

      # wifi
      # pour scanner les reseaux et se connecter
      # sur le reseau avec la plus haute priorite.
      wifi="wpa_cli reassociate"; 
      
      # Utilitaires
      s="source ~/.bashrc";
      rst="reset";
      f="find /home/gustav/ -name";
      reset="reset && clear";
      x="start-my-x";
      off="sudo shutdown now"; # todo: demander une confirmation
      update="sys-update";
      rebuild="sudo nixos-rebuild switch --flake /etc/nixos/#default && s";
      rb="rebuild";

      # We explictly put nvim instead of using the 'e' alias
      # since the 'e' alias could theorically not support
      # the vim syntax used here if 'e' is not a vim like editor.
      config="sudo nvim -p /etc/nixos/OS.nix /etc/nixos/gustav.nix -c \"tabnext 2\"";
      cnf="config";

      infos = "printf '\n**HEURE & DATE**:\n' && date && 
               printf '\n**BATTERIE**:\n' && acpi -b && 
               printf '\n**WIFI**:\n' && wpa_cli status | grep -E '^(ssid|wifi_generation|wpa_state|key_mgmt|ip_address)=' | awk -F= '{print $1 \"=\" $2}' &&
               printf '\n**HDD**:\n' && df -h / &&
               printf '\n**RAM**:\n' && free -h";
      i="infos";
    };

    # Configuration bash étendue avec traçage automatique des alias
    initExtra = ''
      __prompt_to_bottom_line() {
          tput cup $LINES
      }
      __prompt_to_bottom_line
      
      # Configuration du prompt
      # Prompt with the 'prmt' binary (this binary 
      # makes the prompt shell to be fast).
      # if command -v prmt >/dev/null 2>&1; then
       # PS1='Done.\n\n$(prmt "")'
      # else
       PS1='Done.\n\n'
      # fi

      clear_n_bottom() {
	command clear
	__prompt_to_bottom_line
      }

      # Configuration du prompt command
      update_branch() {
        BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      }
      update_terminal_title() {
        echo -ne "\033]0;''${PWD}''${BRANCH:+ on ''$BRANCH}\007"
      }
      PROMPT_COMMAND="update_branch; update_terminal_title"

      
      # Configuration des couleurs pour ls et grep
      if [ -x /usr/bin/dircolors ]; then
          test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
          alias ls='ls --color=auto'
          alias grep='grep --color=auto'
          alias fgrep='fgrep --color=auto'
          alias egrep='egrep --color=auto'
      fi
      
      # Ajout au PATH
      export PATH="$PATH:/home/gustav/.local/jdk-21.0.1+12/bin:/home/gustav/.local/ghidra_10.4_PUBLIC:/home/gustav/Bureau/ngl/target/debug/:/home/gustav/Téléchargements/ideaIU-2023.3.3/idea-IU-233.14015.106/bin/:/usr/lib/postgresql/16/bin/"
    '';
  };

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # To be able to launch GUI.

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';

    ".gnupg/scdaemon.conf".text = ''
      disable-ccid
    '';

    ".config/openbox/menu.xml" = {
      text = ''
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="Openbox 3">
    <item label="Firefox">
      <action name="Execute">
        <command>${pkgs.firefox}/bin/firefox</command>
      </action>
    </item>
    <item label="Terminal">
      <action name="Execute">
        <command>${pkgs.gnome-terminal}/bin/gnome-terminal</command>
      </action>
    </item>
    <item label="Cursor">
      <action name="Execute">
        <command>cursor</command>
      </action>
    </item>
    <separator/>
      <item label="Screenshot">
        <action name="Execute">
          <command>${pkgs.flameshot}/bin/flameshot gui</command>
        </action>
      </item>
    <separator/>
      <item label="Bitwarden">
        <action name="Execute">
          <command>${pkgs.bitwarden-desktop}/bin/bitwarden</command>
        </action>
      </item>
    <separator/>
    
    <!-- <menu id="multimedia-menu" label="Other">
      <item label="VLC">
        <action name="Execute">
          <command>${pkgs.vlc}/bin/vlc</command>
        </action>
      </item>
    </menu> -->

    <menu id="system-menu" label="System">
      <item label="Sortie audiovisuel">
        <action name="Execute">
          <command>${pkgs.arandr}/bin/arandr</command>
        </action>
      </item>
      <separator/>
      <item label="Reconfigure Openbox">
        <action name="Reconfigure"/>
      </item>
      <item label="Restart Openbox">
        <action name="Restart"/>
      </item>
      <separator/>
      <item label="Log Out">
        <action name="Exit">
          <prompt>yes</prompt>
        </action>
      </item>
    </menu>
  </menu>
</openbox_menu>
      '';
    };

    ".config/openbox/rc.xml" = {
    text = ''
  <?xml version="1.0" encoding="UTF-8"?>
  <openbox_config xmlns="http://openbox.org/3.4/rc">
    <resistance>
      <strength>10</strength>
      <screen_edge_strength>20</screen_edge_strength>
    </resistance>

    <focus>
      <focusNew>yes</focusNew>
      <followMouse>no</followMouse>
      <focusLast>yes</focusLast>
      <underMouse>no</underMouse>
      <focusDelay>200</focusDelay>
      <raiseOnFocus>yes</raiseOnFocus>
    </focus>

    <placement>
      <policy>Smart</policy>
      <center>yes</center>
      <monitor>Mouse</monitor>
      <primaryMonitor>1</primaryMonitor>
    </placement>

    <theme>
      <name>Clearlooks</name>
      <titleLayout>NLRC</titleLayout>
      <keepBorder>yes</keepBorder>
      <animateIconify>yes</animateIconify>
    </theme>

    <desktops>
      <number>4</number>
      <firstdesk>1</firstdesk>
      <popupTime>875</popupTime>
    </desktops>

    <menu>
      <file>menu.xml</file>
      <hideDelay>200</hideDelay>
      <middle>no</middle>
      <submenuShowDelay>100</submenuShowDelay>
      <submenuHideDelay>100</submenuHideDelay>
      <applicationIcons>yes</applicationIcons>
      <manageDesktops>yes</manageDesktops>
    </menu>

    <applications>
      <application class="qutebrowser">
        <decor>yes</decor>
      </application>
      <application class="firefox">
        <decor>no</decor>
      </application>
      <application class="Qemu-system-x86_64">
        <decor>no</decor>
      </application>
    </applications>

    <mouse>
      <context name="Root">
        <mousebind button="Right" action="Press">
          <action name="ShowMenu">
            <menu>root-menu</menu>
          </action>
        </mousebind>
      </context>

      <context name="Titlebar">
        <!-- MODIFICATION : Ajout de Focus et Raise avant le déplacement -->
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Move"/>
        </mousebind>
        <mousebind button="Left" action="DoubleClick">
          <action name="ToggleMaximize"/>
        </mousebind>
      </context>

      <context name="Close">
        <mousebind button="Left" action="Click">
          <action name="Close"/>
        </mousebind>
      </context>

      <context name="Maximize">
        <mousebind button="Left" action="Click">
          <action name="ToggleMaximize"/>
        </mousebind>
      </context>

      <context name="Frame">
        <!-- MODIFICATION : Ajout de Focus et Raise avant le déplacement avec Alt -->
        <mousebind button="A-Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="A-Left" action="Drag">
          <action name="Move"/>
        </mousebind>
        <mousebind button="A-Right" action="Drag">
          <action name="Resize"/>
        </mousebind>
      </context>

      <context name="Top">
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Resize"><edge>top</edge></action>
        </mousebind>
      </context>

      <context name="Bottom">
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Resize"><edge>bottom</edge></action>
        </mousebind>
      </context>

      <context name="Left">
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Resize"><edge>left</edge></action>
        </mousebind>
      </context>

      <context name="Right">
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Resize"><edge>right</edge></action>
        </mousebind>
      </context>

      <context name="TLCorner">
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Resize">
            <direction>top_left</direction>
          </action>
        </mousebind>
      </context>

      <context name="TRCorner">
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Resize">
            <direction>top_right</direction>
          </action>
        </mousebind>
      </context>

      <context name="BLCorner">
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Resize">
            <direction>bottom_left</direction>
          </action>
        </mousebind>
      </context>

      <context name="BRCorner">
        <mousebind button="Left" action="Press">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Left" action="Drag">
          <action name="Resize">
            <direction>bottom_right</direction>
          </action>
        </mousebind>
      </context>

      <context name="Client">
        <mousebind button="Left" action="Click">
          <action name="Focus"/>
          <action name="Raise"/>
        </mousebind>
        <mousebind button="Right" action="Click">
          <action name="Focus"/>
        </mousebind>
        <mousebind button="C-Right" action="Press">
          <action name="ShowMenu">
            <menu>client-menu</menu>
          </action>
        </mousebind>
      </context>
    </mouse>

    <keyboard>
      <keybind key="C-A-Left">
        <action name="GoToDesktop"><to>left</to></action>
      </keybind>
      <keybind key="C-A-Right">
        <action name="GoToDesktop"><to>right</to></action>
      </keybind>
      <keybind key="S-A-1">
        <action name="GoToDesktop"><to>1</to></action>
      </keybind>
      <keybind key="S-A-2">
        <action name="GoToDesktop"><to>2</to></action>
      </keybind>
      <keybind key="S-A-3">
        <action name="GoToDesktop"><to>3</to></action>
      </keybind>
      <keybind key="S-A-4">
        <action name="GoToDesktop"><to>4</to></action>
      </keybind>

      <keybind key="C-Escape">
        <action name="ShowMenu">
          <menu>root-menu</menu>
        </action>
      </keybind>
    </keyboard>
  </openbox_config>
    '';
    };
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/gustav/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.
}

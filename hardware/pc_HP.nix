{ config, lib, pkgs, modulesPath, ... }:

{
  # ###BLUETOOTH###
  hardware.bluetooth.enable = true; 

  # Managing the ###SOUND###
  # Remove the deprecated sound.enable line if it exists
  hardware.alsa.enablePersistence = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  
  # Configuration des modules noyau
  boot.extraModprobeConfig = ''
    options snd-hda-intel model=alc236-hp
  '';
  
  # Charger explicitement le module audio
  boot.kernelModules = [ "snd-hda-intel" ];
  
  # PipeWire avec résolution de conflit
  services.pipewire = {
    enable = lib.mkForce true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # NE PAS forcer de profil ici : cette carte (Realtek ALC236 / SOF) expose
    # deux profils HiFi exclusifs l'un de l'autre :
    #   "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)"  (enceintes internes)
    #   "HiFi (HDMI1, HDMI2, HDMI3, Headphones, Mic1, Mic2)" (prise jack)
    # L'ancienne règle qui forçait le profil "Speaker" avec auto-profile=false
    # supprimait complètement la sortie casque. WirePlumber bascule tout seul
    # entre les deux grâce à la détection du jack (auto-profile/auto-port par
    # défaut).
  };

  # To know the ###BATTERY### level (acpi -b)
  environment.systemPackages = with pkgs; [
    acpi
    alsa-utils

    # Contrôle de la luminosité de l'écran (intel_backlight)
    brightnessctl

    # Outils pour le Trackpad (Gestes)
    libinput-gestures
    wmctrl
    xdotool
  ];

  users.users.gustav = {
    group = "gustav";
  };

  users.groups.gustav = {};
}

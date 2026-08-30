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

    # Force le profil audio "Speaker" (haut-parleurs internes) au lieu de
    # "Headphones", et empêche le basculement automatique gênant vers HDMI.
    wireplumber.extraConfig."51-alc236-speaker" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"; }
          ];
          actions.update-props = {
            "device.profile" = "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)";
            "api.acp.auto-profile" = false;
          };
        }
      ];
    };
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

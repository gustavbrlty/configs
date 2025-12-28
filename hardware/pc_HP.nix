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
    options snd-hda-intel probe_mask=1
  '';
  
  # Charger explicitement le module audio
  boot.kernelModules = [ "snd-hda-intel" ];
  
  # PipeWire avec résolution de conflit
  services.pipewire = {
    enable = lib.mkForce true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # To know the ###BATTERY### level (acpi -b)
  environment.systemPackages = with pkgs; [
    acpi
    alsa-utils
    pulseaudio  # Pour pavucontrol

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

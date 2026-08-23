# Laptop: Intel HD 5500 (iGPU, salidas de video) + NVIDIA 940M (Optimus).
# PRIME offload: la Intel maneja escritorio/batería, la NVIDIA se despierta
# solo para gaming. Driver legacy_580 = último que soporta Maxwell (940M).

{ config, pkgs, ... }:

{
  imports = [
    ../../shared
    ./hardware-configuration.nix
  ];

  networking.hostName = "laptop";

  # --- NVIDIA 940M (Maxwell) + PRIME offload ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;                    # Maxwell NO soporta módulos abiertos
    modesetting.enable = true;       # necesario para Wayland/Hyprland
    nvidiaSettings = true;
    powerManagement = {
      enable = true;
      finegrained = true;            # apaga la NVIDIA cuando no se usa (ahorra batería)
    };
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;     # crea `nvidia-offload` para lanzar apps en la GPU
      };
      intelBusId = "PCI:0@0:2:0";
      nvidiaBusId = "PCI:0@4:0:0";
    };
  };

  # NVIDIA: forzar modosetting en kernel para Wayland/Hyprland.
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Variables de sesión específicas NVIDIA (Hyprland/Wayland).
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";   # evita problemas de cursor en Hyprland
  };

  # thermald: daemon térmico de Intel — baja frecuencia del CPU antes de sobrecalentarse.
  services.thermald.enable = true;

  # --- Steam con wrapper de PRIME offload ---
  # El cliente Steam lanza con GPU NVIDIA también desde el launcher de
  # escritorio, no solo con el alias de zsh (`nvidia-offload steam`).
  programs.steam.package = pkgs.steam.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/steam \
        --set __NV_PRIME_RENDER_OFFLOAD 1 \
        --set __GLX_VENDOR_LIBRARY_NAME nvidia \
        --set __VK_LAYER_NV_optimus NVIDIA_only
    '';
  });
}

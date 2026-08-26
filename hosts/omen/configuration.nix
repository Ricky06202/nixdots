# HP Omen 17t-ck000: Intel i7-11800H (Tiger Lake, 8c/16t) + RTX 3070 Laptop 8GB.
# GPU dedicada siempre activa (sin PRIME offload — es gaming machine).

{ config, pkgs, ... }:

{
  imports = [
    ../../shared
    ./hardware-configuration.nix
  ];

  networking.hostName = "omen";

  # 16–32GB RAM: zram moderado al 25%.
  zramSwap.memoryPercent = 25;

  # Swap mínimo (16GB+ no necesita mucho respaldo).
  swapDevices = [ { device = "/swapfile"; size = 4096; } ];

  # --- NVIDIA RTX 3070 (Ampere) ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;                     # RTX 3070 soporta módulos abiertos
    modesetting.enable = true;       # necesario para Wayland/Hyprland
    nvidiaSettings = true;
    powerManagement = {
      enable = true;
    };
  };

  # NVIDIA: forzar modosetting para Wayland/Hyprland.
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Variables de sesión NVIDIA (Hyprland/Wayland).
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  # thermald: daemon térmico de Intel.
  services.thermald.enable = true;

  # `calor`: temperatura CPU + GPU en una línea.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "calor" ''
      Z=$(grep -l x86_pkg_temp /sys/class/thermal/thermal_zone*/type 2>/dev/null | head -1 | sed 's|/type||')
      if [ -n "$Z" ]; then
        T=$(( $(cat "$Z/temp" 2>/dev/null || echo 0) / 1000 ))
        echo -n "CPU ''${T}°C"
      else
        echo -n "CPU: ?"
      fi

      if command -v nvidia-smi >/dev/null 2>&1; then
        GPU=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$GPU" ]; then
          UTIL=$(echo "$GPU" | cut -d',' -f1 | tr -d ' ')
          TEMP=$(echo "$GPU" | cut -d',' -f2 | tr -d ' ')
          echo " | GPU: ''${TEMP}°C (''${UTIL}%)"
        fi
      fi
      echo
    '')
  ];

  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
}

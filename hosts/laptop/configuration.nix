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

  # 7.2GB RAM física: zram agresivo al 50% (~3.6GB comprimidos).
  zramSwap.memoryPercent = 50;

  # Swap en disco (respaldo de RAM). Ruta clásica /swapfile: la instalación
  # original del laptop no usa subvolúmenes Btrfs.
  swapDevices = [ { device = "/swapfile"; size = 8192; } ];

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

  # Watchdog de ventilador: la curva automática del EC de este modelo es floja
  # (se queda en ~4200 RPM aunque el CPU pase de 90°C, casi provoca apagones).
  # Este servicio toma control manual del ventilador (~90%) cuando el CPU pasa
  # el umbral HOT y devuelve el control a la EC cuando baja de COOL.
  # Nota: en modo manual este hwmon deja de reportar RPM — el control funciona,
  # solo el tacómetro calla. El índice hwmon cambia entre arranques: se resuelve
  # dinámicamente buscando el hwmon "asus".
  systemd.services.fan-watchdog = {
    description = "Fuerza el ventilador cuando el CPU se sobrecalienta";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
    };
    path = [ pkgs.coreutils ];
    script = ''
      HOT=85000    # millicelsius: umbral para tomar control manual
      COOL=75000   # millicelsius: umbral con histéresis para devolver auto
      HIGH=230     # duty ~90% (255 sería tope)
      MANUAL=0

      find_hwmon() {
        for d in /sys/class/hwmon/hwmon*; do
          if [ -f "$d/name" ] && grep -q '^asus$' "$d/name" && [ -f "$d/pwm1_enable" ]; then
            echo "$d"
            return 0
          fi
        done
        return 1
      }

      find_zone() {
        grep -l x86_pkg_temp /sys/class/thermal/thermal_zone*/type 2>/dev/null \
          | head -1 | sed 's|/type||'
      }

      H=$(find_hwmon) || exit 1
      echo "fan-watchdog: vigilando $H"

      while true; do
        Z=$(find_zone)
        T=$(cat "$Z/temp" 2>/dev/null || echo 0)
        if [ "$T" -ge "$HOT" ] && [ "$MANUAL" -eq 0 ]; then
          echo 1 > "$H/pwm1_enable" 2>/dev/null
          echo "$HIGH" > "$H/pwm1" 2>/dev/null
          MANUAL=1
          echo "fan-watchdog: MANUAL ON ($((T / 1000))°C)"
        elif [ "$T" -le "$COOL" ] && [ "$MANUAL" -eq 1 ] && [ "$T" -gt 0 ]; then
          echo 2 > "$H/pwm1_enable" 2>/dev/null
          MANUAL=0
          echo "fan-watchdog: automático restaurado ($((T / 1000))°C)"
        fi
        sleep 3
      done
    '';
  };

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

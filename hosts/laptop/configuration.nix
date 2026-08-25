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

  # `calor`: temperatura CPU + estado del ventilador en una línea.
  # Compatible con `watch -n 2 calor`. RPM reales solo en modo automático
  # (el tacómetro calla en manual); en manual se muestra duty % + estimación.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "calor" ''
      Z=$(grep -l x86_pkg_temp /sys/class/thermal/thermal_zone*/type 2>/dev/null | head -1 | sed 's|/type||')
      T=$(( $(cat "$Z/temp" 2>/dev/null || echo 0) / 1000 ))
      H=$(grep -l '^asus$' /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1 | sed 's|/name||')
      E=$(cat "$H/pwm1_enable" 2>/dev/null)
      if [ "$E" = "2" ]; then
        R=$(cat "$H/fan1_input" 2>/dev/null || echo "?")
        echo "CPU ''${T}°C | ventilador: automático (''${R} RPM)"
      elif [ "$E" = "1" ]; then
        D=$(cat "$H/pwm1" 2>/dev/null || echo 0)
        P=$(( D * 100 / 255 ))
        R=$(( 2400 + D * 11 ))
        echo "CPU ''${T}°C | ventilador: ''${P}% (~''${R} RPM est.)"
      else
        echo "CPU ''${T}°C | ventilador: ¿hwmon no encontrado?"
      fi
    '')
  ];

  # Curva de ventilador propia: la automática del EC es floja en este modelo
  # (se queda en ~4200 RPM aunque el CPU pase de 90°C, casi provoca apagones).
  # Umbral/escalones tomados de asus-fan-control (soporte oficial X555LB,
  # PR #156). Por debajo de 55°C se devuelve el control a la EC (silencio en
  # reposo + tacómetro visible); arriba, control manual por rangos de duty.
  # Validado empíricamente: pwm manual a 255 bajó la CPU de 92°→82°C en juego.
  # Nota: en modo manual este hwmon no reporta RPM (solo calla el tacómetro).
  systemd.services.fan-watchdog = {
    description = "Curva de ventilador personalizada para ASUS X555LB";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
    };
    path = [ pkgs.coreutils ];
    script = ''
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

      # temperatura -> duty pwm (0-255). Vacío = devolver modo automático.
      duty_para() {
        T=$1
        if   [ "$T" -gt 80000 ]; then echo 255
        elif [ "$T" -gt 76000 ]; then echo 230
        elif [ "$T" -gt 72000 ]; then echo 200
        elif [ "$T" -gt 68000 ]; then echo 180
        elif [ "$T" -gt 65000 ]; then echo 160
        elif [ "$T" -gt 62000 ]; then echo 140
        elif [ "$T" -gt 60000 ]; then echo 120
        elif [ "$T" -gt 55000 ]; then echo 100
        else echo ""
        fi
      }

      H=$(find_hwmon) || exit 1
      echo "fan-watchdog: curva activa, hwmon en $H"

      MANUAL=0
      while true; do
        Z=$(find_zone)
        T=$(cat "$Z/temp" 2>/dev/null || echo 0)
        D=$(duty_para "$T")
        if [ -z "$D" ]; then
          if [ "$MANUAL" -eq 1 ]; then
            echo 2 > "$H/pwm1_enable" 2>/dev/null
            MANUAL=0
            echo "fan-watchdog: automático ($((T / 1000))°C)"
          fi
        else
          if [ "$MANUAL" -eq 0 ]; then
            echo 1 > "$H/pwm1_enable" 2>/dev/null
            MANUAL=1
            echo "fan-watchdog: curva manual ON ($((T / 1000))°C)"
          fi
          echo "$D" > "$H/pwm1" 2>/dev/null
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

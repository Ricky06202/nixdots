# Laptop: SOLO Intel HD 5500 (iGPU). La NVIDIA 940M está DESACTIVADA por
# completo: sin driver, sin PRIME, sin kernel param. Todas las salidas de
# video viven en la iGPU (card1), así que nada la necesita. La 940M queda en
# latencia sin despertar nunca: 0 uso, 0 calor, 0 consumo.
# (Si algún día quisieras reactivarla: reintroducir hardware.nvidia + PRIME
# offload desde el repo, ya está documentado en git history.)

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

  # --- NVIDIA 940M DESACTIVADA ---
  # No se carga driver ni kernel params de NVIDIA. Solo la iGPU Intel.
  # El módulo hardware.nvidia y PRIME offload se eliminan en la línea de abajo.
  # (Sin driver: la 940M nunca se despierta, sin uso de VRAM/consumo.)

  # Cursor por software en Wayland (evita glitches de cursor en Hyprland).
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  # thermald: daemon térmico de Intel — baja frecuencia del CPU antes de sobrecalentarse.
  services.thermald.enable = true;

  # Tope de turbo: los apagones instantáneos de este equipo son ThermTrips por
  # PICOS de carga (ej: pantalla de carga de Minecraft con muchos mods) que
  # suben la unión a ~105°C en segundos — ni el ventilador ni thermald llegan
  # a tiempo (trip de hardware, sin rastro en el journal). Limitar max_perf_pct
  # recorta la cabeza térmica del turbo para que esos picos meseten bajo el
  # punto de disparo. Costo: ~10% menos rendimiento pico, imperceptible en uso
  # real. Si algún día hace falta el turbo completo: subir este valor a 100.
  systemd.services.cpu-turbo-cap = {
    description = "Limita el turbo del CPU para evitar trips térmicos por picos";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      echo 80 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
    '';
  };

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

  # --- Steam: iGPU Intel, sin wrapper ---
  # Ya no hay NVIDIA que forzar: Steam y sus juegos usan la iGPU Intel natural.
  programs.steam.package = pkgs.steam;

  # --- Bluetooth: SBC @ 44100 Hz fijo (solo laptop) ---
  # El chip Atheros QCA9565 de este equipo tira el transporte A2DP por jitter
  # USB bajo carga: los audífonos se desconectan/reconectan solos. Forzar SBC
  # a 44.1kHz reduce la tasa de paquetes y lo hace significativamente más
  # estable (probado: se desconecta ~1 vez en vez de repetidamente).
  # El nombre "90-" se carga después del "10-bluez-hfp-fix" de shared y lo
  # sobreescribe. AMD NO lo hereda: allá queda AAC/SBC multi-codec.
  services.pipewire.wireplumber.extraConfig = {
    "90-bluez-sbc-laptop" = {
      "wireplumber.settings" = {
        "bluez5.codecs" = [ "sbc" ];
        "bluez5.default.rate" = 44100;
      };
    };
  };
}

# Config compartida entre hosts (laptop + amd).
# Lo específico de cada máquina vive en hosts/<nombre>/configuration.nix.

{ config, pkgs, caelestiaShell, ... }:

{
  # Nix con flakes y nix-command habilitados (necesario para home-manager y caelestia)
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Bootloader: GRUB con tema Himeko-Nova.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.theme = ../home/assets/grub-theme;

  # Firmware redistribuible (necesario para AMD GPU y otros dispositivos)
  hardware.enableRedistributableFirmware = true;

  # WiFi USB (TP-Link Archer T2U, chipset Realtek RTL8821AU) — capta 5GHz y es
  # más estable que la Atheros AR9565 integrada. En el kernel 7.2 el driver
  # rtw88_8821au viene nativo. La integrada (ath9k) se deja como respaldo.
  boot.kernelModules = [ "rtw88_8821au" ];

  # Kernel latest: USB WiFi + GPUs funcionan nativos.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver    # VA-API para Intel Broadwell (i965, NO iHD)
      libvdpau-va-gl       # VDPAU → VA-API para apps que lo necesiten
      mangohud             # Vulkan layer para overlay de rendimiento
    ];
    extraPackages32 = with pkgs; [
      driversi686Linux.intel-vaapi-driver
    ];
  };

  # Optimizaciones de memoria para 7.2GB RAM.
  boot.kernel.sysctl = {
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;
  };

  # Bluetooth: deshabilitar autosuspend del adaptador btusb para evitar
  # desconexiones de audífonos (AZ09 y otros dispositivos BT se desconectaban
  # cuando el kernel suspendía el adaptador para ahorrar batería).
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=0
  '';

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;   # kernel + servicio bluetoothd
  hardware.bluetooth.settings = {
    General.Experimental = true;     # habilita funciones experimentales de BlueZ (necesario para algunos dispositivos)
  };
  hardware.xpadneo.enable = true;    # driver Bluetooth para mandos Xbox One / Series X|S
  services.blueman.enable = true;     # applet en bandeja + interfaz gráfica (blueman-manager)

  # upower: servicio de batería/power (Caelestia lo usa para detectar la batería).
  services.upower.enable = true;

  # gnome-keyring: guarda claves SSH/contraseñas en memoria (sin dialogos feos).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # --- Rendimiento: zram (swap comprimido en RAM) ---
  # El % de RAM y el swapfile de disco son específicos por host
  # (ver hosts/<nombre>/): laptop 7.2GB → zram 50%; amd 32GB → 25%.
  # En Btrfs el swapfile conviene aislado en el subvolúmen @swap.
  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";
  boot.kernel.sysctl."vm.swappiness" = 10;

  # Set your time zone.
  time.timeZone = "America/Panama";

  # Select internationalisation properties.
  i18n.defaultLocale = "es_PA.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_PA.UTF-8";
    LC_IDENTIFICATION = "es_PA.UTF-8";
    LC_MEASUREMENT = "es_PA.UTF-8";
    LC_MONETARY = "es_PA.UTF-8";
    LC_NAME = "es_PA.UTF-8";
    LC_NUMERIC = "es_PA.UTF-8";
    LC_PAPER = "es_PA.UTF-8";
    LC_TELEPHONE = "es_PA.UTF-8";
    LC_TIME = "es_PA.UTF-8";
  };

  # Enable the X11 windowing system (necesario para keymap y XWayland).
  services.xserver.enable = true;

  # Portales Wayland (captura de pantalla, file pickers, etc.)
  xdg.portal.enable = true;

  # Hyprland con UWSM para integración correcta con systemd.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # ReGreet: greeter gráfico GTK (Rust) — personalizable, fácil y estable.
  # El módulo configura greetd + cage automáticamente.
  # IMPORTANTE: ReGreet corre DENTRO de cage (compositor propio). NO lanza Hyprland.
  # Hyprland se inicia DESPUÉS del login, como sesión del usuario (elegida en el menú).
  services.displayManager.regreet = {
    enable = true;

    # cage usa solo el último monitor conectado (evita estirar el greeter
    # sobre ambas pantallas).
    cageArgs = [ "-s" "-d" "-mlast" ];

    # Tema GTK (Colloid-Dark ya instalado en systemPackages).
    theme = {
      package = pkgs.colloid-gtk-theme;
      name = "Colloid-Dark";
    };
    iconTheme.name = "Colloid-Dark";
    cursorTheme.name = "Bibata-Modern-Classic";
    font = {
      name = "IosevkaTerm Nerd Font";
      size = 22;
    };

    # Config TOML de ReGreet (opciones reales del sample).
    settings = {
      # Salta la pantalla de selección de usuario/sesión: va directo a pedir
      # la contraseña del último usuario autenticado.
      skip_selection = true;

      # Forzar tema oscuro (sin esto GTK usa el tema claro por defecto).
      GTK.application_prefer_dark_theme = true;

      background.path = "/var/lib/regreet/background.jpg";
      background.fit = "Cover";

      appearance.greeting_msg = "Bienvenido de vuelta";

      widget.clock = {
        format = "%a %H:%M";
        resolution = "500ms";
      };

      commands = {
        reboot = [ "systemctl" "reboot" ];
        poweroff = [ "systemctl" "poweroff" ];
      };
    };

    # CSS extra (se aplica sobre el tema GTK).
    extraCss = ''
      window {
        background-color: #0e1117;
      }
      #welcome-label {
        font-size: 48px;
        font-weight: bold;
        color: #fff;
        margin-top: 60px;
      }
      #clock-label {
        font-family: monospace;
        font-size: 56px;
        color: #64c8ff;
      }
      #date-label {
        font-size: 22px;
        color: rgba(255, 255, 255, 0.6);
        margin-bottom: 20px;
      }
      #form-box {
        background-color: rgba(14, 17, 23, 0.75);
        border: 1px solid rgba(100, 200, 255, 0.12);
        border-radius: 24px;
        padding: 32px;
      }
      entry {
        background-color: rgba(255, 255, 255, 0.06);
        border: 1px solid rgba(100, 200, 255, 0.15);
        border-radius: 14px;
        padding: 18px 22px;
        color: #fff;
        font-size: 18px;
      }
      entry:focus {
        border-color: rgba(100, 200, 255, 0.5);
      }
      button {
        background: rgba(100, 200, 255, 0.15);
        border: 1px solid rgba(100, 200, 255, 0.3);
        border-radius: 14px;
        padding: 18px;
        color: #fff;
        font-weight: bold;
        font-size: 18px;
      }
      button:hover {
        background-color: rgba(100, 200, 255, 0.25);
      }
      button:active {
        background-color: rgba(100, 200, 255, 0.35);
      }
    '';
  };

  # Wallpaper random: elige una imagen de ~/Imágenes/wallpapers/ al arrancar
  # y la pone en /var/lib/regreet/background.jpg para el greeter ReGreet.
  systemd.services.pick-wallpaper = {
    description = "Pick random wallpaper for ReGreet greeter";
    before = [ "greetd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${../home/scripts/pick-wallpaper.sh}";
    };
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # --- Fix Bluetooth (AZ09 se desconectaban) SIN perder el micrófono ---
    # El perfil HFP se mantiene activo (necesario para hablar), pero se usa
    # mSBC (banda ancha) que es el códec estable. No se desactiva nada.
    wireplumber.extraConfig = {
      "10-bluez-hfp-fix" = {
        "wireplumber.settings" = {
          "bluez5.enable-hfp-mic" = true;
          "bluez5.enable-hsp" = true;
          "bluez5.hfphsp-backend" = "native";
          "bluez5.hfphsp-role" = "source";
          "bluez5.codecs" = [ "aac" "sbc" "sbc_xq" "msbc" ];
          "bluez5.default.rate" = 48000;
          "bluez5.default.channels" = 2;
        };
      };
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Usuario "greeter": necesario para que ReGreet corra bajo greetd.
  users.users.greeter = {
    isSystemUser = true;
    group = "greeter";
    description = "Greeter user for ReGreet";
  };

  users.groups.greeter = { };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."ricky" = {
    isNormalUser = true;
    description = "Ricardo A Sanjur G";
    shell = pkgs.zsh; # shell por defecto: zsh (con plugins de home-manager)
    extraGroups = [ "networkmanager" "wheel" "input" ];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  # Shells válidas para el usuario (zsh es la default)
  environment.shells = [ pkgs.zsh ];
  programs.zsh.enable = true; # zsh como shell del sistema (login/terminals)



  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # nix-ld: permite correr binarios dinámicos "tal cual vienen de internet"
  # (Electron/npm run dev, node_modules/.bin, AppImages sin parchear) que
  # buscan /lib64/ld-linux-x86-64.so.2 — NixOS no lo trae por diseño.
  # `libraries` = las .so típicas que Electron/Chromium pide al arrancar;
  # si algo sigue quejándose de una lib faltante, se añade aquí.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      glib
      gtk3
      nss
      nspr
      atk
      at-spi2-atk
      cups
      dbus
      libdrm
      libgbm
      pango
      cairo
      alsa-lib
      mesa
      wayland            # apps GUI nativas wayland (airshipper/winit)
      libxkbcommon       # input de teclado para winit/wgpu
      vulkan-loader      # render wgpu (veloren usa Vulkan)
      libGL              # fallback OpenGL
      udev               # gamepads/input del cliente
      # Albion Online launcher (QtWebEngine): kerberos + stack de fuentes/X11
      krb5.lib           # libgssapi_krb5 (red del launcher)
      libxtst            # input sintético X11
      freetype
      expat
      fontconfig.lib     # fuentes (el default es .bin sin libs)
      libxrender
      libxau
      libxdmcp
      libxcursor
      libxi
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
      libxkbfile
    ];
  };

  # Fuentes: registrar en fontconfig para que fc-list las encuentre.
  fonts.packages = with pkgs; [
    nerd-fonts.iosevka-term
  ];

  # earlyoom: mata procesos pesados cuando la RAM se llena, evita que la PC se congele.
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };

  # --- Steam ---
  # (El wrapper de PRIME offload para el laptop vive en hosts/laptop/configuration.nix)
  programs.steam.enable = true;

  # --- GameMode (optimización de rendimiento en juegos, usado por Steam/Lutris) ---
  programs.gamemode.enable = true;

  # --- AppImages: ejecutar .AppImage con doble clic (appimage-run + FUSE) ---
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  # --- Java (necesario para PrismLauncher / Minecraft) ---
  programs.java.enable = true;
  programs.java.package = pkgs.jdk21;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Launcher generico para juegos nativos de Lutris en NixOS:
    # Lutris inyecta su propio LD_LIBRARY_PATH (gamemode/runtime) y con esa
    # variable definida el loader de nix-ld ignora sus rutas por defecto,
    # asi que al binario le faltan TODAS las libs del sistema (exit 127).
    # Uso en Lutris: exe = nixld-exec, args = /ruta/al/binario [args del juego]
    (pkgs.writeShellScriptBin "nixld-exec" ''
      export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+''${LD_LIBRARY_PATH}:}/run/current-system/sw/share/nix-ld/lib"
      exec "$@"
    '')
    vulkan-tools       # vulkaninfo: Lutris lo consulta para listar GPUs
    opencode          # asistente de IA (este)
    neovim            # editor
    (symlinkJoin {
      name = "brave";
      paths = [ brave ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/brave \
          --add-flags "--restore-last-session" \
          --add-flags "--noerrdialogs" \
          --run '
            # Parchea el Preferences de Brave para que siempre cree que salió
            # limpiamente (sin esto, tras apagones fuerza el diálogo "Restaurar").
            for PREF in \
              "$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences" \
              "$HOME/.config/BraveSoftware/Brave-Browser/Default/Secure Preferences" \
              "$HOME/.config/BraveSoftware/Brave-Browser/Local State"
            do
              [ -f "$PREF" ] || continue
              sed -i \
                -e "s/\"exit_type\":\"Crashed\"/\"exit_type\":\"Normal\"/g" \
                -e "s/\"exited_cleanly\":false/\"exited_cleanly\":true/g" \
                "$PREF"
            done
          '
      '';
    })  # navegador principal (Chromium, bloqueador built-in, wrapper anti-diálogo crash)
    chromium          # navegador Chromium puro (compatibilidad web sin capas extra)
    karere            # whatsapp (whatsapp-for-linux se retiró de nixpkgs)
    spotify           # música
    lutris            # gestor de juegos
    wezterm           # terminal
    git
    grim              # captura de pantalla (wayland)
    slurp             # selector de región para grim
    wl-clipboard      # portapapeles wayland (wl-copy / wl-paste)
    zellij            # multiplexor de terminal
    hyprpaper         # fondos de pantalla (wayland)
    swaynotificationcenter # notificaciones (sway notification center)
    hypridle          # daemon de inactividad (bloqueo automatico)
    hyprlock          # pantalla de bloqueo
    hyprpicker        # selector de color
    pulseaudio        # provee pactl (Steam lo necesita para audio)
    bibata-cursors    # tema de cursor (Bibata Modern Classic)
    colloid-gtk-theme # tema GTK oscuro (adw-gtk3 causa headerbar blanco en Thunar)
    polkit_gnome       # agente polkit (dialogos de autenticacion con tema)
    xsettingsd         # propaga tema GTK a apps X11
    waybar            # barra de estado (workspaces, reloj, bateria, etc.)
    iw                # info/diagnóstico de WiFi (frecuencia, señal, canal)
    blueman           # gestor de bluetooth (applet en bandeja + interfaz)
    nerd-fonts.iosevka-term # fuente Iosevka Term (Nerd Font) para terminal/wofi (también en fonts.packages)
    blender           # modelado 3D
    inkscape          # diseno vectorial
    gimp              # edicion de imagenes
    krita             # pintura/dibujo digital
    vscode            # editor de codigo (Microsoft oficial)
    zed-editor        # editor secundario (open source, gratuito)
    nodejs_24         # Node.js + npm
    bun               # runtime JS rapido
    # --- Lenguajes de programación ---
    python3           # Python 3 (con pip)
    rustc             # compilador de Rust
    cargo             # gestor de paquetes de Rust
    go                # lenguaje Go
    gcc               # compilador C/C++
    gdb               # debugger de C/C++
    deno              # runtime de JS/TS alternativo
    jdk               # Java (complemento al openjdk del sistema)
    # --- Godot + Android (exportar APK) ---
    godot             # motor de juegos 2D/3D (Godot 4.7)
    android-tools     # adb, fastboot (para instalar APK en el teléfono)
    android-studio    # IDE Android con SDK Manager (instala build-tools/NDK)
    pkg-config        # detección de librerías (necesario para Tauri/build)
    # --- Tauri (apps de escritorio con Rust + web) ---
    cargo-tauri       # CLI de Tauri
    webkitgtk_4_1     # WebView (motor de render de Tauri en Linux)
    librsvg           # renderizado SVG (dependencia de Tauri)
    prismlauncher     # launcher de Minecraft
    wofi              # lanzador de apps (wayland)
    winetricks        # utilidades wine (complemento de Lutris)
    # --- Oficina / productividad ---
    libreoffice       # suite ofimática (escritor, planilha, presentación)
    evince            # visor de PDFs (GNOME, ligero, Wayland nativo)
    gnome-calculator  # calculadora
    thunderbird       # cliente de correo
    thunar            # gestor de archivos (GTK, ligero, respaldo)
    nemo-with-extensions  # gestor de archivos principal (con extensiones GVFS: network, MTP, etc.)
    file-roller       # gestor de comprimidos — la extensión "Extraer aquí" de Nemo lo necesita
    loupe             # visor de imágenes (GNOME, ligero, Wayland nativo)
    gvfs              # daemon de red para Nemo (SMB, MTP, network browsing)
    bitwarden-desktop # gestor de contraseñas (nube, encriptado, 2FA)
    obs-studio        # OBS COMPLETO con obs-browser (overlays de Twitch, alertas) — la PC AMD lo aguanta
    vesktop           # Discord con Vencord (reemplaza a discord, más estable en Wayland)
    # Escritorio Caelestia (quickshell de nixpkgs precompilado + CLI incluido).
    # Evita compilar el quickshell-git de outfoxxed (~1h). Ver flake.nix.
    caelestiaShell
    # --- Uso offline / multimedia ---
    mpv               # reproductor de video local
    (symlinkJoin {
      name = "rustdesk";
      paths = [ rustdesk ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rustdesk --unset WAYLAND_DISPLAY --unset WAYLAND_SOCKET --set XDG_SESSION_TYPE x11 --set GDK_BACKEND x11
      '';
    })  # escritorio remoto (fix teclado Wayland: XWayland; symlinkJoin usa el bin del caché sin recompilar)
    ffmpeg            # herramienta multimedia
    gpu-screen-recorder # backend de grabación de Caelestia (botón de grabar pantalla)
    mangohud          # overlay de rendimiento (FPS, temps, GPU/CPU) — necesita systemPackages para Vulkan layer
    btop              # monitor del sistema
    lm_sensors        # monitoreo de temperatura (sensors, sensors-detect)
    upower            # servicio de batería/power (lo usa Caelestia para detectar la batería)
    udisks2           # montaje automático de USBs/discos (lo traía GNOME)    wget              # descargas desde terminal
    unzip             # descomprimir archivos
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # --- Descubrimiento de red (para que Nemo muestre "Network") ---
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "nixos";
        "netbios name" = "nixos";
        "security" = "user";
        "hosts allow" = "192.168. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "Bad User";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # Performance mode: power-profiles-daemon (Caelestia lo lee por D-Bus)
  services.power-profiles-daemon.enable = true;

  # Variables de cursor a nivel de sesión: se exportan ANTES de que arranquen
  # XWayland y las apps X11, para que todas usen el tema Bibata (incluido Steam/Spotify).
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    # Android (Godot/Tauri export): ruta del JDK (Godot lo necesita).
    JAVA_HOME = "${pkgs.jdk21}";
    # MangoHUD: ruta del config + dlsym para OpenGL (juegos 2D/GameMaker)
    MANGOHUD_CONFIGFILE = "/home/ricky/.config/MangoHUD/MangoHUD.conf";
    MANGOHUD_DLSYM = "1";
  };

  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}

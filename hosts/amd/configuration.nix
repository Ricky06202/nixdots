# PC AMD — specs reales:
#   CPU:  AMD Ryzen 5 5500 (6c/12t, Zen 3)
#   GPU:  ASRock Challenger OC RX 7600 8GB (RDNA3, amdgpu/Mesa nativos)
#   MB:   Gigabyte B550M K (Micro ATX, AM4)
#   RAM:  2x 16GB DDR4-3200 CL22 Silicon Power (32GB total)
#   SSD:  ADATA LEGEND 860 500GB NVMe PCIe 4.0
#   PSU:  MSI MAG A550BN 550W 80+ Bronze

{ pkgs, config, ... }:

let
  # Usuario de la sesión gráfica (greetd -> cage -> Hyprland).
  guiUser = "ricky";

  # Hook post-resume. Patrón documentado en systemd.special(7) para enganchar
  # código ANTES de dormir (ExecStart) y DESPUÉS de despertar (ExecStop):
  # el unit se activa con sleep.target y se para al deshacerlo.
  resumeHeal = pkgs.writeShellScript "amdgpu-resume-heal" ''
    set -euo pipefail

    runtime_dir="/run/user/$(id -u ${guiUser})"

    # margen para que el MODE1 reset asiente antes de tocar la KMS
    sleep 4

    # La dGPU (Navi 23 / SOC21) se resetea en cada resume de s2idle: el driver
    # lee dos veces el sign-of-life register del PSP (soc21_need_reset_on_resume)
    # y si cambió asume "suspend abortado" => MODE1 reset. El reset es correcto
    # en kernel, pero aquamarine no re-adquiere el estado de KMS, así que la
    # CRTC se queda con el framebuffer anterior al suspend. Un reload fuerza un
    # modeset limpio y repinta la pantalla.
    sig="$(ls "$runtime_dir"/hypr/ 2>/dev/null | grep -v '\.socket' | head -n1 || true)"

    if [ -n "$sig" ]; then
      for _ in 1 2 3; do
        if runuser -u ${guiUser} -- env \
             HYPRLAND_INSTANCE_SIGNATURE="$sig" \
             XDG_RUNTIME_DIR="$runtime_dir" \
             hyprctl reload
        then
          break
        fi
        sleep 3
      done
    else
      echo "amdgpu-resume-heal: Hyprland no corre, nada que re-modesetear" >&2
    fi

    # El xhci_hcd tambien se resetea al despertar ("xHC error in resume, Reinit")
    # y Hyprland se queda sin teclado/ratón. Re-disparar udev (solo input de
    # usuario, no power-button/video-bus) para que libinput los vuelva a leer.
    udevadm trigger --subsystem-match=input --property-match=ID_INPUT_KEYBOARD=1 || true
    udevadm trigger --subsystem-match=input --property-match=ID_INPUT_MOUSE=1 || true
    udevadm settle || true
  '';
in

{
  imports = [
    ../../shared
    ./hardware-configuration.nix
  ];

  networking.hostName = "amd";

  # Microcode AMD (estabilidad/seguridad del CPU).
  hardware.cpu.amd.updateMicrocode = true;

  # 32GB RAM física: zram al 25% (8GB, priority -1 => nunca es target de
  # hibernación) + swapfile de disco de 40GB para poder hibernar (>= RAM de
  # uso tipico con margen).
  zramSwap.memoryPercent = 25;

  # Swap en disco, dentro del subvolúmen @swap (instalación Btrfs):
  # es el dispositivo donde systemd-hibernate escribe la imagen de la RAM.
  # priority=100: el kernel escribe la imagen de hibernacion en el swap de
  # MAYOR prioridad. zramSwap viene con prio 5 y zram es RAM volatil: con el
  # swapfile a -1 la cabecera caia en zram y el resume moria ("Unable to
  # resume ... continuing boot process"). Con 100 la imagen va al disco y
  # sobrevive al apagado.
  swapDevices = [ { device = "/swap/swapfile"; size = 40960; priority = 100; } ];

  # initrd con systemd: systemd-hibernate-resume lee la EFI var
  # "HibernateLocation" que deja el hibernate y restaura la imagen al boot
  # (funciona con swapfile, sin tocar GRUB ni hardcoded offsets).
  boot.initrd.systemd.enable = true;

  # Comportamiento de suspend/hibernate de logind.
  systemd.sleep.settings.Sleep = {
    HibernateMode = "shutdown";
    HibernateDelaySec = "30min";
  };

  # IA local (ollama) — la RX 7600 lo acelera vía Vulkan.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
    port = 11434;
    loadModels = [ "qwen3:8b" ];
  };

  # Auto-descargar el modelo tras cada consulta: libera VRAM/RAM al momento,
  # así no hay que desmontarlo a mano para jugar (solo se sube mientras se usa).
  systemd.services.ollama.environment = {
    OLLAMA_KEEP_ALIVE = "0";
    OLLAMA_MAX_LOADED_MODELS = "1";
  };

  # Sunshine: host de game-streaming para Moonlight — la laptop de ella
  # recibe el video de la RX 7600 por LAN y devuelve teclado/mouse/mando como
  # dispositivos virtuales.
  #
  # MODO SIMPLE (2026-10): TODO bajo ricky. Ella juega con SU cuenta de Steam
  # dentro del stream pero en TU usuario Linux: mismo HOME, mismos prefijos
  # Proton tuyos (el "pfx is not owned by you" que mataba Goofy Gorillas
  # desaparece), sin ACLs ni linger ni unidades system. Costo aceptado: un
  # solo Steam online a la vez en esta maquina — mientras ella juega, tu no.
  # El modulo crea USER-unit (corre en tu sesion grafica): captura
  # wl-screencopy directo sobre TU Hyprland, y output_name "HEADLESS-1"
  # (Display Id) transmite el monitor
  # fantasma donde la window rule class=gamescope mapea
  # su ventana (ws 6, fullscreen, no_focus).
  #   max_bitrate: kbps; el default (~1Mbps) se veia a tirones.
  #   gamepad: xone (mando Xbox One) via /dev/uinput (requiere ricky
  #   en grupo uinput, abajo).
  #   stream_audio=false: sin audio en el stream y sin fugas de tu escritorio.
  #   keyboard=false / mouse=false: NO se inyecta teclado ni raton del stream
  #   (los toggles "Keyboard/Mouse passthrough" de la web UI son EFIMEROS: el
  #   conf es declarativo y los pisa). Sola queda el mando xone (evdev global,
  #   ajeno al foco de Hyprland) => ella juega con mando y tu escritorio no se
  #   entera. Keys verificadas en el binary sunshine (labels "Keyboard/Mouse
  #   passthrough" -> conf keys `keyboard`/`mouse`).
  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
    settings = {
      output_name = "HEADLESS-1";
      max_bitrate = 50000;
      gamepad = "xone";
      stream_audio = false;
      keyboard = false;
      mouse = false;
    };
    # Apps del menu Moonlight. Envuelta en gamescope => window rule
    # class=gamescope => ws 6 / HEADLESS-1 fullscreen. steam a secas: es TU
    # steam (wrapper PRIME offload solo existe en laptop; aqui no aplica).
    # HOME propio (steam-ella, 2026-10): DEMOSTRADO que dos clientes Steam
    # conviven bajo el mismo uid con HOMEs distintos (el lock vive en
    # ~/.steam). La app de ella NUNCA despierta tu cliente nativo (adios al
    # Big Picture fantasma): tu steam abre NORMAL, sin flags.
    #   - Primer arranque: login de SU cuenta (una vez, local).
    #   - Para ver tus juegos: ella anade tu Library Folder (Settings >
    #     Storage) y usa Family Sharing si aplica.
    # OJO: con esto declarado, el editor "Applications" de la web UI deja de
    # guardar; se edita aqui.
    applications = {
      apps = [
        {
          name = "Steam";
          cmd = "mkdir -p /home/ricky/steam-ella && HOME=/home/ricky/steam-ella ${pkgs.gamescope}/bin/gamescope -w 1920 -h 1080 --force-windows-fullscreen -- steam";
        }
      ];
    };
  };

  # uinput: ricky (dueno del user-unit sunshine) crea el mando xone virtual.
  # hardware.uinput.enable lo trae el propio modulo de sunshine.
  users.users.ricky.extraGroups = [ "uinput" ];

  # Blacklistear nouveau: si hay una NVIDIA físicamente presente, no se usa y
  # nouveau solo gasta RAM/CPU.
  boot.blacklistedKernelModules = [ "nouveau" ];

  # Estabilidad de suspend en esta placa (B550M + RX 7600):
  # - mem_sleep_default=s2idle: el handoff al S3 "deep" de la BIOS cuelga el
  #   sistema justo tras "Suspending console(s)" (firmware AM4 con S3 mal
  #   implementado). s2idle usa la ruta de idle del SoC, que sí funciona.
  # - amdgpu.sg_display=0: workaround del hang de display DC en suspend/resume
  #   (el boot ya muestra REG_WAIT timeout en optc32_disable_crtc, DCN 3.2).
  # - secretmem.enable=false: si algun proceso mantiene memfd_secret viva
  #   (p.ej. GnuPG >=2.4), hibernation_available() del kernel 7.x se vuelve
  #   false => /sys/power/disk=[disabled] y suspend-then-hibernate muere con
  #   EPERM. Apagandolo, esos usuarios caen a mlock y la hibernacion revierte.
  # - amdgpu.aspm=0 + pcie_aspm.policy=performance: la dGPU mantiene vivo el
  #   firmware TOS del PSP a traves del s2idle, que es lo que hace que el driver
  #   detecte el "suspend abortado" al despertar. Sin ASPM la cadena no se
  #   apaga y el abort es menos frecuente. NO lo elimina: el MODE1 reset es una
  #   mitigacion deliberada de upstream, asi que ademas hace falta el heal de
  #   abajo para que el modo1 reset no rompa el escritorio.
  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "amdgpu.sg_display=0"
    "secretmem.enable=false"
    "amdgpu.aspm=0"
    "pcie_aspm.policy=performance"
  ];

  # El MODE1 reset de amdgpu al despertar es correcto en kernel, pero el backend
  # DRM de Hyprland (aquamarine) no lo maneja: tras el reset la CRTC conserva el
  # framebuffer previo al suspend y el escritorio queda congelado, y el xhci_hcd
  # tambien se resetea dejando a Hyprland sin teclado/ratón. Este unit se
  # engancha a sleep.target y devuelve la sesion sola al despertar, sin TTY.
  systemd.services.amdgpu-resume-heal = {
    description = "Re-modeset del compositor tras el MODE1 reset de amdgpu";
    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];
    unitConfig = {
      DefaultDependencies = false;
      StopWhenUnneeded = true;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${resumeHeal}";
    };
    path = with pkgs; [ coreutils hyprland udev util-linux ];
  };
}

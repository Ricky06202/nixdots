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

  # Manifest propio para que Canvas se pueda instalar como PWA desde el
  # teléfono. Las imágenes las sirve el frontend oficial de Agent Canvas.
  janRemoteManifest = pkgs.writeText "jan-remoto.webmanifest" (builtins.toJSON {
    id = "/";
    name = "Jan Remoto";
    short_name = "Jan";
    description = "Jan local en la PC de Ricky";
    start_url = "/";
    scope = "/";
    display = "standalone";
    orientation = "any";
    background_color = "#15141b";
    theme_color = "#15141b";
    icons = [
      {
        src = "/android-chrome-192x192.png";
        sizes = "192x192";
        type = "image/png";
      }
      {
        src = "/android-chrome-512x512.png";
        sizes = "512x512";
        type = "image/png";
        purpose = "any";
      }
    ];
  });

  # PWA installable, but intentionally no offline cache: the PC/model must be
  # reachable for conversations, and private chats must not be cached on-phone.
  janRemoteServiceWorker = pkgs.writeText "jan-remoto-service-worker.js" ''
    self.addEventListener("install", (event) => event.waitUntil(self.skipWaiting()));
    self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));
  '';
  janRemotePwaRegister = pkgs.writeText "jan-remoto-pwa-register.js" ''
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
        .catch((error) => console.warn("Jan Remote PWA registration failed", error));
    }
  '';

  # El reverse proxy es loopback-only; Tailscale Serve añade HTTPS privado.
  canvasProxyHeaders = ''
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
  '';

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

  # App oficial ChatGPT: solo en la PC principal (clausura Nix ~2.7 GiB).
  # jan: asistente local de escritorio (llama.cpp + Vulkan bundled, AppImage
  # envuelto). Los modelos GGUF viven FUERA del store, en
  # ~/.local/share/Jan/data/llamacpp/models (TwIL 8B / Qwen3-VL 4B).
  environment.systemPackages = [
    (pkgs.callPackage ../../packages/chatgpt-official { inherit pkgs; })
    pkgs.jan
  ];

  # Canvas web privado para programar desde el celular. El agente corre como
  # usuario sin privilegios; solo puede modificar /srv/agent-canvas y su estado
  # privado. Los modelos siguen siendo los de Jan (puerto estable por el bridge).
  services.tailscale.enable = true;

  users.users.agentcanvas = {
    isSystemUser = true;
    group = "users";
    home = "/var/lib/agent-canvas";
    createHome = true;
    homeMode = "0700";
    description = "OpenHands Agent Canvas sin privilegios";
  };

  systemd.tmpfiles.rules = [
    # Workspace compartido entre ricky y el agente, separado de ~/Dev/keys.
    "d /srv/agent-canvas 2770 ricky users - -"
  ];

  systemd.services.agent-canvas = {
    description = "OpenHands Agent Canvas (Jan Remoto)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "systemd-tmpfiles-setup.service" ];
    path = with pkgs; [ nodejs_24 uv bun git gh wrangler curl openssh ];
    environment = {
      HOME = "/var/lib/agent-canvas";
      NPM_CONFIG_CACHE = "/var/lib/agent-canvas/.npm";
      UV_CACHE_DIR = "/var/lib/agent-canvas/.cache/uv";
      UV_PYTHON_INSTALL_DIR = "/var/lib/agent-canvas/.local/share/uv/python";
      # LiteLLM no reconoce todavía el ID local de Qwen3-VL; el usuario
      # seleccionará el perfil Qwen antes de adjuntar fotos.
      OPENHANDS_FORCE_VISION = "true";
      CANVAS_VPS_KEY = "%d/vps_key";
    };
    serviceConfig = {
      Type = "simple";
      User = "agentcanvas";
      Group = "users";
      WorkingDirectory = "/srv/agent-canvas";
      ExecStart = "${pkgs.nodejs_24}/bin/npx --yes @openhands/agent-canvas@1.40.0 --host 127.0.0.1 --port 8000";
      Restart = "on-failure";
      RestartSec = "10s";
      UMask = "0007";
      StateDirectory = "agent-canvas";
      StateDirectoryMode = "0700";
      LoadCredential = [ "vps_key:/home/ricky/Dev/keys/agent-canvas/vps_ed25519" ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      RestrictRealtime = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      ReadWritePaths = [ "/srv/agent-canvas" ];
    };
  };

  # Stable, loopback-only OpenAI endpoint for OpenHands. It discovers Jan's
  # random llama.cpp port/key and loads TwIL or Qwen on demand.
  systemd.services.jan-openai-bridge = {
    description = "OpenAI-compatible loopback bridge to Jan";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ pkgs.bun pkgs.iproute2 ];
    serviceConfig = {
      Type = "simple";
      User = guiUser;
      Group = "users";
      ExecStart = "${pkgs.bun}/bin/bun run ${../../home/dotfiles/openhands/jan-api-bridge.ts}";
      Restart = "on-failure";
      RestartSec = "3s";
      UMask = "0077";
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
    };
  };

  # PWA façade: adds a named manifest/mobile metadata while proxying Canvas.
  # Only loopback listens here; the phone will reach it through Tailscale Serve.
  services.nginx = {
    enable = true;
    virtualHosts."jan-remoto" = {
      serverName = "localhost";
      listen = [ { addr = "127.0.0.1"; port = 8001; } ];
      extraConfig = ''
        client_max_body_size 25m;
      '';
      locations."= /site.webmanifest" = {
        alias = "${janRemoteManifest}";
        extraConfig = ''
          default_type application/manifest+json;
          add_header Cache-Control "no-cache";
        '';
      };
      locations."= /pwa-register.js" = {
        alias = "${janRemotePwaRegister}";
        extraConfig = ''
          default_type application/javascript;
          add_header Cache-Control "no-cache";
        '';
      };
      locations."= /service-worker.js" = {
        alias = "${janRemoteServiceWorker}";
        extraConfig = ''
          default_type application/javascript;
          add_header Service-Worker-Allowed "/" always;
          add_header Cache-Control "no-cache";
        '';
      };
      locations."/assets/" = {
        proxyPass = "http://127.0.0.1:8000";
        extraConfig = canvasProxyHeaders;
      };
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        extraConfig = ''
          ${canvasProxyHeaders}
          proxy_set_header Accept-Encoding "";
          sub_filter_once on;
          sub_filter '</head>' '<link rel="manifest" href="/site.webmanifest"><link rel="apple-touch-icon" href="/apple-touch-icon.png"><meta name="theme-color" content="#15141b"><meta name="apple-mobile-web-app-title" content="Jan"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="mobile-web-app-capable" content="yes"><script src="/pwa-register.js" defer></script></head>';
        '';
      };
    };
  };

  # The systemd unit is deliberately not enabled: first join the PC to your
  # tailnet with `tailscale up`, then start this once. Serve stays private and
  # Tailscale persists the HTTPS route across reboots.
  systemd.services.jan-remoto-tailscale-serve = {
    description = "Expose Jan Remoto PWA over private Tailscale HTTPS";
    after = [ "tailscaled.service" "nginx.service" ];
    requires = [ "tailscaled.service" "nginx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg http://127.0.0.1:8001";
    };
  };

  # Microcode AMD (estabilidad/seguridad del CPU).
  hardware.cpu.amd.updateMicrocode = true;

  zramSwap.memoryPercent = 25;

  swapDevices = [ { device = "/swap/swapfile"; size = 8192; } ];

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
    # CRITICO: sunshine ejecuta cmd SIN SHELL (argv directo). Nada de `&&`,
    # `;` ni `VAR=` inline ahi (mkdir con && como operando muria en 0.4s el
    # 2026-10-05). Las variables van en applications.env (apps.json "env").
    # OJO: con esto declarado, el editor "Applications" de la web UI deja de
    # guardar; se edita aqui.
    applications = {
      env = { HOME = "/home/ricky/steam-ella"; };
      apps = [
        {
          name = "Steam";
          cmd = "${pkgs.gamescope}/bin/gamescope -w 1920 -h 1080 --force-windows-fullscreen -- steam";
        }
      ];
    };
  };

  # uinput: ricky (dueno del user-unit sunshine) crea el mando xone virtual.
  # hardware.uinput.enable lo trae el propio modulo de sunshine.
  users.users.ricky.extraGroups = [ "uinput" "dialout" ];

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

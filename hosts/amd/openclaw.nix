{ pkgs, openclaw, ... }:

# OpenClaw: asistente IA autoalojado (gateway) con acceso por Discord.
# Corre como usuario dedicado `openclaw` (sandbox: NO ve los secretos de
# ricky — wrangler, SSH, keystores — ni puede hacer rebuild).
# Secretos: archivos en /etc/openclaw/ creados a mano (ver README abajo del
# archivo); el modulo HM los lee al arrancar (environment = nombre -> ruta).

let
  # WORKAROUND nix-openclaw issue #158 (abierto, sin fix upstream):
  # los plugins cargados via plugins.load.paths (lo que genera
  # programs.openclaw.runtimePlugins) reciben origin "config" y OpenClaw
  # les niega openKeyedStore => discord muere en register ("trust gate").
  # Las unicas fuentes de trust son origin "bundled" (extension dentro del
  # arbol del paquete) o un install-record oficial (imposible en Nix mode).
  #
  # Solucion: copiar discord+deepseek DENTRO de dist/extensions/ del paquete
  # openclaw-gateway (origin "bundled" => trusted, igual que telegram).
  # Ojo: el loader ESM del gateway no acepta node_modules anidados bajo
  # dist/ (los bundled oficiales llevan deps aplastadas), asi que las deps
  # del plugin se fusionan en node_modules/ del core — las 10 que colisionan
  # son EXACTAMENTE la misma version que el core (catalogo alineado, verificado
  # con diff de package.json), por eso la fusion es segura. Cambiar el pin de
  # openclaw => re-verificar versions antes de rebuild si discord falla.
  openclawTrusted =
    let
      gw = pkgs.openclaw-gateway;
      base = pkgs.openclaw;
      discord = pkgs.openclawRuntimePlugins.discord;
      deepseek = pkgs.openclawRuntimePlugins.deepseek;
    in
    pkgs.runCommand "openclaw-trusted-plugins" { }
      ''
        set -eu
        gwout=$out/gw
        mkdir -p $gwout
        cp -a --reflink=auto ${gw}/lib $gwout/lib
        core=$gwout/lib/node_modules
        pkgdir=$core/openclaw
        chmod u+w $gwout/lib $core $pkgdir $pkgdir/dist
        ext=$pkgdir/dist/extensions
        chmod u+w $ext

        mkdir -p $ext/discord $ext/deepseek
        cp -a --reflink=auto ${discord}/. $ext/discord/
        cp -a --reflink=auto ${deepseek}/. $ext/deepseek/
        chmod -R u+w $ext/discord $ext/deepseek
        rm -rf $ext/discord/node_modules $ext/deepseek/node_modules

        # Fusionar deps del plugin en node_modules del core (el stub
        # "openclaw" anidado se omite: el core ya esta ahi).
        cd ${discord}/node_modules
        for e in *; do
          [ "$e" = openclaw ] && continue
          case "$e" in
            @*)
              mkdir -p $core/$e
              chmod u+w $core/$e
              for s in $e/*; do
                [ -e $core/$e/$(basename $s) ] || cp -a --reflink=auto $s $core/$e/
              done ;;
            *)
              [ -e $core/$e ] || cp -a --reflink=auto $e $core/ ;;
          esac
        done

        mkdir -p $gwout/bin
        sed "s|${gw}|$gwout|g" ${gw}/bin/openclaw > $gwout/bin/openclaw
        chmod +x $gwout/bin/openclaw

        mkdir -p $out/bin
        sed "s|${gw}|$gwout|g" ${base}/bin/openclaw > $out/bin/openclaw
        chmod +x $out/bin/openclaw
      '';
in
{
  nixpkgs.overlays = [ openclaw.overlays.default ];

  users.groups.openclaw = { };

  # UNICA excepcion de sudo para el bot: apagar el equipo cuando Ricky lo pide
  # por Discord ("apaga la PC"). Nada de rebuild ni otros systemctl: la regla
  # fija binario Y subcomando. Ver TOOLS.md del workspace.
  security.sudo.extraConfig = ''
    openclaw ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl poweroff
  '';
  users.users.openclaw = {
    isSystemUser = true;
    group = "openclaw";
    home = "/var/lib/openclaw";
    createHome = true;
  };

  # Linger: el servicio systemd --user de openclaw debe vivir sin sesion grafica.
  systemd.tmpfiles.rules = [
    "d /var/lib/systemd/linger 0755 root root - -"
    "f /var/lib/systemd/linger/openclaw 0644 root root - -"
    "d /etc/openclaw 0755 root root - -"
  ];

  home-manager.users.openclaw = {
    imports = [ openclaw.homeManagerModules.openclaw ];

    programs.openclaw = {
      enable = true;
      # NO meter discord/deepseek en runtimePlugins (bug #158, ver comentario de
      # openclawTrusted arriba): van empaquetados como bundled/trusted en el
      # package envuelto. Esto también elimina plugins.load.paths del config.
      package = openclawTrusted;

      # Contexto persistente del agente (equivalente al INSTRUCTIONS.md de
      # opencode). bootstrapFiles fuerza skipBootstrap para que no siembre
      # plantillas por defecto.
      workspace.bootstrapFiles = {
        agents = ./openclaw/workspace/AGENTS.md;
        soul = ./openclaw/workspace/SOUL.md;
        tools = ./openclaw/workspace/TOOLS.md;
        identity = ./openclaw/workspace/IDENTITY.md;
        user = ./openclaw/workspace/USER.md;
        # Guía del heartbeat periódico (sin este archivo el heartbeat no tiene
        # nada que chequear; ver config.agents.defaults.heartbeat).
        heartbeat = ./openclaw/workspace/HEARTBEAT.md;
      };

      environment = {
        DEEPSEEK_API_KEY = "/etc/openclaw/deepseek-key";
        DISCORD_BOT_TOKEN = "/etc/openclaw/discord-token";
        OPENCLAW_GATEWAY_TOKEN = "/etc/openclaw/gateway-token";
        # Credenciales PROPIAS del bot (no las de ricky):
        #   GH_TOKEN   -> PAT fine-grained, solo repos de Ricky06202, sin admin
        #   CLOUDFLARE_API_TOKEN -> token CF escopado a la cuenta de carreras
        GH_TOKEN = "/etc/openclaw/gh-token";
        CLOUDFLARE_API_TOKEN = "/etc/openclaw/cf-token";
      };

      config = {
        gateway = {
          mode = "local";
          auth.token = { source = "env"; provider = "default"; id = "OPENCLAW_GATEWAY_TOKEN"; };
        };

        # Plugins bundled (trusted) que van en el package envuelto: deepseek se
        # auto-activa (enabledByDefault), discord hay que habilitarlo a mano.
        plugins.entries.discord.enabled = true;
        plugins.entries.deepseek.enabled = true;

        channels.discord = {
          enabled = true;
          token = { source = "env"; provider = "default"; id = "DISCORD_BOT_TOKEN"; };
          # Tu user ID de Discord (snowflake, string).
          allowFrom = [ "276103262875287553" ];
        };

        # Provider deepseek (plugin oficial): sin overrides. El plugin ya trae
        # baseUrl https://api.deepseek.com, el catalogo de modelos con costos
        # reales (deepseek-v4-flash / deepseek-v4-pro / deepseek-flash) y
        # usageProviders => /usage muestra la plata sin config extra. La key
        # va por env DEEPSEEK_API_KEY.
        #
        # Nota: el filtro DataInspectionFailed era del moderador de DashScope
        # (Alibaba) sobre el input, no del modelo Qwen. deepseek no tiene ese
        # filtro; por eso ya no hace falta sanitizar descripciones de skills
        # (aunque se dejan neutras por si se vuelve a qwen como fallback).

        # Footer de uso (tokens + costo) en cada respuesta, por defecto en
        # todas las sesiones. Cada /usage por-session hace override;
        # /usage reset vuelve a heredar este valor.
        messages.responseUsage = "full";

        # Solo Ricky usa a Molty: dueño unico = su ID de Discord. Comandos de
        # admin (owner-only) restringidos a él; /restart deshabilitado desde
        # chat (si el gateway cae, systemd lo levanta solo: Restart=always).
        commands = {
          restart = false;
          ownerAllowFrom = [ "discord:276103262875287553" ];
        };

        # Modelos DeepSeek: deepseek-flash (default, barato) y deepseek-v4-pro
        # (fallback para tareas dificiles). Auth = DEEPSEEK_API_KEY (env).
        # Mismo par que opencode (deepseek/deepseek-flash + .../deepseek-v4-pro).
        agents.defaults.model = {
          primary = "deepseek/deepseek-flash";
          fallbacks = [ "deepseek/deepseek-v4-pro" ];
        };

        # Heartbeat: cada 45m (solo de 7:00 a 23:30) Molty chequea HEARTBEAT.md
        # y escribe a Discord SOLO si hay novedad (HEARTBEAT_OK = silencio).
        # lightContext = contexto minimo, costo por ping ~$0.002.
        agents.defaults.heartbeat = {
          every = "45m";
          activeHours = {
            start = "07:00";
            end = "23:30";
            timezone = "America/Panama";
          };
          lightContext = true;
        };

        # Skills reactivadas con descripciones SANITIZADAS (2026-10-08): las
        # descriptions viajan al system prompt de CADA mensaje; las originales
        # (injection/attack/OWASP/XSS) hacian que el moderador de DashScope
        # rechazara todo (DataInspectionFailed). Los cuerpos se leen solo bajo
        # demanda; si al activar una de security fallara el filtro, recortar
        # ese cuerpo o sacarla del indice.
        skills.load.extraDirs = [ (toString ./openclaw/skills) ];
      };
    };

    # Herramientas del sandbox (además del toolchain interno del paquete:
    # node, pnpm, git, curl, jq, python3, ripgrep...). gh/bun/wrangler para
    # que opere los mismos proyectos que Ricky, openssh para su clave propia.
    # Generadores de PDF a elección del agente: typst (documentos nativos,
    # liviano) y weasyprint (HTML/CSS a PDF, mismo motor de la web cotiza).
    home.packages = with pkgs; [
      gh
      bun
      openssh
      wrangler
      typst
      (python3.withPackages (ps: [ ps.weasyprint ]))
    ];

    # Identidad git propia (commits atribuibles al bot, no a Ricky).
    programs.git = {
      enable = true;
      settings.user.name = "openclaw-bot";
      settings.user.email = "openclaw@localhost";
    };

    home.stateVersion = "26.05";
  };
}

# --- Setup de secretos (una sola vez, en tu terminal) ---
#   sudo mkdir -p /etc/openclaw
#   echo "sk-TU-KEY-DEEPSEEK" | sudo tee /etc/openclaw/deepseek-key  >/dev/null
#   echo "bot-token..."   | sudo tee /etc/openclaw/discord-token   >/dev/null
#   openssl rand -hex 32  | sudo tee /etc/openclaw/gateway-token   >/dev/null
#   echo "github_pat_..." | sudo tee /etc/openclaw/gh-token        >/dev/null
#   echo "cf-..."         | sudo tee /etc/openclaw/cf-token        >/dev/null
#   sudo chown root:openclaw /etc/openclaw/* && sudo chmod 640 /etc/openclaw/*
#
# Despues del primer rebuild, generar la clave SSH del bot y registrarla:
#   sudo -u openclaw ssh-keygen -t ed25519 -f /var/lib/openclaw/.ssh/id_ed25519 -N ""
#   sudo cat /var/lib/openclaw/.ssh/id_ed25519.pub   # -> agregar a GitHub (Settings -> SSH keys)

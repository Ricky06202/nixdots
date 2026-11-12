{ config, pkgs, lib, hostName ? "laptop", cliAw, ... }:

{
  # Caelestia: usar ~/Imágenes/wallpapers como carpeta de fondos
  home.sessionVariables = {
    CAELESTIA_WALLPAPERS_DIR = "$HOME/Imágenes/wallpapers";
    GTK_THEME = "Colloid-Dark";
    QT_IM_MODULE = "xim";
    XMODIFIERS = "@im=none";
    GTK_IM_MODULE = "xim";
    # Editor por defecto = Zed (GUI). --wait lo hace síncrono para git commit.
    # OJO: requiere sesión gráfica; en TTY puro exportate EDITOR=nvim a mano.
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
  };

  # core.editor manda sobre EDITOR para todo lo que pase por git.
  programs.git = {
    enable = true;
    settings = {
      core.editor = "zed --wait";
    };
  };

  # ~/.local/bin en PATH (para nini y otros scripts locales)
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Config de Caelestia. Se instalan como archivos REALES (editables)
  # porque Caelestia los escribe en runtime; un symlink de home-manager
  # causaría "Failed to write config".
  # idle.timeouts VACIO: la pantalla ya NO se apaga ni bloquea sola. Antes
  # tenia lock(3m)+dpms(5m); apagar por inactividad era molesto (leer sin
  # teclear = pantalla negra). Ahora la pantalla solo se apaga al bloquear a
  # mano (SUPER+L -> lock-screen.sh: lock + dpms off tras 3s). Suspend e
  # hibernate quedan manuales (menu de sesion o "apaga la PC" por Discord).
  home.activation.writeCaelestiaConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/caelestia"
    cat > "$HOME/.config/caelestia/shell.json" << 'CAEL_EOF'
{
  "services": {
    "useTwelveHourClock": false
  },
  "bar": {
    "clock": {
      "showDate": true
    }
  },
  "general": {
    "idle": {
      "lockBeforeSleep": true,
      "inhibitWhenAudio": true,
      "timeouts": []
    }
  }
}
CAEL_EOF

    if [ ! -f "$HOME/.config/caelestia/cli.json" ]; then
      printf '{"theme":{"enableGtk":false}}\n' > "$HOME/.config/caelestia/cli.json"
    fi

    mkdir -p "$HOME/.config/xsettingsd"
    cat > "$HOME/.config/xsettingsd/xsettingsd.conf" << 'XS_EOF'
Gtk/ThemeName "Colloid-Dark"
Gtk/IconThemeName "Colloid-Dark"
Gtk/CursorThemeName "Bibata-Modern-Classic"
Net/ThemeName "Colloid-Dark"
Net/IconThemeName "Colloid-Dark"
XS_EOF
  '';

  # nini — crear directorio de config y placeholder de API key
  home.activation.writeNiniConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/nini"
    if [ ! -f "$HOME/.config/nini/api.key" ]; then
      echo "# pega tu API key de DeepSeek aqui (una linea)" > "$HOME/.config/nini/api.key"
      chmod 600 "$HOME/.config/nini/api.key"
    fi
  '';

  # RustDesk — keyboard layout fix. Se escribe SOLO la primera vez (si falta):
  # RustDesk guarda aquí sus dispositivos recientes/remembered y un rebuild
  # sobrescribiéndolo los borraría.
  home.activation.writeRustDeskConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/rustdesk"
    if [ ! -f "$HOME/.config/rustdesk/RustDesk_local.toml" ]; then
      cat > "$HOME/.config/rustdesk/RustDesk_local.toml" << 'RUSTEOF'
remote_id =
kb_layout_type = universal
size = [0, 0, 1826, 1036]
fav = []

[options]

[ui_flutter]
RUSTEOF
    fi
  '';

  # Programa zellij
  programs.zellij = {
    enable = true;
    enableBashIntegration = true;
  };

  # Config de wezterm
  xdg.configFile."wezterm/wezterm.lua".source = ./dotfiles/wezterm.lua;

  # Config de zellij
  xdg.configFile."zellij/config.kdl" = {
    source = ./dotfiles/zellij/config.kdl;
    force = true;
  };

  # Zsh con plugins (shell moderno)
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    # oh-my-zsh: framework con plugins útiles y completion case-insensitive.
    # Sin theme para conservar el prompt custom. Highlight/autosuggest/zoxide
    # ya están activos por home-manager aparte (no duplicar como plugins).
    oh-my-zsh = {
      enable = true;
      theme = "";
      plugins = [
        "git"              # aliases de git (gst, gco, gd...)
        "sudo"             # ESC ESC antepone sudo al comando anterior
        "extract"          # `extract archivo.*` descomprime cualquier formato
        "colored-man-pages" # man pages con colores
        "dirhistory"       # Alt+flechas para navegar historial de directorios
        "jsontools"        # pipes JSON: pp_json, is_json, urlencode_json...
        "copypath"         # copia la ruta del cwd al portapapeles
      ];
    };
    shellAliases = {
      # NOTA: NO poner alias `z` aqui — pisaria la funcion z de zoxide
      # (`zoxide init zsh` abajo), que es la que SI hace el salto de directorio.
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline";
      ls = "ls --color=auto";
      ll = "ls -la";
      nv = "nvim";
      # update: avanza el lock a lo mas nuevo Y reconstruye el sistema
      update = "cd /home/ricky/Dev/nixdots && nix flake update && sudo nixos-rebuild switch --flake /home/ricky/Dev/nixdots#${hostName}";
      # upgrade: solo reconstruye con el lock actual (sin actualizar inputs)
      upgrade = "sudo nixos-rebuild switch --flake /home/ricky/Dev/nixdots#${hostName}";
    };
    initContent = ''
      # zoxide: z (saltar a directorios frecuentes)
      eval "$(zoxide init zsh)"
      # fzf
      eval "$(fzf --zsh)"

      # ytdl: wrapper de yt-dlp (el "spotdl" de YouTube).
      #   ytdl <url>                     -> mejor video+audio a ~/Downloads
      #   ytdl "ytsearch5:query"        -> los 5 primeros resultados de una busqueda
      #   ytdl --mp3 <url>              -> solo audio en MP3 (mismo flujo que spotdl)
      #   ytdl --subs <url>             -> ademas descarga subtitulos (es/en)
      # Si YouTube responde "Sign in to confirm you're not a bot", usar
      # `ytdl --cookies-from-browser librewolf <url>`.
      ytdl() {
        local fmt="bv*+ba/b" extra=()
        while [[ "$1" == "--mp3" || "$1" == "--subs" ]]; do
          case "$1" in
            --mp3)
              fmt="bestaudio/best"
              extra+=( -x --audio-format mp3 --audio-quality 0 --embed-thumbnail )
              ;;
            --subs)
              # OJO: el endpoint de subtitulos de YouTube (timedtext) se
              # rate-limita aparte y devuelve 429 con facilidad; en esta version
              # ese error es FATAL y cancela el video entero. Por eso los subs
              # son opt-in y no el default.
              extra+=( --write-subs --write-auto-subs
                       --sub-langs "es.*,en.*,es-orig,en-orig" --embed-subs )
              ;;
          esac
          shift
        done
        command yt-dlp \
          -f "$fmt" \
          ''${extra[@]} \
          --merge-output-format mkv \
          -o "$HOME/Downloads/%(uploader,artist)s - %(title).180B [%(id)s].%(ext)s" \
          --embed-metadata --embed-thumbnail --embed-chapters \
          --no-overwrites \
          --sleep-requests 1 --sleep-interval 5 \
          --retries 10 --fragment-retries 10 --extractor-retries 3 \
          --retry-sleep "http:exp=1:20" --retry-sleep "extractor:exp=1:10" \
          "$@"
      }
      # Prompt personalizado
      export PROMPT='%F{cyan}%n@%m%f:%F{green}%~%f %F{yellow}❯%f '
      export RPROMPT='%(?.%F{green}✓.%F{red}✗)%f'
    '';
  };

  # Paquetes del shell
  home.packages = with pkgs; [
    cliAw # CLI de Caelestia (colores/material-you/wallpapers) para scripts externos
    zoxide
    fzf
    ripgrep
    xdg-desktop-portal # portal principal (captura de pantalla/ventana)
    xdg-desktop-portal-hyprland # implementación de captura para Hyprland
    freecad # CAD 3D paramétrico
    yt-dlp # descarga de YouTube (y 1000 sitios más); el wrapper `ytdl` de .zshrc lo endulza
    feishin # cliente de escritorio para Navidrome/Subsonic (Jellyfin de música)
    libnotify # notify-send para la acción "Montar imagen" de Nemo y scripts
    dconf   # necesario para forzar tema GTK en home.activation
    zenity  # diálogos para "Extraer RAR"
  ];

  # Config de Nemo (file manager): sort por fecha descendente, sin carpetas primero
  dconf.settings = {
    "org/nemo/preferences" = {
      "sort-directories-first" = false;
      "sort-favorites-first" = false;
      "default-sort-column" = "mtime";
      "default-sort-order" = "reverse";
    };
  };

  home.activation.nemoBookmarks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    bookmarks="$HOME/.config/gtk-3.0/bookmarks"
    if [ -L "$bookmarks" ] || [ ! -e "$bookmarks" ]; then
      mkdir -p "$(dirname "$bookmarks")"
      rm -f "$bookmarks"
      cat > "$bookmarks" <<'EOF'
file:///home/ricky/Downloads Downloads
file:///home/ricky/Documents Documents
file:///home/ricky/Dev Dev
file:///home/ricky/Games Games
file:///mnt/flix Flix
file:///mnt/familia Familia
EOF
    fi
  '';

  # Aplicaciones predeterminadas: sin esto, xdg-open agarra al primer .desktop
  # que se registra (VSCode abre carpetas, PrismLauncher los zip, Librewolf las imágenes).
  # Zed es el editor por defecto: el comodin text/* lo elige para TODO texto/código
  # (Zed solo declara text/plain en su .desktop; sin comodin los .py/.nix/.md caían
  # en VSCode por orden de registro). Las claves exactas (text/html=Librewolf)
  # ganan al comodin, asi el navegador no se ve afectado.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Navegador por defecto → Librewolf (el "principal" del repo). Sin estas
      # 3 claves xdg-open agarra el primer .desktop con x-scheme-handler que
      # encuentra en el perfil (antes cayó en chromium por accidente).
      "x-scheme-handler/http" = [ "librewolf.desktop" ];
      "x-scheme-handler/https" = [ "librewolf.desktop" ];
      "text/html" = [ "librewolf.desktop" ];
      # Archivos/carpetas
      "inode/directory" = [ "nemo.desktop" ];
      # Texto y código → Zed (comodin: cubre .py .js .md .nix .toml, etc)
      "text/*" = [ "dev.zed.Zed.desktop" ];
      "application/json" = [ "dev.zed.Zed.desktop" ];
      # Imágenes → Loupe
      "image/png" = [ "org.gnome.Loupe.desktop" ];
      "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
      "image/gif" = [ "org.gnome.Loupe.desktop" ];
      "image/webp" = [ "org.gnome.Loupe.desktop" ];
      "image/svg+xml" = [ "org.gnome.Loupe.desktop" ];
      # PDFs → Okular
      "application/pdf" = [ "org.kde.okular.desktop" ];
      # Documentos de oficina → LibreOffice (por familia: writer/calc/impress)
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "libreoffice-writer.desktop" ];
      "application/msword" = [ "libreoffice-writer.desktop" ];
      "application/rtf" = [ "libreoffice-writer.desktop" ];
      "application/vnd.oasis.opendocument.text" = [ "libreoffice-writer.desktop" ];
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = [ "libreoffice-calc.desktop" ];
      "application/vnd.ms-excel" = [ "libreoffice-calc.desktop" ];
      "application/vnd.oasis.opendocument.spreadsheet" = [ "libreoffice-calc.desktop" ];
      "text/csv" = [ "libreoffice-calc.desktop" ];
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = [ "libreoffice-impress.desktop" ];
      "application/vnd.ms-powerpoint" = [ "libreoffice-impress.desktop" ];
      "application/vnd.oasis.opendocument.presentation" = [ "libreoffice-impress.desktop" ];
      # Modelos 3D → F3D. Los .desktop "plugin" son los que declaran MimeType
      # (el f3d.desktop pelado no trae ninguno); el plugin importa el formato:
      # native = mallas (stl/obj/ply/gltf), assimp = 3mf/fbx/dae/off, occt =
      # CAD (step/iges/brep), usd = usd/usdz. .FCStd se deja en FreeCAD.
      "model/stl" = [ "f3d-plugin-native.desktop" ];
      "model/obj" = [ "f3d-plugin-native.desktop" ];
      "application/vnd.ply" = [ "f3d-plugin-native.desktop" ];
      "model/gltf-binary" = [ "f3d-plugin-native.desktop" ];
      "model/gltf+json" = [ "f3d-plugin-native.desktop" ];
      "application/vnd.3ds" = [ "f3d-plugin-native.desktop" ];
      "application/vnd.vtk" = [ "f3d-plugin-native.desktop" ];
      "model/vrml" = [ "f3d-plugin-native.desktop" ];
      "model/3mf" = [ "f3d-plugin-assimp.desktop" ];
      "application/vnd.fbx" = [ "f3d-plugin-assimp.desktop" ];
      "application/vnd.dae" = [ "f3d-plugin-assimp.desktop" ];
      "application/vnd.off" = [ "f3d-plugin-assimp.desktop" ];
      "image/vnd.dxf" = [ "f3d-plugin-assimp.desktop" ];
      "model/step" = [ "f3d-plugin-occt.desktop" ];
      "application/vnd.step" = [ "f3d-plugin-occt.desktop" ];
      "model/iges" = [ "f3d-plugin-occt.desktop" ];
      "application/vnd.brep" = [ "f3d-plugin-occt.desktop" ];
      "application/vnd.usd" = [ "f3d-plugin-usd.desktop" ];
      "model/vnd.usda" = [ "f3d-plugin-usd.desktop" ];
      "model/vnd.usdz+zip" = [ "f3d-plugin-usd.desktop" ];
      # Comprimidos → File Roller (y "Extraer aquí" de Nemo)
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/gzip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/vnd.rar" = [ "org.gnome.FileRoller.desktop" ];
      # Ejecutables Windows (.exe) → Wine
      "application/x-msdownload" = [ "wine.desktop" ];
      "application/vnd.microsoft.portable-executable" = [ "wine.desktop" ];
      "application/x-ms-dos-executable" = [ "wine.desktop" ];
      # Video/Audio → mpv
      "video/mp4" = [ "mpv.desktop" ];
      "video/x-matroska" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "audio/mpeg" = [ "mpv.desktop" ];
      "audio/mp4" = [ "mpv.desktop" ];
    };
  };

  # Acceso directo "Abrir con Wine" para ejecutar .exe con doble clic.
  xdg.desktopEntries.wine = {
    name = "Wine";
    comment = "Ejecuta programas de Windows";
    exec = "wine %f";
    icon = "wine";
    categories = [ "Utility" ];
    mimeType = [
      "application/x-msdownload"
      "application/vnd.microsoft.portable-executable"
      "application/x-ms-dos-executable"
    ];
    terminal = false;
  };

  # Acceso directo "Abrir con Proton" para ejecutar .exe con el Proton de Steam.
  xdg.desktopEntries.proton = {
    name = "Proton";
    comment = "Ejecuta programas de Windows con el Proton de Steam";
    exec = "proton-run %f";
    icon = "steam";
    categories = [ "Utility" ];
    mimeType = [
      "application/x-msdownload"
      "application/vnd.microsoft.portable-executable"
      "application/x-ms-dos-executable"
    ];
    terminal = false;
  };

  home.file.".local/bin/proton-run" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      export PATH="${pkgs.python3}/bin:$PATH"

      if [ "$#" -lt 1 ]; then
        echo "Uso: proton-run archivo.exe [args]" >&2
        exit 1
      fi

      exe="$1"
      shift
      if [ ! -f "$exe" ]; then
        echo "No existe: $exe" >&2
        exit 1
      fi

      steam="$HOME/.steam/steam"
      if [ -x "$steam/steamapps/common/Proton - Experimental/proton" ]; then
        proton="$steam/steamapps/common/Proton - Experimental/proton"
      elif [ -x "$steam/steamapps/common/Proton 9.0 (Beta)/proton" ]; then
        proton="$steam/steamapps/common/Proton 9.0 (Beta)/proton"
      else
        echo "No encontré Proton en $steam/steamapps/common" >&2
        exit 1
      fi

      base="$(basename "$exe")"
      prefix="$HOME/.local/share/proton-prefixes/''${base%.*}"
      mkdir -p "$prefix"

      export STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam"
      export STEAM_COMPAT_DATA_PATH="$prefix"
      export SteamAppId=0
      export SteamGameId=0

      exec "$HOME/.config/hypr/game-us.sh" "$proton" run "$exe" "$@"
    '';
  };

  home.file.".local/share/nemo/actions/proton-run.nemo_action" = {
    text = ''
      [Nemo Action]
      Name=Ejecutar con Proton
      Comment=Ejecutar .exe con el Proton de Steam
      Exec=proton-run %F
      Icon-Name=steam
      Selection=s
      Extensions=exe;msi;bat;cmd;
      Quote=double
    '';
  };

  home.file.".local/bin/rar-extract" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      if [ "$#" -lt 1 ]; then
        echo "Uso: rar-extract archivo.rar" >&2
        exit 1
      fi

      archive="$1"
      if [ ! -f "$archive" ]; then
        zenity --error --text="No existe: $archive"
        exit 1
      fi

      password="$(zenity --password --title="Contraseña del RAR")" || exit 1
      dest="$(dirname "$archive")/$(basename "$archive" .rar)"
      mkdir -p "$dest"

      if unrar x -p"$password" "$archive" "$dest/" >/tmp/rar-extract.log 2>&1; then
        zenity --info --text="Extraído en:\n$dest"
      else
        zenity --error --text="No se pudo extraer:\n$(tail -n 20 /tmp/rar-extract.log)"
      fi
    '';
  };

  home.file.".local/share/nemo/actions/rar-extract.nemo_action" = {
    text = ''
      [Nemo Action]
      Name=Extraer RAR
      Comment=Extrae un RAR pidiendo la contraseña
      Exec=rar-extract %F
      Icon-Name=package-x-generic
      Selection=s
      Extensions=rar;
      Quote=double
    '';
  };

  # Config de Hyprland (force: sobrescribe los archivos manuales existentes).
  # La cabecera de monitores es POR HOST: en amd los puertos del laptop
  # (HDMI-A-2/eDP-1) no existen y rompen el arranque. El cuerpo de
  # hyprland.lua es compartido y no debe declarar monitores.
  xdg.configFile."hypr/hyprland.lua" = {
    text = ''
      ${builtins.readFile ./dotfiles/hypr/${if hostName == "amd" then "monitors-amd.lua" else "monitors-laptop.lua"}}

      ${builtins.readFile ./dotfiles/hypr/hyprland.lua}
    '';
    force = true;
  };

  # MangoHUD: overlay de rendimiento con FPS limit a 30 (reduce calor)
  xdg.configFile."MangoHUD/MangoHUD.conf" = {
    source = if hostName == "laptop" then ./dotfiles/mangohud/MangoHUD-laptop.conf else ./dotfiles/mangohud/MangoHUD-amd.conf;
    force = true;
  };

  # Tema GTK (Colloid-dark en vez de adw-gtk3-dark que ignora CSS custom)
  gtk = {
    enable = true;
    theme = {
      name = "Colloid-Dark";
      package = pkgs.colloid-gtk-theme;
    };
    iconTheme = {
      name = "Colloid-Dark";
      package = pkgs.colloid-gtk-theme;
    };
    font = {
      name = "Sans";
      size = 11;
    };
  };
  xdg.configFile."hypr/hyprland.conf" = {
    source = ./dotfiles/hypr/hyprland.conf;
    force = true;
  };
  xdg.configFile."hypr/hypridle.conf" = {
    source = ./dotfiles/hypr/hypridle.conf;
    force = true;
  };
  xdg.configFile."hypr/hyprlock.conf" = {
    source = ./dotfiles/hypr/hyprlock.conf;
    force = true;
  };
  xdg.configFile."hypr/hyprpaper.conf" = {
    source = ./dotfiles/hypr/hyprpaper.conf;
    force = true;
  };

  # Wallpapers versionados (carpeta entera): los estáticos que Caelestia bajó
  # por ID (~/Imágenes/wallpapers) y el live wallpaper mp4. Se declaran en el
  # repo para no perderlos al reinstalar; home-manager los hace symlinks al
  # store. Para añadir más solo hay que copiarlos a ./assets/wallpapers/
  # (añadir archivos nuevos en la carpeta lanza el rebuild sin tocar la config).
  home.file."Imágenes/wallpapers" = {
    source = ./assets/wallpapers;
    force = true;
  };

  # Scripts de Hyprland
  home.file.".config/hypr/autostart.sh" = {
    source = ./dotfiles/hypr/autostart.sh;
    executable = true;
    force = true;
  };
  # session-action.sh: lo enlazan los binds SUPER+CTRL+ESC / SUPER+CTRL+R de
  # hyprland.lua (poweroff/reboot). NO quitar el registro o los binds quedan
  # apuntando a un archivo inexistente.
  home.file.".config/hypr/session-action.sh" = {
    source = ./dotfiles/hypr/session-action.sh;
    executable = true;
    force = true;
  };
  # headless-setup.sh: crea HEADLESS-1 al iniciar la sesion (lo ejecuta el
  # exec_cmd de monitors-amd.lua). Sin registro, el monitor fantasma de
  # Moonlight no aparece tras un boot limpio.
  home.file.".config/hypr/headless-setup.sh" = {
    source = ./dotfiles/hypr/headless-setup.sh;
    executable = true;
    force = true;
  };
  home.file.".config/hypr/warmup.sh" = {
    source = ./dotfiles/hypr/warmup.sh;
    executable = true;
    force = true;
  };
  home.file.".config/hypr/monitor-watch.sh" = {
    source = ./dotfiles/hypr/monitor-watch.sh;
    executable = true;
    force = true;
  };
  home.file.".config/hypr/wallpaper-pick.sh" = {
    source = ./dotfiles/hypr/wallpaper-pick.sh;
    executable = true;
    force = true;
  };
  home.file.".config/hypr/rotate-wallpaper.sh" = {
    source = ./dotfiles/hypr/rotate-wallpaper.sh;
    executable = true;
    force = true;
  };
  home.file.".config/hypr/lock-screen.sh" = {
    source = ./dotfiles/hypr/lock-screen.sh;
    executable = true;
    force = true;
  };
  home.file.".config/hypr/game-us.sh" = {
    source = ./dotfiles/hypr/game-us.sh;
    executable = true;
    force = true;
  };
  home.file.".config/hypr/steam-launcher.sh" = {
    source = ./dotfiles/hypr/steam-launcher.sh;
    executable = true;
    force = true;
  };
  home.file.".local/bin/nini" = {
    source = ./scripts/nini;
    executable = true;
    force = true;
  };

  # Entorno de OpenCode por completo — config, instrucciones globales, agente,
  # comando y skills. EL CONTEXTO que opencode carga en cada chat nuevo vive aquí
  # (repo público, sin secretos). La API key NO va aquí: se guarda aparte en
  # ~/.local/share/opencode/auth.json (secreto, local).
  home.file.".config/opencode/opencode.jsonc" = {
    source = ./dotfiles/opencode/opencode.jsonc;
    force = true;
  };
  home.file.".config/opencode/INSTRUCTIONS.md" = {
    source = ./dotfiles/opencode/INSTRUCTIONS.md;
    force = true;
  };
  home.file.".config/opencode/agent/nixos.md" = {
    source = ./dotfiles/opencode/agent/nixos.md;
    force = true;
  };
  home.file.".config/opencode/command/rebuild.md" = {
    source = ./dotfiles/opencode/command/rebuild.md;
    force = true;
  };
  # Script que disparan los timers de recordatorios (skill `memory`).
  # La DATA de la memoria (~/.config/opencode/memory/) NO se declara aquí:
  # es personal y sobrevive rebuilds intacta.
  home.file.".local/bin/reminder-fire.sh" = {
    source = ./dotfiles/opencode/scripts/reminder-fire.sh;
    executable = true;
    force = true;
  };

  # Skills de OpenCode — todas las del repo se despliegan (públicas, sin secretos).
  home.file.".config/opencode/skills" = {
    source = ./dotfiles/opencode/skills;
    recursive = true;
    force = true;
  };

  home.stateVersion = "26.05";

  # Rotación automática de wallpaper cada hora (con jitter ±15 min para no
  # ser mecánico). Importa el entorno de Hyprland vía el wrapper y recarga
  # Caelestia + WezTerm en caliente (el watch del scheme corre dentro de wezterm).
  systemd.user.services."rotate-wallpaper" = {
    Unit.Description = "Rota el wallpaper de Caelestia";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${./dotfiles/hypr/rotate-wallpaper.sh}";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.timers."rotate-wallpaper" = {
    Unit.Description = "Timer de rotación de wallpaper";
    Timer = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "15min";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Quitado todo el extra de suspend/resume de esta sesion:
#  - la unidad systemd "caelestia-resume" (disparaba al entrar en suspend, no
#    al resume, y mataba el shell a mitad de suspension)
#  - el script/manual "reshell" (era pasivo, no toca suspend, pero se retira
#    para volver de lleno al sistema tal como estaba).
# El freeze al despertar NO es un bug de firmware de la placa: el journal si
# tiene los logs. Es el MODE1 reset que amdgpu hace en cada resume de s2idle
# (soc21_need_reset_on_resume => "S3 suspend aborted, resetting..."), que
# aquamarine no re-adquiere => CRTC congelada en el framebuffer viejo. Se
# auto-cura con el unit "amdgpu-resume-heal" de hosts/amd/configuration.nix,
# asi que aqui no hace falta ninguna pieza extra de suspend/resume.
}

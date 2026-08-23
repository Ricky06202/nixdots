{ config, pkgs, lib, hostName ? "laptop", ... }:

{
  # Caelestia: usar ~/Imágenes/wallpapers como carpeta de fondos
  home.sessionVariables = {
    CAELESTIA_WALLPAPERS_DIR = "$HOME/Imágenes/wallpapers";
    GTK_THEME = "Colloid-Dark";
    QT_IM_MODULE = "xim";
    XMODIFIERS = "@im=none";
    GTK_IM_MODULE = "xim";
  };

  # ~/.local/bin en PATH (para nini y otros scripts locales)
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Config de Caelestia. Se instalan como archivos REALES (editables)
  # porque Caelestia los escribe en runtime; un symlink de home-manager
  # causaría "Failed to write config".
  home.activation.writeCaelestiaConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/caelestia"
    cat > "$HOME/.config/caelestia/shell.json" << 'CAEL_EOF'
{
  "services": {
    "useTwelveHourClock": false
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

  # RustDesk — keyboard layout fix
  home.activation.writeRustDeskConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/rustdesk"
    cat > "$HOME/.config/rustdesk/RustDesk_local.toml" << 'RUSTEOF'
remote_id =
kb_layout_type = universal
size = [0, 0, 1826, 1036]
fav = []

[options]

[ui_flutter]
RUSTEOF
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
      update = "sudo nixos-rebuild switch --flake /home/ricky/Dev/nixdots#${hostName}";
    } // (lib.optionalAttrs (hostName == "laptop") {
      # NVIDIA PRIME: steam y lutris usan la GPU dedicada automáticamente
      steam = "nvidia-offload steam";
      lutris = "nvidia-offload lutris";
    });
    initContent = ''
      # zoxide: z (saltar a directorios frecuentes)
      eval "$(zoxide init zsh)"
      # fzf
      eval "$(fzf --zsh)"
      # Prompt personalizado
      export PROMPT='%F{cyan}%n@%m%f:%F{green}%~%f %F{yellow}❯%f '
      export RPROMPT='%(?.%F{green}✓.%F{red}✗)%f'
    '';
  };

  # Paquetes del shell
  home.packages = with pkgs; [
    zoxide
    fzf
    ripgrep
    xdg-desktop-portal # portal principal (captura de pantalla/ventana)
    xdg-desktop-portal-hyprland # implementación de captura para Hyprland
    shotcut # editor de video para clips/shorts
    chatterino2 # cliente ligero de chat de Twitch (sin navegador)
    dconf   # necesario para forzar tema GTK en home.activation
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

  # Config de Hyprland (force: sobrescribe los archivos manuales existentes)
  xdg.configFile."hypr/hyprland.lua" = {
    source = ./dotfiles/hypr/hyprland.lua;
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

  # Scripts de Hyprland
  home.file.".config/hypr/autostart.sh" = {
    source = ./dotfiles/hypr/autostart.sh;
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
  home.file.".config/hypr/steam-launcher.sh" = {
    source = ./dotfiles/hypr/steam-launcher.sh;
    executable = true;
    force = true;
  };
  home.file.".config/hypr/nvidia-detect.sh" = lib.mkIf (hostName == "laptop") {
    source = ./dotfiles/hypr/nvidia-detect.sh;
    executable = true;
    force = true;
  };

  # nini — DeepSeek CLI para NixOS/Hyprland
  home.file.".local/bin/nini" = {
    source = ./scripts/nini;
    executable = true;
    force = true;
  };

  home.stateVersion = "26.05";
}

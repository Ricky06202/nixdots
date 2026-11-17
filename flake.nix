{
  description = "Config NixOS multi-host de Ricky (laptop + amd + omen)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # m3shapes: dependencia QML de Caelestia (flake=false). Declarada aquí para
    # fijar la revisión una sola vez y compartirla vía follows.
    m3shapes = {
      url = "github:soramanew/m3shapes";
      flake = false;
    };

    # --- Caelestia ---
    # El flake oficial compila quickshell desde git master de outfoxxed
    # (~1h local, sin caché binaria pública). No usamos sus packages.*:
    # armamos el shell nosotros en outputs con el quickshell de nixpkgs
    # (precompilado) → ver caelestiaShell.
    caelestia.url = "github:caelestia-dots/shell";
    caelestia.inputs.m3shapes.follows = "m3shapes";
    # OJO: su input quickshell queda declarado pero NUNCA se usa/compila
    # (no referenciamos caelestia.packages.*; armamos el shell más abajo).

    caelestia-cli.url = "github:caelestia-dots/cli";
    # Su input caelestia-shell solo se usa en el paquete with-shell (que no
    # usamos); no dispara ninguna compilación de quickshell extra.

    # --- Caelestia-AW (live wallpapers) ---
    # Forks de AdiAmbassador que añaden soporte nativo de wallpaper animado
    # (VideoOutput/MediaPlayer en QtMultimedia) al shell y al CLI.
    # AMBOS hosts usan el fork AW: es un superconjunto de vanilla (con estático
    # se comporta idéntico) y el vídeo solo carga al seleccionarlo en el launcher.
    # OJO: el fork está en "v2.3.0 compatible" (detrás de master vanilla, ej.
    # NetworkUsage sigue en QML) y su instalador es Arch-only (patch.sh), pero
    # su packaging nix/default.nix es compatible con nuestro qsPrebuilt: solo
    # hay que inyectarle qt6.qtmultimedia (no lo declara) y usar su CLI fork
    # (pillow + ffmpeg). Ver caelestiaShellAW en outputs.
    caelestia-aw = {
      url = "github:AdiAmbassador/caelestia-shell-aw";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.m3shapes.follows = "m3shapes";
      # No usamos sus packages.* (compilarían quickshell-git ~1h); solo
      # callPackage sobre su /nix. Desactivamos sus inputs para no arrastrar
      # lock de quickshell/outfoxxed ni de caelestia-cli vanilla.
      inputs.quickshell.follows = "";
      inputs.caelestia-cli.follows = "";
    };
    caelestia-cli-aw.url = "github:AdiAmbassador/caelestia-cli-aw";
    caelestia-cli-aw.inputs.nixpkgs.follows = "nixpkgs";
    caelestia-cli-aw.inputs.caelestia-shell.follows = "";

    # SpotX-Nix: parchea Spotify para bloquear anuncios (declarativo, NixOS-native).
    spotx-nix.url = "github:SpotX-Official/SpotX-Nix";

  };

  outputs = { self, nixpkgs, caelestia, m3shapes, caelestia-cli, home-manager, spotx-nix, caelestia-aw, caelestia-cli-aw }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # Paquete oficial propietario aislado del set libre por defecto.
      pkgsUnfree = import nixpkgs.outPath {
        inherit system;
        config.allowUnfree = true;
      };

      # CLI de Caelestia (fork AW: pillow + thumbnails por ffmpeg). Se expone
      # además como paquete del usuario para scripts exteriores (p.ej.
      # wallpaper-pick.sh) sin depender del PATH del wrapper del shell.
      cliAw =
        caelestia-cli-aw.packages.${system}.default.overrideAttrs (old: {
          patchPhase = (old.patchPhase or "") + ''
            substituteInPlace pyproject.toml \
              --replace-fail 'dynamic = ["version"]' 'version = "1"'
            sed -i '/^\[tool\.hatch\.version\]$/,/^source = "vcs"$/d' pyproject.toml
          '';
        });
      m3shapesPkg = pkgs.callPackage "${m3shapes}/nix" { stdenv = pkgs.clangStdenv; };

      # Quickshell precompilado de nixpkgs (+ módulos QML extra).
      # Replica el wrapper del flake oficial de outfoxxed, incluyendo su
      # passthru `withModules`: se copia el binario ya compilado y
      # wrapQtAppsHook registra los módulos QML de buildInputs.
      # Cero compilación de C++.
      qsPrebuilt =
        let
          mkQs = modules:
            pkgs.stdenv.mkDerivation {
              pname = "quickshell-prebuilt";
              inherit (pkgs.quickshell) version;
              nativeBuildInputs = [ pkgs.qt6.wrapQtAppsHook ];
              buildInputs = [ pkgs.quickshell ] ++ modules;
              dontUnpack = true;
              dontConfigure = true;
              dontBuild = true;
              installPhase = ''
                mkdir -p $out
                cp -r ${pkgs.quickshell}/* $out/
              '';
              passthru = {
                unwrapped = pkgs.quickshell;
                withModules = more: mkQs (modules ++ more);
              };
            };
        in
          mkQs [ ];

      # Caelestia-AW: fork con live wallpapers (video .mp4/.webm/etc.).
      # Mismo enfoque (wrapper qsPrebuilt), pero:
      #  - el wrapper quickshell lleva qt6.qtmultimedia (el fork NO lo declara,
      #    aunque VideoWallpaper.qml importa QtMultimedia)
      #  - CLI = fork caelestia-cli-aw (añade pillow + genera thumbnails con ffmpeg)
      #
      # Vanilla: sin parches postPatch (el fix #1814 del blur del lock screen
      # se retiró a petición; si Hyprland vuelve a crashear al despertar,
      # está en el git history — commit c96c840).
      caelestiaShellAW =
        let
          qsAw = qsPrebuilt.withModules [ pkgs.qt6.qtmultimedia ];
          base = (pkgs.callPackage "${caelestia-aw}/nix" {
            stdenv = pkgs.clangStdenv;
            m3shapes = m3shapesPkg;
            quickshell = qsAw;
            caelestia-cli = cliAw;
            rev = caelestia-aw.sourceInfo.rev or "unknown";
            # El CLI-AW genera thumbnails llamando ffmpeg por subprocess; el
            # wrapper del shell lo expone en su PATH (default.nix del fork no
            # lo añade por defecto).
            extraRuntimeDeps = [ pkgs.ffmpeg ];
          }).override { withCli = true; };
        in
          base.overrideAttrs (old: {
            # Botón "IA local" en la zona de estado (internet/batería/bluetooth).
            # El shell no admite entradas custom por config: sus elementos salen
            # de un DelegateChooser con ids fijos, así que hay que inyectar el
            # componente y su DelegateChoice en el QML instalado.
            # Si Caelestia cambia StatusIcons.qml, el substituteInPlace falla en
            # el build (no rompe en runtime): se ve enseguida.
            postInstall = (old.postInstall or "") + ''
              root=$out/share/caelestia-shell
              install -Dm644 ${./home/dotfiles/caelestia/AiToggle.qml} \
                "$root/modules/bar/components/AiToggle.qml"
              f="$root/modules/bar/components/StatusIcons.qml"
              # La lista de elementos cambió de nombre entre versiones
              # (`statusIcons.values` vs `.elements`): sed acepta las dos y el
              # grep de control hace fallar el build si ninguna matchea.
              sed -i -E \
                's/values: root\.Config\.bar\.statusIcons\.(values|elements)\.filter\(e => e\.enabled\)/values: [{ id: "ai", enabled: true }].concat(root.Config.bar.statusIcons.\1.filter(e => e.enabled))/' \
                "$f"
              grep -q 'id: "ai"' "$f" || {
                echo "AiToggle: no encontre la linea de valores en StatusIcons.qml" >&2
                exit 1
              }
              substituteInPlace "$f" --replace-fail '                    roleValue: "network"' '                    roleValue: "ai"
                    delegate: EntryWrapper {
                        AiToggle {
                            colour: root.colour
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "network"'
              grep -q 'roleValue: "ai"' "$f" || {
                echo "AiToggle: no pude insertar el DelegateChoice ai" >&2
                exit 1
              }
            '';
          });


      mkHost = name: nixpkgs.lib.nixosSystem {
        inherit system;
        # Ambos hosts usan el fork AW (live wallpapers). Es un superconjunto de
        # vanilla: con wallpaper estático (default) se comporta idéntico, y el
        # vídeo solo carga MediaPlayer cuando se selecciona uno en el launcher.
        specialArgs = { inherit caelestiaShellAW spotx-nix; hostName = name; };
        modules = [
          ./hosts/${name}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = { hostName = name; inherit cliAw; };
            home-manager.users.ricky = import ./home;
          }
        ];
      };
    in
    {
      # Paquetes standalone para probar/distribuir sin rebuild de host.
      # (El vanilla fue eliminado: el callPackage ${caelestia}/nix rompió contra
      #  qsPrebuilt tras update del input y NINGUN host lo usa - todos van por AW.)
      packages.${system} = {
        caelestia-shell-aw = caelestiaShellAW;
        chatgpt-official = pkgsUnfree.callPackage ./packages/chatgpt-official { pkgs = pkgsUnfree; };
      };

      nixosConfigurations.laptop = mkHost "laptop";
      nixosConfigurations.amd = mkHost "amd";
      nixosConfigurations.omen = mkHost "omen";
    };
}

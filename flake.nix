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
      # Mismo enfoque que caelestiaShell (qsPrebuilt), pero:
      #  - el wrapper quickshell lleva qt6.qtmultimedia (el fork NO lo declara,
      #    aunque VideoWallpaper.qml importa QtMultimedia)
      #  - CLI = fork caelestia-cli-aw (añade pillow + genera thumbnails con ffmpeg)
      caelestiaShellAW =
        let
          qsAw = qsPrebuilt.withModules [ pkgs.qt6.qtmultimedia ];
          cliAw = caelestia-cli-aw.packages.${system}.default;
        in
          (pkgs.callPackage "${caelestia-aw}/nix" {
            stdenv = pkgs.clangStdenv;
            inherit m3shapes;
            quickshell = qsAw;
            caelestia-cli = cliAw;
            rev = caelestia-aw.sourceInfo.rev or "unknown";
            # El CLI-AW genera thumbnails llamando ffmpeg por subprocess; el
            # wrapper del shell lo expone en su PATH (default.nix del fork no
            # lo añade por defecto).
            extraRuntimeDeps = [ pkgs.ffmpeg ];
          }).override { withCli = true; };

      # Caelestia shell usando nuestro quickshell precompilado.
      # Es el mismo callPackage ./nix del flake oficial; conCli incluye la CLI
      # de Caelestia (colores/material you/wallpapers) como runtime dep.
      caelestiaShell = (pkgs.callPackage "${caelestia}/nix" {
        stdenv = pkgs.clangStdenv;
        inherit m3shapes;
        quickshell = qsPrebuilt;
        caelestia-cli = caelestia-cli.packages.${system}.default;
        rev = caelestia.sourceInfo.rev or "unknown";
      }).override { withCli = true; };

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
            home-manager.extraSpecialArgs = { hostName = name; };
            home-manager.users.ricky = import ./home;
          }
        ];
      };
    in
    {
      # Paquetes standalone para probar/distribuir sin rebuild de host.
      # caelestia-shell = vanilla (referencia); caelestia-shell-aw = el de los
      # hosts (live wallpapers).
      packages.${system} = {
        caelestia-shell = caelestiaShell;
        caelestia-shell-aw = caelestiaShellAW;
      };

      nixosConfigurations.laptop = mkHost "laptop";
      nixosConfigurations.amd = mkHost "amd";
      nixosConfigurations.omen = mkHost "omen";
    };
}

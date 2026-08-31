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

    # SpotX-Nix: parchea Spotify para bloquear anuncios (declarativo, NixOS-native).
    spotx-nix.url = "github:SpotX-Official/SpotX-Nix";
  };

  outputs = { self, nixpkgs, caelestia, m3shapes, caelestia-cli, home-manager, spotx-nix }:
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
        specialArgs = { inherit caelestiaShell spotx-nix; hostName = name; };
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
      # Paquete standalone para probar sin rebuild completo:
      #   nix build .#caelestia-shell
      packages.${system}.caelestia-shell = caelestiaShell;

      nixosConfigurations.laptop = mkHost "laptop";
      nixosConfigurations.amd = mkHost "amd";
      nixosConfigurations.omen = mkHost "omen";
    };
}

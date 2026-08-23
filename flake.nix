{
  description = "Config NixOS multi-host de Ricky (laptop + amd)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    caelestia.url = "github:caelestia-dots/shell";
    caelestia-cli.url = "github:caelestia-dots/cli";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, caelestia, caelestia-cli, home-manager }:
    let
      system = "x86_64-linux";
      mkHost = name: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit caelestia caelestia-cli; hostName = name; };
        modules = [
          ./hosts/${name}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { hostName = name; };
            home-manager.users.ricky = import ./home;
          }
        ];
      };
    in
    {
      nixosConfigurations.laptop = mkHost "laptop";
      nixosConfigurations.amd = mkHost "amd";
    };
}

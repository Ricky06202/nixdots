# PC AMD: CPU + GPU AMD (drivers amdgpu/Mesa nativos del kernel, sin config extra).
# La iGPU Intel Broadwell queda como salida de video (VA-API i965 en shared).

{ pkgs, ... }:

{
  imports = [
    ../../shared
    ./hardware-configuration.nix
  ];

  networking.hostName = "amd";

  # Blacklistear nouveau: si hay una NVIDIA físicamente presente, no se usa y
  # nouveau solo gasta RAM/CPU.
  boot.blacklistedKernelModules = [ "nouveau" ];
}

# PC AMD — specs reales:
#   CPU:  AMD Ryzen 5 5500 (6c/12t, Zen 3)
#   GPU:  ASRock Challenger RX 7600 8GB (RDNA3, amdgpu/Mesa nativos)
#   MB:   Gigabyte A520M K V2 (AM4)
#   RAM:  16GB DDR4-3200
#   SSD:  Crucial P2 500GB NVMe

{ pkgs, ... }:

{
  imports = [
    ../../shared
    ./hardware-configuration.nix
  ];

  networking.hostName = "amd";

  # Microcode AMD (estabilidad/seguridad del CPU).
  hardware.cpu.amd.updateMicrocode = true;

  # 16GB RAM física: zram al 25% (4GB) + swapfile 4GB.
  zramSwap.memoryPercent = 25;

  # Swap en disco, dentro del subvolúmen @swap (instalación Btrfs):
  swapDevices = [ { device = "/swap/swapfile"; size = 4096; } ];

  # IA local (ollama) — la RX 7600 lo acelera vía Vulkan.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
    port = 11434;
  };

  # Blacklistear nouveau: si hay una NVIDIA físicamente presente, no se usa y
  # nouveau solo gasta RAM/CPU.
  boot.blacklistedKernelModules = [ "nouveau" ];
}

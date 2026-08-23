# PC AMD — specs reales:
#   CPU:  AMD Ryzen 7 5700 (8c/16t, Cezanne con iGPU desactivada)
#   GPU:  ASRock Challenger RX 7600 8GB (RDNA3, amdgpu/Mesa nativos)
#   MB:   MSI B550M PRO-VDH WIFI (AM4)
#   RAM:  G.Skill Ripjaws V 32GB DDR4-3200
#   SSD:  TeamGroup MP44L 1TB NVMe Gen4 (instalación Btrfs, ver README)

{ pkgs, ... }:

{
  imports = [
    ../../shared
    ./hardware-configuration.nix
  ];

  networking.hostName = "amd";

  # Microcode AMD (estabilidad/seguridad del CPU).
  hardware.cpu.amd.updateMicrocode = true;

  # 32GB RAM física: zram al 25% (8GB) alcanza de sobra junto al swapfile.
  zramSwap.memoryPercent = 25;

  # Swap en disco, dentro del subvolúmen @swap (instalación Btrfs):
  # NOCOW heredado y los futuros snapshots de @ no chocan con el archivo activo.
  # NixOS le aplica `chattr +C` automáticamente al crearlo.
  swapDevices = [ { device = "/swap/swapfile"; size = 8192; } ];

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

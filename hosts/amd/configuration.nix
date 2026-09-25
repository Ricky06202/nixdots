# PC AMD — specs reales:
#   CPU:  AMD Ryzen 5 5500 (6c/12t, Zen 3)
#   GPU:  ASRock Challenger OC RX 7600 8GB (RDNA3, amdgpu/Mesa nativos)
#   MB:   Gigabyte B550M K (Micro ATX, AM4)
#   RAM:  2x 16GB DDR4-3200 CL22 Silicon Power (32GB total)
#   SSD:  ADATA LEGEND 860 500GB NVMe PCIe 4.0
#   PSU:  MSI MAG A550BN 550W 80+ Bronze

{ pkgs, ... }:

{
  imports = [
    ../../shared
    ./hardware-configuration.nix
  ];

  networking.hostName = "amd";

  # Microcode AMD (estabilidad/seguridad del CPU).
  hardware.cpu.amd.updateMicrocode = true;

  # 32GB RAM física: zram al 25% (8GB, priority -1 => nunca es target de
  # hibernación) + swapfile de disco de 40GB para poder hibernar (>= RAM de
  # uso tipico con margen).
  zramSwap.memoryPercent = 25;

  # Swap en disco, dentro del subvolúmen @swap (instalación Btrfs):
  # es el dispositivo donde systemd-hibernate escribe la imagen de la RAM.
  # priority=100: el kernel escribe la imagen de hibernacion en el swap de
  # MAYOR prioridad. zramSwap viene con prio 5 y zram es RAM volatil: con el
  # swapfile a -1 la cabecera caia en zram y el resume moria ("Unable to
  # resume ... continuing boot process"). Con 100 la imagen va al disco y
  # sobrevive al apagado.
  swapDevices = [ { device = "/swap/swapfile"; size = 40960; priority = 100; } ];

  # initrd con systemd: systemd-hibernate-resume lee la EFI var
  # "HibernateLocation" que deja el hibernate y restaura la imagen al boot
  # (funciona con swapfile, sin tocar GRUB ni hardcoded offsets).
  boot.initrd.systemd.enable = true;

  # Comportamiento de suspend/hibernate de logind.
  systemd.sleep.settings.Sleep = {
    HibernateMode = "shutdown";
    HibernateDelaySec = "30min";
  };

  # IA local (ollama) — la RX 7600 lo acelera vía Vulkan.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
    port = 11434;
    loadModels = [ "qwen3:8b" ];
  };

  # Auto-descargar el modelo tras cada consulta: libera VRAM/RAM al momento,
  # así no hay que desmontarlo a mano para jugar (solo se sube mientras se usa).
  systemd.services.ollama.environment = {
    OLLAMA_KEEP_ALIVE = "0";
    OLLAMA_MAX_LOADED_MODELS = "1";
  };

  # Blacklistear nouveau: si hay una NVIDIA físicamente presente, no se usa y
  # nouveau solo gasta RAM/CPU.
  boot.blacklistedKernelModules = [ "nouveau" ];

  # Estabilidad de suspend en esta placa (B550M + RX 7600):
  # - mem_sleep_default=s2idle: el handoff al S3 "deep" de la BIOS cuelga el
  #   sistema justo tras "Suspending console(s)" (firmware AM4 con S3 mal
  #   implementado). s2idle usa la ruta de idle del SoC, que sí funciona.
  # - amdgpu.sg_display=0: workaround del hang de display DC en suspend/resume
  #   (el boot ya muestra REG_WAIT timeout en optc32_disable_crtc, DCN 3.2).
  # - secretmem.enable=false: si algun proceso mantiene memfd_secret viva
  #   (p.ej. GnuPG >=2.4), hibernation_available() del kernel 7.x se vuelve
  #   false => /sys/power/disk=[disabled] y suspend-then-hibernate muere con
  #   EPERM. Apagandolo, esos usuarios caen a mlock y la hibernacion revierte.
  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "amdgpu.sg_display=0"
    "secretmem.enable=false"
  ];
}

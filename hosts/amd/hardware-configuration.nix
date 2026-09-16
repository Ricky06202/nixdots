# hardware-configuration.nix del PC AMD (host "amd").
# Hardware real:
#   CPU/Placa: Ryzen + Gigabyte B550M K (AM4)
#   Disco sistema: ADATA LEGEND 860 NVMe — nvme0n1
#     nvme0n1p1  vfat   UUID 9D18-3EDA               -> /boot
#     nvme0n1p2  btrfs  UUID 9fec97f4-215a-49b9-a087-15c1e3a5ed94
#        subvolúmenes:  @ -> /,  @home -> /home,  @nix -> /nix,  @swap -> /swap
#   Swap: swapfile en /swap (declarado en hosts/amd/configuration.nix) + zram.
# OJO: estas UUIDs/subvolúmenes son SOLO de esta máquina. No copiar a otros hosts.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/9fec97f4-215a-49b9-a087-15c1e3a5ed94";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/9D18-3EDA";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/9fec97f4-215a-49b9-a087-15c1e3a5ed94";
      fsType = "btrfs";
      options = [ "subvol=@home" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/9fec97f4-215a-49b9-a087-15c1e3a5ed94";
      fsType = "btrfs";
      options = [ "subvol=@nix" ];
    };

  fileSystems."/swap" =
    { device = "/dev/disk/by-uuid/9fec97f4-215a-49b9-a087-15c1e3a5ed94";
      fsType = "btrfs";
      options = [ "subvol=@swap" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
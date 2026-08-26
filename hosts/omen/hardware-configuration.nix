# Placeholder: reemplazar con el generado por `nixos-generate-config` en la Omen.
# Este archivo NO se commitea — cada máquina genera el suyo.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # TODO: reemplazar con el contenido de /etc/nixos/hardware-configuration.nix
  # generado por `nixos-generate-config` en la Omen.
  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [ { device = "/swapfile"; } ];

  hardware.cpu.intel.updateMicrocode = true;
}

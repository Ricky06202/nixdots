# Raspberry Pi 3 de la oficina — agente de impresiones HEADLESS.
# Imagen: nix build .#nixosConfigurations.pi.config.system.build.sdImage
# Cross-compilada desde x86_64 (nixpkgs.buildPlatform), sin qemu/binfmt.
#
# Flujo de uso:
#   1. Flashear la SD, arrancar el Pi con ethernet.
#   2. Crear el token (NUNCA va al repo ni a la imagen):
#        ssh ricky@pi
#        sudo mkdir -p /var/secrets
#        sudo cp <tu-token> /var/secrets/impresiones-admin-token
#        sudo chmod 600 /var/secrets/impresiones-admin-token
#      (el servicio reintenta solo: tras poner el token imprime sin reiniciar)
#   3. Conectar la impresora por USB (ipp-usb la expone como red local y CUPS
#      la auto-crea) o dejar que browsed descubra las compartidas de la red.
#   4. En el panel web: asignar los papeles y el stock a las impresoras que
#      reportó la máquina "pi" — desde ahí se activan/desactivan por papel.

{ config, lib, pkgs, modulesPath, impresiones, ... }:

{
  imports = [ (modulesPath + "/installer/sd-card/sd-image-aarch64.nix") ];

  networking.hostName = "pi";
  time.timeZone = "America/Panama";

  # La imagen del módulo sd-image-aarch64 ya arranca en Pi 3 (u-boot aarch64
  # + dtbs bcm2710 en populateFirmwareCommands).
  sdImage.compressImage = false;

  # --- CUPS: impresoras locales/red ---
  services.printing.enable = true;
  # Impresora HP Smart Tank (y similares) por USB → se expone por IPP
  # (protocolo AirPrint/Mopria) sin need de drivers hplip:
  services.ipp-usb.enable = true;
  # Descubrimiento de colas de red/compartidas (CUPS browsed + mDNS):
  services.printing.browsed.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # --- Agente headless de impresiones ---
  services.agente-impresiones = {
    enable = true;
    # Binario aarch64 cross-compilado (se construye aquí, en x86_64).
    package = impresiones.packages.x86_64-linux.agentd-aarch64;
    tokenFile = "/var/secrets/impresiones-admin-token";
    # machine = null → usa el hostname ("pi") como nombre de máquina en el panel.
  };

  # --- Acceso ---
  users.users.ricky = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Cambiar tras el primer login (sudo passwd ricky) o borrar y usar solo llave.
    initialPassword = "pi-cambiar";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUKs3WHiTv1RjpzYl+4yMe0f2mNf7+KT94eT55cWrfb ricardosanjurg@gmail.com"
    ];
  };
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  zramSwap.enable = true;

  system.stateVersion = "26.05";
}

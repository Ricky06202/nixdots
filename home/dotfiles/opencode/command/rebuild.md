---
description: Reconstruye el sistema NixOS (aplica changes en configuration.nix). Como sudo pide contraseña, te doy el comando para correr.
agent: nixos
---

El usuario quiere reconstruir NixOS para aplicar cambios del sistema.

Pasos:
1. Lee `/etc/nixos/configuration.nix` y, si hay algún cambio pendiente en otro archivo de trabajo, prepáralo.
2. Comprueba que el canal sea `nixos-unstable`: ejecuta `nix-channel --list` (como usuario) y si hace falta, indica el cambio de canal.
3. Dale al usuario este comando exacto para que lo corra en su terminal:

```
sudo nixos-rebuild switch
```

4. Cuando el usuario confirme que terminó, verifica la instalación con comandos como:
   - `which vivaldi spotify discord neovim wezterm lutris steam opencode`
   - `nixos-version`
5. Si hubo errores en el rebuild, revisa el log y propón la corrección en `/etc/nixos/configuration.nix`, y pídele que repita el comando.

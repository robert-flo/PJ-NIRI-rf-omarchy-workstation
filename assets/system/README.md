---
title: "assets/system — Archivos de Sistema de Referencia"
tags:
  - referencia
  - sistema
aliases:
  - assets/system
date: 2026-10-23
---

# 🗄️ `assets/system/` — Archivos de Sistema de Referencia

> [!NOTE]
> **Navegación:**
> * Explicación e instalación: [[07.4 - Archivos de Sistema de Referencia (assets-system)|07.4 - Archivos de Sistema de Referencia]]
> * Volver a: [[00.0 - Mapa General del Sistema (MOC)|00.0 - Mapa General del Sistema (MOC)]]

Copias **exactas** de los archivos fuera de `$HOME` que gestiona esta arquitectura. La ruta dentro de esta carpeta es la ruta absoluta de destino (por ejemplo `assets/system/etc/sddm.conf.d/10-theme.conf` $\rightarrow$ `/etc/sddm.conf.d/10-theme.conf`).

> [!TIP]
> **Verlos en Obsidian.** El vault tiene activado *Ajustes → Archivos y enlaces → Detectar todas las extensiones de archivo* (`showUnsupportedFiles` en `.obsidian/app.json`), así que estos archivos aparecen en el explorador y los enlaces de abajo funcionan.

| Archivo | Destino | Modo | Nota Explicativa |
|---|---|---|---|
| `assets/system/etc/sudoers.d/` (`04_omarchy`, `04_omarchy-test`, `04_gracie`, `04_niri`, `04_niri-test`, `04_sura`, `04_nyxuri`, `04_nyxuri-test`, `04_nyxuri-legacy`) | `/etc/sudoers.d/` | `0440` | [[01.1 - Sudo sin Contrasena (Passwordless Sudo)\|01.1]] |
| `assets/system/etc/skel/` (`.bashrc`, `.config/fish/conf.d/android.fish`) | `/etc/skel/` | `0644` | [[01.3 - Creacion de Usuarios y Cuentas de Sistema\|01.3]] |
| `assets/system/etc/sddm.conf.d/` (`10-theme.conf`, `99-omarchy-login.conf`) | `/etc/sddm.conf.d/` | `0644` | [[01.4 - Display Manager y Sesiones SDDM (Herald OS)\|01.4]] |
| `assets/system/usr/local/bin/update-niri-desktop.sh` | `/usr/local/bin/` | `0755` | [[04.2 - Desktop Flavor Clavis (Quickshell y Actualizaciones)\|04.2]] |
| `assets/system/usr/local/bin/update-nyxuri-desktop.sh` | `/usr/local/bin/` | `0755` | [[04.5 - Desktop Flavor Nyxuri (Noctalia Shell y mpvpaper)\|04.5]] |
| `assets/system/usr/local/bin/rvim` | `/usr/local/bin/` | `0755` | [[05.1 - Arquitectura Neovim Dual Compartida (z-nvims)\|05.1]] |
| `assets/system/usr/local/bin/cvim`, `craftvim` | `/usr/local/bin/` | `0755` | [[05.1 - Arquitectura Neovim Dual Compartida (z-nvims)\|05.1]] |
| `assets/system/usr/local/bin/2kvim` | `/usr/local/bin/` | `0755` | [[05.1 - Arquitectura Neovim Dual Compartida (z-nvims)\|05.1]] |
| `assets/system/usr/local/bin/forkhub` | `/usr/local/bin/` | `0755` | [[07.5 - Catalogo y Manual de Herramientas CLI del Playbook\|07.5]] |
| `assets/system/etc/forkhub/repos.d/` (`*.conf`) | `/etc/forkhub/repos.d/` | `0664` | [[07.5 - Catalogo y Manual de Herramientas CLI del Playbook\|07.5]] |
| `assets/system/etc/systemd/system/` (`forkhub.service`, `forkhub.timer`) | `/etc/systemd/system/` | `0644` | [[07.5 - Catalogo y Manual de Herramientas CLI del Playbook\|07.5]] |
| `assets/system/etc/systemd/system/` (`niri-update.service`, `niri-update.timer`) | `/etc/systemd/system/` | `0644` | [[04.2 - Desktop Flavor Clavis (Quickshell y Actualizaciones)\|04.2]] |
| `assets/system/etc/` (`greetd/config.toml`, `polkit-1/rules.d/50-noctalia-greeter.rules`) | `/etc/` | `0644` | [[04.5 - Desktop Flavor Nyxuri (Noctalia Shell y mpvpaper)\|04.5]] |
| `assets/system/etc/modprobe.d/i915.conf` | `/etc/modprobe.d/` | `0644` | [[01.2 - Hardware y Graficos (Fix Parpadeo Intel i915)\|01.2]] |
| `assets/system/etc/environment.d/10-android.conf` | `/etc/environment.d/` | `0644` | [[03.5 - Ecosistema Google Antigravity y Android Studio Canary (BYOA)\|03.5]] |
| `assets/system/etc/fish/conf.d/android.fish` | `/etc/fish/conf.d/` | `0644` | [[03.5 - Ecosistema Google Antigravity y Android Studio Canary (BYOA)\|03.5]] |
| `assets/system/etc/profile.d/android.sh` | `/etc/profile.d/` | `0755` | [[03.5 - Ecosistema Google Antigravity y Android Studio Canary (BYOA)\|03.5]] |
| `assets/system/usr/local/bin/google-chrome` | `/usr/local/bin/` | `0755` | [[03.5 - Ecosistema Google Antigravity y Android Studio Canary (BYOA)\|03.5]] |
| `assets/system/usr/local/bin/fix_shared_dir_perms.sh` | `/usr/local/bin/` | `0755` | [[02.1 - Directorio Compartido (z) y Permisos ACL\|02.1]] |
| `assets/system/usr/local/bin/` (`*_watcher.sh`) | `/usr/local/bin/` | `0755` | [[02.1 - Directorio Compartido (z) y Permisos ACL\|02.1]] |
| `assets/system/etc/systemd/system/` (`android-*-perms.*`, `z-perms.*`, `z-drive-perms.*`) | `/etc/systemd/system/` | `0644` | [[02.1 - Directorio Compartido (z) y Permisos ACL\|02.1]] |
| `assets/system/etc/rclone/` (`exclusiones-sync.txt`, `sync-*.conf`, plantilla `rclone.conf`) | `/etc/rclone/` | `0644` / `0660` | [[02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud\|02.3]] |
| `assets/system/etc/environment.d/20-rclone.conf` | `/etc/environment.d/` | `0644` | [[02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud\|02.3]] |
| `assets/system/etc/profile.d/20-rclone.sh` | `/etc/profile.d/` | `0644` | [[02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud\|02.3]] |
| `assets/system/etc/fish/conf.d/rclone.fish` | `/etc/fish/conf.d/` | `0644` | [[02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud\|02.3]] |
| `assets/system/usr/local/bin/` (`sync-*`, `upload-moved-*`, `watch-moved`) | `/usr/local/bin/` | `0755` | [[02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud\|02.3]] |
| `assets/system/etc/fuse.conf` | `/etc/fuse.conf` | `0644` | [[02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud\|02.3]] |
| `assets/system/etc/systemd/system/rclone-gdrive-mount.service` | `/etc/systemd/system/` | `0644` | [[02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud\|02.3]] |
| `assets/system/usr/local/bin/synchub` | `/usr/local/bin/` | `0755` | [[02.4 - Suite Declarativa synchub y Automatizacion Udev\|02.4]] |
| `assets/system/etc/synchub/targets.d/` (`*.conf`) | `/etc/synchub/targets.d/` | `0644` | [[02.4 - Suite Declarativa synchub y Automatizacion Udev\|02.4]] |
| `assets/system/etc/systemd/system/synchub@.*` | `/etc/systemd/system/` | `0644` | [[02.4 - Suite Declarativa synchub y Automatizacion Udev\|02.4]] |
| `assets/system/etc/systemd/system/synchub-btrfs-attach.service` | `/etc/systemd/system/` | `0644` | [[02.4 - Suite Declarativa synchub y Automatizacion Udev\|02.4]] |
| `assets/system/etc/udev/rules.d/99-almacen-btrfs.rules` | `/etc/udev/rules.d/` | `0644` | [[02.4 - Suite Declarativa synchub y Automatizacion Udev\|02.4]] |
| `assets/system/etc/systemd/system/` (`sync-*.service`, `sync-*.timer`) | `/etc/systemd/system/` | `0644` | [[02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud\|02.3]] |
| `assets/system/etc/sudoers.d/99_guest-deny` | `/etc/sudoers.d/` | `0440` | [[01.7 - Usuario Especial Amnesico y Sandbox (guest)\|01.7]] |
| `assets/system/etc/polkit-1/rules.d/00-guest-block.rules` | `/etc/polkit-1/rules.d/` | `0644` | [[01.7 - Usuario Especial Amnesico y Sandbox (guest)\|01.7]] |
| `assets/system/etc/pam.d/` (`su`, `system-login`) | `/etc/pam.d/` | `0644` | [[01.7 - Usuario Especial Amnesico y Sandbox (guest)\|01.7]] |
| `assets/system/usr/local/bin/guest-session-manager.sh` | `/usr/local/bin/` | `0755` | [[01.7 - Usuario Especial Amnesico y Sandbox (guest)\|01.7]] |
| `assets/system/etc/guest-skel/` | `/etc/guest-skel/` | `0755` | [[01.7 - Usuario Especial Amnesico y Sandbox (guest)\|01.7]] |
| `assets/system/etc/systemd/system/user-1007.slice` | `/etc/systemd/system/` | `0644` | [[01.7 - Usuario Especial Amnesico y Sandbox (guest)\|01.7]] |
| `assets/system/etc/ufw/before.rules` | `/etc/ufw/` | `0640` | [[01.7 - Usuario Especial Amnesico y Sandbox (guest)\|01.7]] |

> [!WARNING]
> **Mantener sincronizado.** Si cambias uno de estos archivos en la máquina, copia la versión nueva aquí y actualiza la nota que lo explica. La comprobación `cmp` de [[07.4 - Archivos de Sistema de Referencia (assets-system)\|07.4]] muestra qué difiere.

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
| [[assets/system/etc/sudoers.d/04_gracie\|04_gracie]] · [[assets/system/etc/sudoers.d/04_niri\|04_niri]] · [[assets/system/etc/sudoers.d/04_sura\|04_sura]] · [[assets/system/etc/sudoers.d/04_nyxuri\|04_nyxuri]] · [[assets/system/etc/sudoers.d/04_nyxuri-test\|04_nyxuri-test]] | `/etc/sudoers.d/` | `0440` | [[01.1 - Sudo sin Contrasena (Passwordless Sudo)\|01.1]] |
| [[assets/system/etc/sddm.conf.d/10-theme.conf\|10-theme.conf]] · [[assets/system/etc/sddm.conf.d/99-omarchy-login.conf\|99-omarchy-login.conf]] | `/etc/sddm.conf.d/` | `0644` | [[01.4 - Display Manager y Sesiones SDDM (Herald OS)\|01.4]] |
| [[assets/system/usr/local/bin/update-niri-desktop.sh\|update-niri-desktop.sh]] | `/usr/local/bin/` | `0755` | [[04.2 - Desktop Flavor Clavis (Quickshell y Actualizaciones)\|04.2]] |
| [[assets/system/usr/local/bin/update-nyxuri-desktop.sh\|update-nyxuri-desktop.sh]] | `/usr/local/bin/` | `0755` | [[04.5 - Desktop Flavor Nyxuri (Noctalia Shell y mpvpaper)\|04.5]] |
| [[assets/system/usr/local/bin/rvim\|rvim]] | `/usr/local/bin/` | `0755` | [[05.1 - Arquitectura Neovim Dual Compartida (/z/nvims)\|05.1]] |
| [[assets/system/etc/systemd/system/niri-update.service\|niri-update.service]] · [[assets/system/etc/systemd/system/niri-update.timer\|niri-update.timer]] | `/etc/systemd/system/` | `0644` | [[04.2 - Desktop Flavor Clavis (Quickshell y Actualizaciones)\|04.2]] |
| [[assets/system/etc/greetd/config.toml\|config.toml]] · [[assets/system/etc/polkit-1/rules.d/50-noctalia-greeter.rules\|50-noctalia-greeter.rules]] | `/etc/greetd/` | `0644` | [[04.5 - Desktop Flavor Nyxuri (Noctalia Shell y mpvpaper)\|04.5]] |
| [[assets/system/etc/modprobe.d/i915.conf\|i915.conf]] | `/etc/modprobe.d/` | `0644` | [[01.2 - Hardware y Graficos (Fix Parpadeo Intel i915)\|01.2]] |

> [!WARNING]
> **Mantener sincronizado.** Si cambias uno de estos archivos en la máquina, copia la versión nueva aquí y actualiza la nota que lo explica. La comprobación `cmp` de [[07.4 - Archivos de Sistema de Referencia (assets-system)\|07.4]] muestra qué difiere.

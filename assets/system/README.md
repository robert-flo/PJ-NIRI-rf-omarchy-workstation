---
title: "assets/system — Archivos de Sistema"
tags:
  - referencia
  - sistema
aliases:
  - assets/system
date: 2026-10-12
---

# 🗄️ `assets/system/`

> [!NOTE]
> **Navegación:**
> * Explicación e instalación: [[05.4 - Archivos de Sistema de Referencia|Archivos de Sistema de Referencia]]
> * Volver a: [[00 - Indice General (MOC)|Índice General]]

Copias **exactas** de los archivos fuera de `$HOME` que deja este playbook, tomadas de la máquina de referencia (2026-10-12). La ruta dentro de esta carpeta es la ruta absoluta de destino (`assets/system/etc/sddm.conf.d/10-theme.conf` → `/etc/sddm.conf.d/10-theme.conf`).

> [!TIP]
> **Verlos en Obsidian.** El vault tiene activado *Ajustes → Archivos y enlaces → Detectar todas las extensiones de archivo* (`showUnsupportedFiles` en `.obsidian/app.json`), así que estos archivos aparecen en el explorador y los enlaces de abajo funcionan. Obsidian no los edita: se abren con la aplicación predeterminada del sistema.

| Archivo | Destino | Modo | Lo explica |
|---|---|---|---|
| [[assets/system/etc/sudoers.d/04_gracie\|04_gracie]] · [[assets/system/etc/sudoers.d/04_niri\|04_niri]] · [[assets/system/etc/sudoers.d/04_sura\|04_sura]] | `/etc/sudoers.d/` | `0440` | [[01.0 - Sudo sin Contrasena (Passwordless Sudo)\|01.0]] |
| [[assets/system/etc/sddm.conf.d/10-theme.conf\|10-theme.conf]] · [[assets/system/etc/sddm.conf.d/99-omarchy-login.conf\|99-omarchy-login.conf]] | `/etc/sddm.conf.d/` | `0644` | [[01.2 - Paso 2 - Creacion de Usuario y Login SDDM\|01.2]] |
| [[assets/system/usr/local/bin/update-niri-desktop.sh\|update-niri-desktop.sh]] | `/usr/local/bin/` | `0755` | [[01.3 - Paso 3 - Clavis Shell y Actualizaciones\|01.3]] |
| [[assets/system/etc/systemd/system/niri-update.service\|niri-update.service]] · [[assets/system/etc/systemd/system/niri-update.timer\|niri-update.timer]] | `/etc/systemd/system/` | `0644` | [[01.3 - Paso 3 - Clavis Shell y Actualizaciones\|01.3]] |
| [[assets/system/etc/modprobe.d/i915.conf\|i915.conf]] | `/etc/modprobe.d/` | `0644` | [[04.1 - Fix Parpadeo Intel i915 (FIFO Underrun & SAGV)\|04.1]] |

> [!WARNING]
> **Mantener sincronizado.** Si cambias uno de estos archivos en la máquina, copia la versión nueva aquí y actualiza la nota que lo explica. La comprobación `cmp` de [[05.4 - Archivos de Sistema de Referencia|05.4]] muestra qué difiere. Copia como tu usuario (con `sudo install -D` las carpetas nuevas quedarían de root y Obsidian no podría escribir en ellas):
> ```bash
> f=/etc/sddm.conf.d/10-theme.conf          # el archivo que cambió
> mkdir -p "assets/system$(dirname "$f")"
> sudo cat "$f" > "assets/system$f"
> ```

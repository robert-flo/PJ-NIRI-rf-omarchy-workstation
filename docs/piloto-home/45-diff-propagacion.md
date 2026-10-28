---
title: "Piloto Home: Diff de Snapshots y Propagación por pacman (#45)"
tags:
  - piloto-home
  - niri
  - diff
  - pacman
  - propagacion
  - btrfs
aliases:
  - 45-diff-propagacion
  - Diff y Propagacion niri-test
date: 2026-10-26
---

# Piloto Home: Diff de Snapshots y Propagación por pacman (#45)

> **Contexto:** Sub-issue de [#45](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/45), parte del spec central [#40](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/40) (spec madre [#17](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/17)).
> **Objetivo:** Comparar exhaustivamente el snapshot de la línea base (`snap-niri-test-metodo-actual`) contra el snapshot del método desacoplado por capas (`snap-niri-test-metodo-nuevo`), analizar y justificar cada diferencia, emitir veredicto formal de viabilidad para sesión SDDM, y demostrar la propagación transparente mediante `pacman` al subir de versión `ravn-home-common` con un cambio visible sin tocar el repositorio de perfil `ravn-home-profile-niri`.

---

## 📊 1. Resumen Cuantitativo del Diff entre Snapshots

Comparativa ejecutada con exclusión estricta de cachés (`.cache`), estado efímero (`state`), papelera (`Trash`), historiales de shell (`*history*`, `*.hist`), sockets (`*.sock`), locks (`*.lock`, `*.pid`) y temporales (`*.swp`, `*~`, `*.tmp`, `FETCH_HEAD`):

- **Snapshot A (Método Actual / Monolítico):** `/home/.niri-test-snaps/snap-niri-test-metodo-actual`
- **Snapshot B (Método Nuevo / Capas):** `/home/.niri-test-snaps/snap-niri-test-metodo-nuevo`
- **Registro completo del diff:** `~/.cache/ravn-piloto/logs/diff-actual-vs-nuevo.txt` (1,140 líneas)

| Categoría de Diferencia | Cantidad | Descripción Arquitectónica |
| :--- | :---: | :--- |
| **Archivos de Configuración que Difieren** | 8 | Cargadores mínimos (`source`/`import`/`include`) vs configuraciones completas |
| **Metadatos de Git / dotbare (`.cfg`)** | 12 | Cambio de remote origin (`niri-dotfiles` master -> `ravn-home-profile-niri` main) |
| **Conversión Archivo Regular -> Symlink** | 10 | Archivos estáticos delegados a `/usr/share/ravn/{common,niri}/` |
| **Conversión Directorio -> Symlink** | 5 | Carpetas delegadas a paquetes del sistema (activos GTK-4.0, scripts MPV, etc.) |
| **Symlinks hacia Rutas de Sistema** | 3 | Enlaces simbólicos directos a `/usr/share/ravn/` |
| **Elementos Exclusivos de A (Removidos)** | 11 | Datos de apps fuera de alcance (`obsidian`, `rvim`, `thunderbird`, `Documents`, etc.) |
| **Elementos Exclusivos de B (Nuevos)** | 3 | Directorio `fish/conf.d`, ejecutable `ravn-niri-postinstall`, packs git |

---

## 🔍 2. Justificación Fina de Cada Diferencia

### A. Cargadores Nativos Mínimos (Difieren en Contenido)

1. **`.bashrc` (Esperada):**
   - *Antes:* 28 líneas copiadas monolíticamente de `/usr/share/omarchy/default/bash/`.
   - *Después:* 2 líneas: `[[ -r /usr/share/ravn/common/bash/rc ]] && source /usr/share/ravn/common/bash/rc`.
   - *Justificación:* Desacoplamiento total; la lógica de sesión bash reside en el paquete del sistema `ravn-home-common`.
2. **`.config/alacritty/alacritty.toml` (Esperada):**
   - *Antes:* 32 líneas con tipografía JetBrainsMono, bindings y decoraciones fijas en `$HOME`.
   - *Después:* `general.import = [ "/usr/share/ravn/common/alacritty/alacritty.toml" ]`.
   - *Justificación:* Alacritty soporta import nativo de configs compartidas en `/usr/share/`.
3. **`.config/fish/config.fish` (Esperada):**
   - *Antes:* 14 líneas con inicialización de Clavis theme y `try`.
   - *Después:* Comentario de perfil y delegación a `conf.d/ravn.fish`.
   - *Justificación:* Fish inicializa automáticamente archivos en `conf.d/`, donde `ravn.fish` carga `/usr/share/ravn/common/fish/config.fish`.
4. **`.config/mpv/mpv.conf` (Esperada):**
   - *Antes:* Configuración completa con perfiles GPU-next y uosc.
   - *Después:* Directiva `include=/usr/share/ravn/common/mpv/mpv.conf`.
   - *Justificación:* Mpv soporta inclusión directa de archivos de configuración externos.
5. **`.config/niri/config.kdl` (Esperada):**
   - *Antes:* Archivo monolítico de configuración niri.
   - *Después:* `include "/usr/share/ravn/niri/niri/config.kdl"` seguido de `include optional=true "outputs.kdl"`.
   - *Justificación:* Niri valida y resuelve inclusiones relativas (`statindet-windowrule.kdl`, `clavis/`, etc.) directamente sobre `/usr/share/ravn/niri/niri/`.
6. **`.gitignore` y `README.md` (Esperada):**
   - *Antes:* Documentación y reglas del repo monolítico `niri-dotfiles`.
   - *Después:* Documentación y exclusiones de `ravn-home-profile-niri`.

### B. Enlaces Simbólicos Idempotentes hacia `/usr/share/ravn/`

1. **Fcitx5 (`~/.config/fcitx5/conf/classicui.conf`) (Esperada):**
   - Convertido de archivo regular a enlace simbólico hacia `/usr/share/ravn/common/fcitx5/conf/classicui.conf`.
2. **GTK 3 y GTK 4 (`~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/*`) (Esperada):**
   - Archivos `settings.ini`, `gtk.css`, temas dark/light y carpetas de activos (`assets`, `windows-assets`) convertidos en enlaces simbólicos hacia `/usr/share/ravn/common/gtk-4.0/`.
3. **Clavis Shell y Wallpapers (`~/.config/clavis/*`, `~/.local/share/clavis/wallpapers`) (Esperada):**
   - Configuración `config.json`, temas de Matugen `config.toml`, entorno `clavis-mpvpaper.conf` y directorio de wallpapers convertidos en enlaces simbólicos gestionados por `ravn-niri-sync`.
4. **MPV Scripts y Assets (`~/.config/mpv/{scripts,script-opts,fonts}`) (Esperada):**
   - Directorios enlazados simbólicamente hacia `/usr/share/ravn/common/mpv/`.
5. **Herramientas de Soporte (`~/.local/bin/clavis-mpvpaper.sh`, `niri-dotfiles-postinstall`, `optimize-wallpaper`) (Esperada):**
   - Enlaces simbólicos hacia binarios empaquetados en `/usr/share/ravn/niri/bin/`.

### C. Elementos Fuera de Alcance Excluidos de Perfil

1. **`Documents`, `.config/obsidian`, `.config/rvim`, `.config/thunderbird`, `.local/share/2kvim`, `.local/share/rvim` (Esperada):**
   - Presentes en `niri-dotfiles` por tracking histórico accidental.
   - Eliminados deliberadamente de la capa de perfil del sistema; pertenecen a aplicaciones de usuario independientes y no al gestor de ventanas niri.

---

## 🚀 3. Demostración de Propagación por pacman

Para comprobar el criterio central del spec (#40 y #45), se realizó un bump de versión de la capa común y se verificó su propagación automática:

1. **Bump de Versión en `ravn-home-common`:**
   - Versión: `0.1.0-1` -> `0.1.1-1`.
   - Modificación visible: export `RAVN_HOME_COMMON_VERSION="0.1.1"` y alias `ravn-version` en `/usr/share/ravn/common/bash/rc`.
   - Archivo de versión: `/usr/share/ravn/common/version` (`0.1.1`).
2. **Empaquetado y Publicación:**
   - Construcción con `makepkg -f` (`ravn-home-common-0.1.1-1-any.pkg.tar.zst`, SHA-256 tarball: `113721b56fae0fe920b6337eda968c65f9e5e144a6e0374bd753909781bfa099`).
   - Sincronización en base de datos pacman local `/var/cache/pacman/ravn-local/`.
3. **Actualización del Sistema:**
   - Ejecutado: `sudo pacman -S --noconfirm ravn-home-common`.
   - Salida: `upgrading ravn-home-common (0.1.0-1 -> 0.1.1-1)`.
4. **Verificación en el Usuario `niri-test`:**
   ```bash
   sudo -u niri-test bash -ic 'echo "VERSION=$RAVN_HOME_COMMON_VERSION"; ravn-version'
   # Salida:
   # VERSION=0.1.1
   # ravn-home-common v0.1.1 (propagado por pacman)
   ```
5. **Inmutabilidad del Repositorio de Perfil (`dotbare status`):**
   ```bash
   sudo -u niri-test bash -c 'cd /home/niri-test && dotbare status'
   # Salida:
   # On branch main
   # Your branch is up to date with 'origin/main'.
   # nothing to commit (use -u to show untracked files)
   ```
   **Resultado:** Cero archivos modificados en `$HOME`. La actualización del paquete del sistema propagó inmediatamente los cambios a la sesión del usuario sin requerir commits, merges ni pulls en el repositorio de perfil.

6. **Registro de Snapshots Btrfs:**
   - Snapshot inicial método nuevo: `/home/.niri-test-snaps/snap-niri-test-metodo-nuevo` (Subvolumen ID 298).
   - Snapshot post-propagación: `/home/.niri-test-snaps/snap-niri-test-metodo-nuevo-45` (Subvolumen ID 300).
   - Diff entre `/home/niri-test` y el snapshot: 0 diferencias en archivos de usuario.

---

## ⚖️ 4. Veredicto Final

> **Veredicto:** **OK PARA SDDM**
>
> Todas las diferencias encontradas son conformes a la arquitectura por capas diseñada. Las configuraciones de shell, terminal, compositores y temas cargan limpiamente; `niri validate` concluye en estado `INFO niri: config is valid`; el servicio `user@1002` se encuentra activo; y `dotbare status` permanece 100% limpio. El usuario desechable `niri-test` está listo para login gráfico manual a través de SDDM.

---

## 📋 5. Checklist de Verificación SDDM para Roberto

Para verificar la sesión gráfica como `niri-test`:

1. Cerrar sesión actual o cambiar a SDDM (`Ctrl+Alt+F1` o selector de usuario).
2. Seleccionar la sesión **Niri**.
3. Iniciar sesión con el usuario `niri-test` (contraseña configurada para pruebas).
4. **Verificaciones en sesión gráfica:**
   - [ ] Niri arranca con barra QuickShell / Clavis y wallpaper animado activo.
   - [ ] Abrir Alacritty (`Super+Return` o `Shift+Return`): terminal arranca con tipografía JetBrainsMono Nerd Font 9.
   - [ ] En la terminal interactiva, comprobar propagación de versión:
     ```bash
     echo $RAVN_HOME_COMMON_VERSION   # Debe retornar 0.1.1
     ravn-version                     # Debe imprimir: ravn-home-common v0.1.1 (propagado por pacman)
     ```
   - [ ] Comprobar tema GTK y Fcitx5 en aplicaciones Wayland nativas.
   - [ ] Comprobar que el usuario de producción `niri` y `/z` no fueron afectados.

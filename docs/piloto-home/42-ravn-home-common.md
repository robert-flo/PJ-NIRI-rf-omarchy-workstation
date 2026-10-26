---
title: "Piloto Home: ravn-home-common (#42)"
tags:
  - piloto-home
  - common
  - bash
  - fish
  - pacman
aliases:
  - 42-ravn-home-common
  - Capa ravn-home-common
date: 2026-10-26
---

# 42 - ravn-home-common mínimo

Documento de registro para el sub-issue [#42](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/42), parte del spec [#40](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/40) (piloto `$HOME` por capas en `niri-test`).

---

## 📦 Repositorios Creados (Privados)

1. **Código fuente (`ravn-home-common`)**:
   - URL: https://github.com/robert-flo/ravn-home-common
   - Tag: `v0.1.0` (SHA-256 tarball: `ab361c2e553a086c3df8cb3c48d0f8e022110daeeb9c379dfddec4b5a33771e1`)
   - Contenido: capa común derivada de `robert-flo/niri-dotfiles` (shell bash/fish, alacritty, fcitx5, gtk-3.0, gtk-4.0, mpv y herramienta `ravn-home-sync`).

2. **Empaquetado Arch Linux (`ravn-home-common-arch`)**:
   - URL: https://github.com/robert-flo/ravn-home-common-arch
   - Contenido: `PKGBUILD`, `.SRCINFO`, `Makefile` y `README.md` configurados para instalar todos los activos bajo `/usr/share/ravn/common`.

---

## 🔀 Pull Requests Abiertos

| Repositorio | Rama / Base | Pull Request | Estado |
| :--- | :--- | :--- | :--- |
| `robert-flo/ravn-home-common` | `feat/common-layer` → `main` | [#1](https://github.com/robert-flo/ravn-home-common/pull/1) | Abierto |
| `robert-flo/ravn-home-common-arch` | `feat/arch-packaging` → `main` | [#1](https://github.com/robert-flo/ravn-home-common-arch/pull/1) | Abierto |
| `robert-flo/omarchy-pkgs` | `feat/42-ravn-home-common` → `personal` | [#25](https://github.com/robert-flo/omarchy-pkgs/pull/25) | Abierto |

---

## 🗺️ Mapeo de Carga en `$HOME`

### 1. Archivos cargados mediante `source` / `include` / `import`

| Archivo en `$HOME` | Directiva | Archivo en `/usr/share/ravn/common` | Propósito |
| :--- | :--- | :--- | :--- |
| `~/.bashrc` | `source` | `bash/rc` | Bootstrap Omarchy, variable `CURSOR_API_KEY`, wrapper interactivo para `try` |
| `~/.config/fish/config.fish` | `source` | `fish/config.fish` | Tema Clavis, wrapper de `try` y variables de sesión |
| `~/.config/alacritty/alacritty.toml` | `general.import` | `alacritty/alacritty.toml` | Terminal: tipografía JetBrainsMono Nerd Font 9, bindings Shift/Alt+Return |
| `~/.config/mpv/mpv.conf` | `include` | `mpv/mpv.conf` | GPU-next, Vulkan, VA-API, display-resample, uosc custom titlebar |

### 2. Archivos enlazados mediante `ravn-home-sync` (sin soporte de include)

Ubicación del ejecutable: `/usr/share/ravn/common/bin/ravn-home-sync`

| Archivo / Enlace en `$HOME` | Destino en `/usr/share/ravn/common` |
| :--- | :--- |
| `~/.config/fcitx5/conf/classicui.conf` | `fcitx5/conf/classicui.conf` |
| `~/.config/gtk-3.0/settings.ini` | `gtk-3.0/settings.ini` |
| `~/.config/gtk-4.0/settings.ini` | `gtk-4.0/settings.ini` |
| `~/.config/gtk-4.0/gtk.css` | `gtk-4.0/gtk.css` |
| `~/.config/gtk-4.0/gtk-dark.css` | `gtk-4.0/gtk-dark.css` |
| `~/.config/gtk-4.0/gtk-Dark.css` | `gtk-4.0/gtk-Dark.css` |
| `~/.config/gtk-4.0/gtk-Light.css` | `gtk-4.0/gtk-Light.css` |
| `~/.config/gtk-4.0/assets` | `gtk-4.0/assets` |
| `~/.config/gtk-4.0/windows-assets` | `gtk-4.0/windows-assets` |
| `~/.config/mpv/input.conf` | `mpv/input.conf` |
| `~/.config/mpv/fonts` | `mpv/fonts` |
| `~/.config/mpv/script-opts` | `mpv/script-opts` |
| `~/.config/mpv/scripts` | `mpv/scripts` |

---

## 🔍 Evidencia Técnica

### 1. Suite de Pruebas Automatizadas (`ravn-home-sync`)
Verificación de sintaxis, simulación `dry-run`, creación de enlaces, idempotencia (0 modificaciones en segunda ejecución), opción `--skeletons` y resolución de conflictos con respaldo `.bak` bajo `--force`:
```
==> 1. Verificando sintaxis de scripts...
  [OK] Sintaxis bash valida.
==> 2. Verificando ejecucion de ravn-home-sync con directorio temporal...
  [test] Dry-run...
  [OK] Dry-run no creo archivos.
  [test] Primera ejecucion de enlace...
  [OK] Enlaces simbolicos creados correctamente.
  [test] Segunda ejecucion (idempotencia)...
  [OK] Idempotencia verificada: 0 cambios en segunda ejecucion.
  [test] Verificando opcion --skeletons...
  [OK] Skeletons creados correctamente.
  [OK] Idempotencia de skeletons verificada.
  [test] Verificando conflicto y --force...
  [OK] Conflicto resuelto con --force y respaldo generado.
==> TODOS LOS TESTS PASARON EXITOSAMENTE.
```

### 2. Compilación del Paquete y Verificación de Límites
Compilación ejecutada con `makepkg -f` en `pkgbuilds/ravn-home-common`:
```
==> Making package: ravn-home-common 0.1.0-1 (Mon 26 Oct 2026 08:56:30 AM CST)
==> Checking runtime dependencies...
==> Checking buildtime dependencies...
==> Retrieving sources...
  -> Found ravn-home-common-0.1.0.tar.gz
==> Validating source files with sha256sums...
    ravn-home-common-0.1.0.tar.gz ... Passed
==> Extracting sources...
==> Starting package()...
==> Creating package "ravn-home-common"...
==> Finished making: ravn-home-common 0.1.0-1
```
Verificación de que el paquete instala archivos **únicamente** bajo `/usr/share/ravn/common`:
```bash
tar -tf ravn-home-common-0.1.0-1-any.pkg.tar.zst | grep -v '^\.' | grep -v '^usr/share/ravn/common' | grep -v '^usr/share/ravn/$' | grep -v '^usr/share/$' | grep -v '^usr/$'
# Resultado: salida vacía (0 archivos fuera de /usr/share/ravn/common)
```

### 3. Vendoring del Tarball en `omarchy-pkgs`
Al tratarse de repositorios privados durante el experimento, el tarball `ravn-home-common-0.1.0.tar.gz` fue vendoreado con checksum SHA-256 en `pkgbuilds/ravn-home-common/` para permitir que el workflow `release-personal` de GitHub Actions compile y empaquete de forma autónoma sin requerir llaves ni secretos de repositorios privados.

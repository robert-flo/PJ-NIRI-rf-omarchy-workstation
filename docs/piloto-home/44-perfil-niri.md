---
title: "Piloto Home: Perfil Niri y Despliegue Nuevo en niri-test (#44)"
tags:
  - piloto-home
  - niri
  - perfil
  - dotbare
  - btrfs
  - despliegue
aliases:
  - 44-perfil-niri
  - Perfil Niri niri-test
date: 2026-10-26
---

# Piloto Home: Perfil Niri y Despliegue Nuevo en `niri-test` (#44)

> **Contexto:** Sub-issue de [#44](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/44), parte del spec central [#40](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/40) (spec madre [#17](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/17)).
> **Objetivo:** Crear el repositorio privado de perfil `robert-flo/ravn-home-profile-niri` para dotbare conteniendo únicamente los cargadores nativos de las capas instaladas por pacman (`/usr/share/ravn/common` y `/usr/share/ravn/niri`) y overrides propios, realizar wipe de `niri-test`, desplegar con la suite reproducible (`piloto-home.sh deploy niri-nuevo`), generar el snapshot inmutable `snap-niri-test-metodo-nuevo`, demostrar idempotencia estricta (0 cambios en una segunda corrida) y dejar `dotbare status` limpio.

---

## 📦 1. Repositorio de Perfil Creado (Privado)

Se creó e inicializó el repositorio privado de dotfiles de perfil en GitHub:

- **Repositorio:** `robert-flo/ravn-home-profile-niri`
- **URL:** [https://github.com/robert-flo/ravn-home-profile-niri](https://github.com/robert-flo/ravn-home-profile-niri)
- **Rama por defecto:** `main`
- **Visibilidad:** Privado (durante la fase de experimento)

### Estructura Mínima sin Copias de Common

A diferencia del enfoque monolítico tradicional donde cada dotfile era copiado por completo, este repositorio de perfil contiene **únicamente cargadores nativos** y overrides de usuario:

```
ravn-home-profile-niri/
├── .bashrc                                  # source /usr/share/ravn/common/bash/rc
├── .config/
│   ├── alacritty/
│   │   └── alacritty.toml                  # general.import = [ "/usr/share/ravn/common/alacritty/alacritty.toml" ]
│   ├── environment.d/
│   │   └── qt-gtk3.conf                     # QT_QPA_PLATFORMTHEME=gtk3
│   ├── fish/
│   │   ├── conf.d/
│   │   │   └── ravn.fish                    # source /usr/share/ravn/common/fish/config.fish
│   │   └── config.fish                      # Overrides interactivos de usuario
│   ├── mpv/
│   │   └── mpv.conf                         # include=/usr/share/ravn/common/mpv/mpv.conf
│   └── niri/
│       └── config.kdl                       # include "/usr/share/ravn/niri/niri/config.kdl" + outputs.kdl
├── .gitignore                               # Exclusión de credenciales (.config/cursor/) y videos pesados
├── .icons/
│   └── default/
│       └── index.theme                      # Inherits=MacTahoe-dark-cursors
└── README.md                                # Documentación de arquitectura por capas
```

---

## 🏛️ 2. Mecanismos de Carga e Idempotencia

### Archivos con Soporte de Include / Import / Source

| Componente | Archivo en `$HOME` | Directiva | Destino en Sistema (`/usr/share/ravn`) |
| :--- | :--- | :--- | :--- |
| **Bash** | `~/.bashrc` | `source` | `/usr/share/ravn/common/bash/rc` |
| **Fish** | `~/.config/fish/conf.d/ravn.fish` | `source` | `/usr/share/ravn/common/fish/config.fish` |
| **Alacritty** | `~/.config/alacritty/alacritty.toml` | `general.import` | `/usr/share/ravn/common/alacritty/alacritty.toml` |
| **MPV** | `~/.config/mpv/mpv.conf` | `include` | `/usr/share/ravn/common/mpv/mpv.conf` |
| **Niri** | `~/.config/niri/config.kdl` | `include` | `/usr/share/ravn/niri/niri/config.kdl` |

### Enlace Idempotente para Programas sin Include

Los programas que no soportan directivas nativas de inclusión son vinculados mediante enlaces simbólicos idempotentes por las utilidades empaquetadas:
- **`ravn-home-sync`** (`/usr/share/ravn/common/bin/ravn-home-sync`): Vincula fcitx5 (`classicui.conf`), temas GTK 3/4 (`settings.ini`, `.css`, assets) y scripts/fuentes de MPV.
- **`ravn-niri-sync`** (`/usr/share/ravn/niri/bin/ravn-niri-sync`): Vincula Clavis (`config.json`), Matugen (`config.toml`), variables de entorno (`clavis-mpvpaper.conf`), wallpapers y ejecutables de usuario (`.local/bin/`).

---

## 🛠️ 3. Mejoras y Correcciones a la Suite de Pruebas

Durante la implementación y ejecución del método nuevo, se resolvieron las siguientes necesidades en la suite `scripts/piloto-home/`:

1. **Alineación de Rama por Defecto:**
   - Se actualizó `PROFILE_BRANCH="main"` tanto en `piloto-home.sh` como en `plugins/niri-nuevo.sh`.
2. **Autenticación Git Automatizada para Repositorios Privados:**
   - Dado que `robert-flo/ravn-home-profile-niri` es un repositorio privado y `niri-test` carece de credenciales interactivas, `plugins/niri-nuevo.sh` genera un helper efímero vía `GIT_ASKPASS` mediante `gh auth token` durante la ejecución del script.
   - El helper se elimina automáticamente tras finalizar el comando (`trap cleanup_cred EXIT`), garantizando que **ningún token quede almacenado en disco** ni en la configuración de Git de `~/.cfg`.
3. **Idempotencia de Clonación Bare con dotbare:**
   - Se añadió la verificación `sudo test -d "$TARGET_HOME/.cfg"` previa a invocar `dotbare finit`. Si el repositorio bare ya existe, se omite la clonación evitando fallos de directorio no vacío en subsecuentes ejecuciones.
4. **Permisos de Inspección sobre `$TARGET_HOME`:**
   - Como `/home/niri-test` tiene permisos restrictivos `0700`, cualquier comprobación ejecutada por el usuario invocador (`omarchy`) requería ejecutarse con `sudo test` para no falsear comprobaciones de existencia.
5. **Cadena Completa de Despliegue:**
   - Se integraron las llamadas ordenadas a `ravn-home-sync`, `ravn-niri-sync` y la postinstalación de Niri (`/usr/share/ravn/niri/bin/niri-dotfiles-postinstall`).
6. **Exclusión de `FETCH_HEAD` en Diff:**
   - Se incorporó `FETCH_HEAD` a `DIFF_EXCLUDES` en `piloto-home.sh` para evitar falsos positivos derivados de operaciones de consulta de Git.

---

## 🚀 4. Ejecución del Despliegue en `niri-test`

### 1. Wipe Controlado y Despliegue Nuevo
```console
$ ~/.cache/ravn-piloto/wt-44/scripts/piloto-home/piloto-home.sh wipe --user niri-test
==> [wipe] Iniciando wipe controlado para usuario desechable 'niri-test'...
==>        Home: /home/niri-test (UID: 1002)
==> [wipe] Recreando subvolumen dedicado en /home/niri-test...
Create subvolume '/home/niri-test'
==> [wipe] Subvolumen btrfs /home/niri-test recreado en estado limpio (modo 700).

$ ~/.cache/ravn-piloto/wt-44/scripts/piloto-home/piloto-home.sh deploy niri-nuevo --user niri-test
==> [deploy] Ejecutando plugin de despliegue 'niri-nuevo' para niri-test...
==> [niri-nuevo] Instalando paquetes del sistema...
warning: ravn-home-common-0.1.0-1 is up to date -- skipping
warning: ravn-home-niri-0.1.0-1 is up to date -- skipping
==> [niri-nuevo] Clonando repositorio de perfil con dotbare...
File checkout succeeded
==> [niri-nuevo] Ejecutando /usr/share/ravn/common/bin/ravn-home-sync...
Enlazado: /home/niri-test/.config/fcitx5/conf/classicui.conf -> /usr/share/ravn/common/fcitx5/conf/classicui.conf
Enlazado: /home/niri-test/.config/gtk-3.0/settings.ini -> /usr/share/ravn/common/gtk-3.0/settings.ini
Enlazado: /home/niri-test/.config/gtk-4.0/settings.ini -> /usr/share/ravn/common/gtk-4.0/settings.ini
Enlazado: /home/niri-test/.config/mpv/input.conf -> /usr/share/ravn/common/mpv/input.conf
==> [niri-nuevo] Ejecutando /usr/share/ravn/niri/bin/ravn-niri-sync...
Enlazado: /home/niri-test/.config/clavis/config.json -> /usr/share/ravn/niri/clavis/config.json
Enlazado: /home/niri-test/.local/bin/clavis-mpvpaper.sh -> /usr/share/ravn/niri/bin/clavis-mpvpaper.sh
==> [niri-nuevo] Ejecutando postinstalación niri...
==> Validating niri config
INFO niri: config is valid
==> [niri-nuevo] Despliegue nuevo completado.
```

### 2. Estado de `dotbare status`
Ejecutado como usuario `niri-test`:
```console
$ (cd /tmp && sudo -u niri-test -H dotbare status)
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit (use -u to show untracked files)
```
El árbol de trabajo queda **completamente limpio**, sin modificaciones accidentales sobre archivos versionados.

### 3. Validación de la Configuración de Niri
```console
$ sudo -u niri-test niri validate -c /home/niri-test/.config/niri/config.kdl
DEBUG niri_config: loaded config from "/home/niri-test/.config/niri/config.kdl"
INFO niri: config is valid
```

---

## 📸 5. Creación del Snapshot `snap-niri-test-metodo-nuevo`

Se capturó el snapshot de solo lectura en el subvolumen de respaldos:

```console
$ ~/.cache/ravn-piloto/wt-44/scripts/piloto-home/piloto-home.sh snapshot snap-niri-test-metodo-nuevo --user niri-test
==> [snapshot] Creando snapshot read-only en /home/.niri-test-snaps/snap-niri-test-metodo-nuevo...
Create readonly snapshot of '/home/niri-test' in '/home/.niri-test-snaps/snap-niri-test-metodo-nuevo'
==> [snapshot] Snapshot creado exitosamente:
	Name: 			snap-niri-test-metodo-nuevo
	UUID: 			263edc12-6b59-4444-8b52-2f0d1c3a4456
	Flags: 			readonly
```

Subvolumen confirmado:
- **Ruta:** `/home/.niri-test-snaps/snap-niri-test-metodo-nuevo`
- **Subvolume ID:** `298`
- **Modo:** Read-Only

---

## 🔁 6. Demostración de Idempotencia Estricta (0 Cambios)

Para demostrar que una ejecución sucesiva no altera la configuración ni el entorno, se ejecutó una segunda pasada completa de `deploy niri-nuevo`:

1. **Ejecución repetida:**
   ```console
   $ ~/.cache/ravn-piloto/wt-44/scripts/piloto-home/piloto-home.sh deploy niri-nuevo --user niri-test
   ==> [deploy] Ejecutando plugin de despliegue 'niri-nuevo' para niri-test...
   ==> [niri-nuevo] Instalando paquetes del sistema... (omitiendo: al día)
   ==> [niri-nuevo] Repositorio bare ~/.cfg ya existe; omitiendo clonación dotbare.
   ==> [niri-nuevo] Ejecutando /usr/share/ravn/common/bin/ravn-home-sync... (sin cambios)
   ==> [niri-nuevo] Ejecutando /usr/share/ravn/niri/bin/ravn-niri-sync... (sin cambios)
   ==> [niri-nuevo] Despliegue nuevo completado.
   ```
2. **`dotbare status` tras segunda pasada:**
   ```console
   $ (cd /tmp && sudo -u niri-test -H dotbare status)
   On branch main
   Your branch is up to date with 'origin/main'.

   nothing to commit (use -u to show untracked files)
   ```
3. **Comparativa Btrfs contra Snapshot Temporal:**
   Se capturó el snapshot temporal `snap-niri-test-segunda-corrida` y se ejecutó la herramienta de diff:
   ```console
   $ ~/.cache/ravn-piloto/wt-44/scripts/piloto-home/piloto-home.sh diff snap-niri-test-metodo-nuevo snap-niri-test-segunda-corrida
   ==> [diff] Comparando snapshots:
   ==>        A: /home/.niri-test-snaps/snap-niri-test-metodo-nuevo
   ==>        B: /home/.niri-test-snaps/snap-niri-test-segunda-corrida

   --- RESUMEN DE DIFERENCIAS ---
   Solo en A: 0
   Solo en B: 0
   Diferentes: 0
   Especiales: 0
   ------------------------------
   ```
   **Resultado:** **0 diferencias absolutas**, confirmando la completa idempotencia de la arquitectura por capas y de la suite de despliegue.

---

## 🛡️ 7. Preservación del Sistema

Conforme a las reglas de protección del sistema:
- El usuario `niri` de producción y `/home/niri` permanecieron totalmente intactos.
- No se accedió ni modificó `/z`, `/z-drive` ni ninguna bóveda de secretos.
- Cada intervención en el sistema y snapshots quedó asentada en `~/.cache/ravn-piloto/CAMBIOS.md` con sus correspondientes comandos de reversión.

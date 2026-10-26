---
title: "Piloto Home: ravn-home-niri (#43)"
tags:
  - piloto-home
  - niri
  - clavis
  - pacman
  - quickshell
aliases:
  - 43-ravn-home-niri
  - Capa ravn-home-niri
date: 2026-10-26
---

# 43 - ravn-home-niri

Documento de registro para el sub-issue [#43](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/43), parte del spec [#40](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/40) (piloto `$HOME` por capas en `niri-test`).

---

## 📦 Repositorios Creados (Privados)

1. **Código fuente (`ravn-home-niri`)**:
   - URL: https://github.com/robert-flo/ravn-home-niri
   - Tag: `v0.1.0` (SHA-256 tarball: `445e40ed2e2474b7b5c8e235e199e1717f2e8d825d5a4e59e3daed507bb45f6e`)
   - Contenido: capa de escritorio niri derivada de `robert-flo/niri-dotfiles`:
     - Configuración modular de niri en KDL (`config.kdl`, `clavis/` binds, cursor, effects, hot-corners, layer-rules, minimize-animation, liquidbird, obsidian-violet, statindet animaciones, colores y windowrule).
     - Configuración declarativa de Clavis (`config.json`) y Matugen (`matugen/config.toml`).
     - Script de postinstalación adaptado e idempotente (`niri-dotfiles-postinstall` y symlink `ravn-niri-postinstall`).
     - Herramienta de sincronización de usuario `ravn-niri-sync`.
     - Fondos base y scripts (`clavis-mpvpaper.sh`, `optimize-wallpaper`).
     - Suite de pruebas automatizada (`tests/test_niri.sh`).

2. **Empaquetado Arch Linux (`ravn-home-niri-arch`)**:
   - URL: https://github.com/robert-flo/ravn-home-niri-arch
   - Contenido: `PKGBUILD`, `.SRCINFO`, `Makefile` y `README.md` configurados para empaquetar e instalar exclusivamente bajo `/usr/share/ravn/niri`.
   - Dependencias: declara `depends=('ravn-home-common')`.
   - Exclusión: `outputs.kdl` estrictamente excluido del paquete.

---

## 🔀 Pull Requests Abiertos

| Repositorio | Rama / Base | Pull Request | Estado |
| :--- | :--- | :--- | :--- |
| `robert-flo/ravn-home-niri` | `feat/niri-layer` → `main` | [#1](https://github.com/robert-flo/ravn-home-niri/pull/1) | Abierto |
| `robert-flo/ravn-home-niri-arch` | `feat/pkgbuild` → `main` | [#1](https://github.com/robert-flo/ravn-home-niri-arch/pull/1) | Abierto |
| `robert-flo/omarchy-pkgs` | `feat/43-ravn-home-niri` → `personal` | [#26](https://github.com/robert-flo/omarchy-pkgs/pull/26) | Abierto |

---

## 🏛️ Arquitectura de Carga en Niri

### 1. Inclusión Nativa KDL

A diferencia de herramientas que requieren symlinks rígidos, Niri soporta directivas `include` nativas en KDL. En el perfil del usuario (`~/.config/niri/config.kdl`), solo se requiere un cargador mínimo:

```kdl
// ~/.config/niri/config.kdl
// Carga la configuración central inmutable del paquete:
include "/usr/share/ravn/niri/niri/config.kdl"

// Sobrescrituras y salidas de pantalla específicas de la máquina:
include optional=true "outputs.kdl"
```

Todos los includes relativos dentro de `/usr/share/ravn/niri/niri/config.kdl` (como `clavis/binds.kdl`, `liquidbird.kdl`, `statindet-windowrule.kdl`, etc.) son resueltos automáticamente de forma relativa al archivo en `/usr/share/ravn/niri/niri/`.

### 2. Exclusión de `outputs.kdl`

La configuración de salidas físicas y pantallas (`outputs.kdl`) es de **ámbito de máquina** (varía según monitor, modo, escala y conector HDMI/eDP). Queda excluida tanto del repositorio de código como del paquete Arch (`.gitignore` y `rm -f` en `package()`). Como `config.kdl` la incluye con `optional=true`, su ausencia en `/usr/share/ravn/niri/` es ignorada sin error por Niri.

---

## 📂 Estructura Instalada en `/usr/share/ravn/niri`

```
/usr/share/ravn/niri/
├── bin/
│   ├── clavis-mpvpaper.sh             # Gestor de fondos de pantalla en video
│   ├── optimize-wallpaper             # Conversión 1080p@30fps VA-API / CPU
│   ├── niri-dotfiles-postinstall      # Postinstalación idempotente adaptada
│   ├── ravn-niri-postinstall          # Enlace simbólico a niri-dotfiles-postinstall
│   └── ravn-niri-sync                 # Sincronizador de perfil de usuario
├── clavis/
│   ├── config.json                    # Configuración declarativa de Clavis
│   └── matugen/
│       └── config.toml                # Templates de colores dinámicos
├── environment.d/
│   └── clavis-mpvpaper.conf           # Variables de entorno XDG de sesión
├── niri/
│   ├── config.kdl                     # Configuración principal de Niri
│   ├── liquidbird.kdl                 # Reglas de estilo para Thunderbird
│   ├── obsidian-violet.kdl            # Reglas de estilo y blur para Obsidian
│   ├── statindet-animations.kdl       # Animaciones fluidas
│   ├── statindet-colors.kdl           # Anillo de foco y colores base
│   ├── statindet-windowrule.kdl       # Esquinas redondeadas universales
│   └── clavis/
│       ├── binds.kdl                  # Atajos de teclado gestionados por Clavis
│       ├── cursor.kdl                 # Cursor y tamaño MacTahoe
│       ├── effects.kdl                # Efectos X-Ray
│       ├── hot-corners.kdl            # Comportamiento de esquinas
│       ├── layer-rules.kdl            # Reglas de capas para overview y fondos
│       └── minimize-animation.kdl     # Efecto genie de minimizado
└── share/
    ├── clavis/
    │   └── wallpapers/
    │       ├── statindet/
    │       │   └── wallhaven-rq6yqm.jpg
    │       ├── wallhaven-5y3571.jpg
    │       └── video/
    │           ├── optimize-wallpaper.sh
    │           └── README.md
    └── statindet-niri/
        └── niri-colors.kdl
```

---

## ⚙️ Postinstalación Idempotente y Sincronizador

1. **`niri-dotfiles-postinstall` / `ravn-niri-postinstall`:**
   - Adaptado para no fallar si encuentra archivos o symlinks de solo lectura en `/usr/share/ravn/`.
   - Aplica configuraciones `gsettings` (tema GTK MacTahoe-Dark, icono MacTahoe-dark, cursor MacTahoe-dark 28, prefer-light/dark) si el bus D-Bus de sesión está disponible.
   - Habilita de forma segura servicios de usuario systemd (`clavis-shell.service`, `clavis-clipboard.service`).
   - Genera colores dinámicos con Matugen a partir del fondo de pantalla configurado.
   - Valida la sintaxis del compositor ejecutando `niri validate`.

2. **`ravn-niri-sync`:**
   - Herramienta para inicializar o enlazar idempotentemente la capa niri en el `$HOME` del usuario (`~/.config/niri/config.kdl`, `~/.config/clavis/`, wallpapers y binarios locales).

---

## 🔍 Evidencia Técnica

### 1. Validación de Sintaxis y Suite de Pruebas
Ejecución de `tests/test_niri.sh`:
```
==> Test 1: Verificando que outputs.kdl NO exista en el repositorio
OK: outputs.kdl ausente (correcto para archivo de máquina)
==> Test 2: Validando sintaxis KDL de niri/config.kdl con niri validate
2026-10-26T14:59:12.956170Z  WARN niri_config: optional include not found: ".../niri/outputs.kdl"
2026-10-26T14:59:12.956230Z DEBUG niri_config: loaded config from ".../niri/config.kdl"
2026-10-26T14:59:12.956303Z  INFO niri: config is valid
OK: niri/config.kdl es valido
==> Test 3: Validando permisos de ejecucion en bin/
OK: todos los binarios son ejecutables
==> Test 4: Verificando sintaxis de JSON y TOML en clavis
OK: clavis/config.json es JSON valido
==> Todos los tests de ravn-home-niri pasaron exitosamente.
```

### 2. Compilación del Paquete y Verificación de Límites
Compilación ejecutada con `makepkg -d -f` en `pkgbuilds/ravn-home-niri`:
```
==> Making package: ravn-home-niri 0.1.0-1 (Mon 26 Oct 2026 09:04:32 AM CST)
==> Retrieving sources...
  -> Found ravn-home-niri-0.1.0.tar.gz
==> Validating source files with sha256sums...
    ravn-home-niri-0.1.0.tar.gz ... Passed
==> Extracting sources...
==> Entering fakeroot environment...
==> Starting package()...
==> Creating package "ravn-home-niri"...
==> Finished making: ravn-home-niri 0.1.0-1
```

Verificación de que el 100% de los archivos se instalan **únicamente** bajo `/usr/share/ravn/niri/`:
```bash
tar -tf ravn-home-niri-0.1.0-1-any.pkg.tar.zst | grep -v '^\.' | grep -v '^usr/share/ravn/niri' | grep -v '^usr/share/ravn/$' | grep -v '^usr/share/$' | grep -v '^usr/$'
# Resultado: salida vacía (0 archivos fuera de /usr/share/ravn/niri)
```

### 3. Vendoring del Tarball en `omarchy-pkgs`
Dado que `robert-flo/ravn-home-niri` es un repositorio privado durante el piloto, el tarball `ravn-home-niri-0.1.0.tar.gz` (1.1 MB) fue vendoreado con checksum SHA-256 en `pkgbuilds/ravn-home-niri/` para permitir que el workflow `release-personal` de GitHub Actions compile y publique autónomamente en `[omarchy-personal]` sin requerir secretos de repositorios privados.

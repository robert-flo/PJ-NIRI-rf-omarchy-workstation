# 🌌 Arch Linux Workstation Architecture & Bootstrap Playbook

[![Obsidian](https://img.shields.io/badge/Obsidian-Ready-483699?logo=obsidian&logoColor=white)](https://obsidian.md)
[![Linux](https://img.shields.io/badge/Linux-Arch%20%7C%20Omarchy-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Wayland](https://img.shields.io/badge/Display-Wayland%20(Niri)-FFA500)](https://github.com/YaLTeR/niri)
[![Shell 1](https://img.shields.io/badge/Shell-Quickshell%20(Clavis)-68217A)](https://github.com/outfoxxed/quickshell)
[![Shell 2](https://img.shields.io/badge/Shell-Noctalia%20(Nyxuri)-20B2AA)](https://github.com/ech678/Nyxuri)
[![Editor](https://img.shields.io/badge/Editor-Neovim%200.12%20Dual-57A143?logo=neovim&logoColor=white)](https://neovim.io)

Arquitectura integral por capas, diseño de sistemas y bootstrap completo para una estación de trabajo avanzada sobre **Arch Linux / Omarchy**:
- **`niri-edge`**: Compositor Wayland scrollable tiling con minimización nativa y esquinas redondeadas.
- **`Clavis Shell`**: Suite de escritorio en Quickshell (Qt 6 / C++) con estética Liquid Glass inspirada en macOS.
- **`Nyxuri / Noctalia Shell`**: Entorno modular de escritorio con Orbit Launcher, mpvpaper (videos animados) y presets en caliente.
- **`Neovim Dual Compartido`**: Suite IDE basada en Neovim 0.12 con `vim.pack` (Fork Craftzdog, rama `personal`) + distribución personal aislada (`rvim`) centralizadas en `/z/nvims`.
- **`Almacenamiento Compartido /z/`**: Espacio colaborativo multiusuario con setgid, ACLs y Git seguro.
- **`dotbare`**: Gestión profesional de dotfiles mediante repositorios Git bare directamente sobre `$HOME`.

---

## 🚀 Inicio Rápido (Cómo Comenzar en una Máquina Nueva o Existente)

### 1. Puesta en Marcha desde la Terminal (`onboard-machine.sh`)

Clona este repositorio y ejecuta el asistente idempotente de onboarding según el rol de tu máquina (funciona con cualquier nombre de usuario administrador, ej. `rollo`, `omarchy`, etc.):

```bash
# 1. (Opcional) Si aún no has desbloqueado tus credenciales SSH/GitHub CLI cifradas con age:
./scripts/secrets/desbloquear-secretos.sh

# 2A. Estación de Desarrollo (Modo PADRE / DEV — clona /z/pj-omarchy y enlaza omarchy dev link):
sudo ./scripts/omarchy-onboarding/onboard-machine.sh --padre

# 2B. Instalación Completa (Modo PADRE + Convergencia de Capas 01 a 07 en un solo comando):
sudo ./scripts/omarchy-onboarding/onboard-machine.sh --padre --full

# 2C. Máquina Cliente / Producción (Modo HIJA — instala paquetes de [omarchy-personal]):
sudo ./scripts/omarchy-onboarding/onboard-machine.sh --hija

# 2D. Simulación sin modificar el sistema (Dry-Run):
./scripts/omarchy-onboarding/onboard-machine.sh --padre --full --dry-run
```

**¿Qué ejecuta automáticamente este comando?**
- **Etapa 0 (Pre-Flight):** Configura `sudo` sin contraseña para tu usuario en `/etc/sudoers.d/04_<usuario>`, instala `/etc/forkhub/repos.d/*.conf`, y audita + sincroniza los **15 forks** contra sus respectivos `upstream` (`forkhub upstream` y `forkhub sync-upstream --all`).
- **Etapa 1 (Criptografía, `/z` y Pacman):** Crea `/z` (`root:wheel`, `2775` + ACLs), importa y firma la clave GPG `E954119B629B58F6`, y activa el repositorio firmado `[omarchy-personal]`.
- **Etapa 2 (Convergencia de Rol):** En **Modo PADRE**, clona `/z/pj-omarchy`, ejecuta `./pj listo` para inicializar toda la flota (`fo-omarchy`, `fo-omarchy-pkgs`, `rf-omarchy-personal-repo`, `rf-fork-docs`, etc.) y activa el Modo Live (`omarchy dev link`). En **Modo HIJA**, actualiza paquetes y aprovisiona los perfiles de usuario.
- **Etapa 3 (Verificación):** Comprueba paquetes, base de datos `[omarchy-personal]` y estado del enlace de desarrollo.

### 2. Prompts Recomendados para Agentes IA (Antigravity / Cursor)

Si abres este repositorio en **Google Antigravity (`agy`)** o **Cursor**, puedes iniciar con cualquiera de estos prompts:

- **Para ejecutar el onboarding inicial de la máquina (Modo PADRE):**
  > *"Lee `AGENTS.md` y la nota `01.9`. Ejecuta el onboarding en Modo PADRE con `sudo ./scripts/omarchy-onboarding/onboard-machine.sh --padre` y verifica que quede con 0 cambios pendientes."*
- **Para desplegar o auditar todas las capas de la estación de trabajo (Capas 01 a 07):**
  > *"Lee `AGENTS.md` y `00 - MOC y Topologia/00.0 - Mapa General del Sistema (MOC).md`. Audita qué capas de la estación de trabajo faltan por aplicar en esta máquina (usuarios, `/z/nvims`, toolchain, Clavis, Nyxuri, synchub) y aplícalas de forma idempotente."*
- **Para auditar y sincronizar todos tus forks contra upstream:**
  > *"Ejecuta `./scripts/forkhub/forkhub upstream` y `./scripts/forkhub/forkhub sync-upstream --all` para verificar que toda mi flota de forks esté al día contra upstream."*

---

## 📖 Cómo Abrir este Vault en Obsidian

Este repositorio está estructurado como una bóveda (*vault*) nativa de **Obsidian**:
1. Abre **Obsidian**.
2. Selecciona **Open folder as vault** (Abrir carpeta como bóveda).
3. Selecciona la carpeta compartida: **`/z/PJ-NIRI-rf-omarchy-workstation`**.
4. Abre la nota principal: **`00 - MOC y Topologia/00.0 - Mapa General del Sistema (MOC).md`**.

### ⚓ Lanzadores Rápidos a los Hubs de Capa (Obsidian URI)

Si ya tienes la bóveda abierta o agregada en Obsidian, puedes saltar directamente a cualquier hub de capa haciendo clic en los enlaces de la tabla:

| Capa Arquitectónica | Hub Central de Capa | Lanzador Rápido Nativo |
|---|---|---|
| **Capa 00 — Topología & MOC** | [[00.0 - Mapa General del Sistema (MOC)\|00.0 - Mapa General del Sistema]] | [🚀 Abrir MOC Maestro](obsidian://open?vault=PJ-NIRI-rf-omarchy-workstation&file=00%20-%20MOC%20y%20Topologia%2F00.0%20-%20Mapa%20General%20del%20Sistema%20(MOC)) |
| **Capa 01 — Core del Sistema** | [[01.0 - Core del Sistema (MOC)\|01.0 - Core del Sistema (MOC)]] | [🚀 Abrir Capa 01](obsidian://open?vault=PJ-NIRI-rf-omarchy-workstation&file=01%20-%20Core%20del%20Sistema%2F01.0%20-%20Core%20del%20Sistema%20(MOC)) |
| **Capa 02 — Almacenamiento Compartido** | [[02.0 - Almacenamiento Compartido (MOC)\|02.0 - Almacenamiento Compartido]] | [🚀 Abrir Capa 02](obsidian://open?vault=PJ-NIRI-rf-omarchy-workstation&file=02%20-%20Almacenamiento%20Compartido%2F02.0%20-%20Almacenamiento%20Compartido%20(MOC)) |
| **Capa 03 — Toolchain Global** | [[03.0 - Toolchain Global y Estacion de Trabajo (MOC)\|03.0 - Toolchain Global]] | [🚀 Abrir Capa 03](obsidian://open?vault=PJ-NIRI-rf-omarchy-workstation&file=03%20-%20Toolchain%20Global%20y%20Estacion%20de%20Trabajo%2F03.0%20-%20Toolchain%20Global%20y%20Estacion%20de%20Trabajo%20(MOC)) |
| **Capa 04 — Entornos de Escritorio** | [[04.0 - Entornos de Escritorio (MOC)\|04.0 - Entornos de Escritorio]] | [🚀 Abrir Capa 04](obsidian://open?vault=PJ-NIRI-rf-omarchy-workstation&file=04%20-%20Entornos%20de%20Escritorio%2F04.0%20-%20Entornos%20de%20Escritorio%20(MOC)) |
| **Capa 05 — Suite Neovim Dual** | [[05.0 - Suite de Desarrollo Neovim (MOC)\|05.0 - Suite Neovim Dual]] | [🚀 Abrir Capa 05](obsidian://open?vault=PJ-NIRI-rf-omarchy-workstation&file=05%20-%20Suite%20de%20Desarrollo%20Neovim%2F05.0%20-%20Suite%20de%20Desarrollo%20Neovim%20(MOC)) |
| **Capa 06 — Dotfiles y Mantenimiento** | [[06.0 - Dotfiles y Ciclo de Vida (MOC)\|06.0 - Dotfiles y Ciclo de Vida]] | [🚀 Abrir Capa 06](obsidian://open?vault=PJ-NIRI-rf-omarchy-workstation&file=06%20-%20Dotfiles%20y%20Ciclo%20de%20Vida%20(MOC)) |
| **Capa 07 — Referencias del Sistema** | [[07.0 - Referencias del Sistema (MOC)\|07.0 - Referencias del Sistema]] | [🚀 Abrir Capa 07](obsidian://open?vault=PJ-NIRI-rf-omarchy-workstation&file=07%20-%20Referencias%20del%20Sistema%2F07.0%20-%20Referencias%20del%20Sistema%20(MOC)) |

---

## 🗺️ Estructura de Capas de la Estación de Trabajo

```text
PJ-NIRI-rf-omarchy-workstation/
├── 00 - MOC y Topologia/
│   ├── 00.0 - Mapa General del Sistema (MOC).md
│   └── 00.1 - Topologia de Usuarios y Perfiles.md
├── 01 - Core del Sistema/
│   ├── 01.1 - Sudo sin Contrasena (Passwordless Sudo).md
│   ├── 01.2 - Hardware y Graficos (Fix Parpadeo Intel i915).md
│   ├── 01.3 - Creacion de Usuarios y Cuentas de Sistema.md
│   ├── 01.4 - Display Manager y Sesiones SDDM (Herald OS).md
│   ├── 01.5 - Snapshots y Recuperacion con Btrfs.md
│   ├── 01.6 - Boveda de Secretos y Bootstrap Criptografico (age).md
│   ├── 01.7 - Usuario Especial Amnesico y Sandbox (guest).md
│   ├── 01.8 - Usuario Sandbox Btrfs Desechable (sandbox).md
│   └── 01.9 - Onboarding del Sistema y Repositorio Personal (Modo Padre DEV vs Hija).md
├── 02 - Almacenamiento Compartido/
│   ├── 02.1 - Directorio Compartido (z) y Permisos ACL.md
│   ├── 02.2 - Repositorio de Wallpapers y Medios (z).md
│   ├── 02.3 - Espacio Colaborativo z-drive y Sincronizacion Cloud.md
│   └── 02.4 - Suite Declarativa synchub y Automatizacion Udev.md
├── 03 - Toolchain Global y Estacion de Trabajo/
│   ├── 03.1 - Paquetes Globales y Navegadores Web.md
│   ├── 03.2 - Toolchain de Desarrollo (C, Rust, Node, Python).md
│   ├── 03.3 - Terminal GPU (Ghostty) y Multiplexores (tmux, herdr).md
│   ├── 03.4 - Tipografias y Fuentes del Sistema.md
│   ├── 03.5 - Ecosistema Google Antigravity y Android Studio Canary (BYOA).md
│   ├── 03.6 - Ecosistema Omarchy Personal Fork y Portal fork-docs.md
│   └── 03.7 - Flujo de Trabajo con Try y Directorios Efimeros (zt).md
├── 04 - Entornos de Escritorio/
│   ├── 04.1 - Niri Core (niri-edge y key-cli).md
│   ├── 04.2 - Desktop Flavor Clavis (Quickshell y Actualizaciones).md
│   ├── 04.3 - Apariencia Clavis (MacTahoe y Fcitx5).md
│   ├── 04.4 - Suite de Aplicaciones Clavis.md
│   ├── 04.5 - Desktop Flavor Nyxuri (Noctalia Shell y mpvpaper).md
│   └── 04.6 - Guia de Validacion Visual y Checklist Funcional (Clavis y Nyxuri).md
├── 05 - Suite de Desarrollo Neovim/
│   ├── 05.1 - Arquitectura Neovim Dual Compartida (z-nvims).md
│   └── 05.2 - Configuracion Craftzdog (nvim) y Distro Propia (rvim).md
├── 06 - Dotfiles y Ciclo de Vida/
│   ├── 06.1 - Gestion de Dotfiles con dotbare.md
│   ├── 06.2 - Validacion en Usuario Limpio (Testbench sura y nyxuri-test).md
│   └── 06.3 - Dotfiles de Omarchy para gracie (Planificado).md
├── 07 - Referencias del Sistema/
│   ├── 07.1 - Mapa Completo de Atajos de Teclado (Niri, Clavis, Nyxuri).md
│   ├── 07.2 - Repositorios Upstream y Fuentes Externas.md
│   ├── 07.3 - Guia de Video Showcase y Recursos Audiovisuales.md
│   ├── 07.4 - Archivos de Sistema de Referencia (assets-system).md
│   ├── 07.5 - Catalogo y Manual de Herramientas CLI del Playbook.md
│   └── 07.6 - Estandar de Duo Repositorios y Arbol de Decision (git-setup vs shared_dir).md
├── docs/adr/                                          # Registros de Decisiones de Arquitectura (ADR 0001, 0002)
├── scripts/
│   ├── omarchy-onboarding/onboard-machine.sh          # Asistente idempotente de onboarding (PADRE / HIJA)
│   ├── forkhub/forkhub                                # CLI de auditoría y sincronización de forks (upstream + local)
│   └── secrets/desbloquear-secretos.sh                # Bootstrap criptográfico con age
├── assets/
│   ├── system/                                        # Espejo exacto de archivos /etc y /usr
│   └── keys/omarchy-personal-repo.pub.asc             # Clave GPG pública de [omarchy-personal]
├── AGENTS.md                                          # Reglas de operación para agentes IA
└── README.md                                          # Portada principal
```

---

## 👥 Matriz de Usuarios y Perfiles

| Usuario | Rol en la Máquina | Entorno de Escritorio | Dotfiles y Gestión |
|---|---|---|---|
| **`<admin>`** (`rollo`, `omarchy`, etc.) | Administración del Sistema + Rol PADRE/HIJA | Omarchy / Hyprland base | Agnóstico del nombre de usuario (`wheel`) |
| **`niri`** | Producción Wayland Clavis | `niri-edge` + Clavis Shell | `robert-flo/niri-dotfiles` (dotbare) |
| **`sura`** (`niri-test`) | Testbench Visual Clavis | `niri-edge` + Clavis Shell | Desechable (recreable desde dotfiles) |
| **`nyxuri`** | Producción Wayland Nyxuri | `niri-edge` + Noctalia Shell | `robert-flo/PJ-NIRI-fo-nyxuri` (`personal`) |
| **`nyxuri-test`** | Testbench Visual Nyxuri | `niri-edge` + Noctalia Shell | Desechable (recreable desde dotfiles) |
| **`nyxuri-legacy`** | Escritorio Nyxuri Estable | `niri-edge` + Noctalia Stable | `ech678/Nyxuri` tag `v3.1.0` |
| **`guest`** | Entorno Amnésico Volátil (RAM) | Hyprland / Waybar aislado | `tmpfs` 8 GB (destrucción al logout) |
| **`sandbox`** | Entorno Amnésico GPU (Btrfs CoW) | Hyprland / Waybar aislado | Rollback instantáneo de subvolumen Btrfs |

---

## 📜 Créditos y Agradecimientos

- **Clavis Shell & Niri-edge:** [StatIndet](https://github.com/StatIndet) por la creación de Clavis, key-cli y personalizaciones estéticas.
- **Nyxuri / Noctalia:** [ech678](https://github.com/ech678) por la arquitectura modular de Nyxuri y Noctalia Shell.
- **Craftzdog Dotfiles:** [craftzdog](https://github.com/craftzdog) por la configuración de referencia de Neovim 0.12 con `vim.pack`.
- **Iconos y GTK MacTahoe:** [Vince Liuice](https://github.com/vinceliuice).
- **Proyectos Base:** [YaLTeR/niri](https://github.com/YaLTeR/niri), [outfoxxed/quickshell](https://github.com/outfoxxed/quickshell), [kazhala/dotbare](https://github.com/kazhala/dotbare), [InioX/matugen](https://github.com/InioX/matugen).

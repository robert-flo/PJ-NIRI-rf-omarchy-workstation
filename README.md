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
- **`Neovim Dual Compartido`**: Suite IDE basada en Neovim 0.12 con `vim.pack` (Fork Craftzdog) + distribución personal aislada (`rvim`) centralizadas en `/z/nvims`.
- **`Almacenamiento Compartido /z/`**: Espacio colaborativo multiusuario con setgid, ACLs y Git seguro.
- **`dotbare`**: Gestión profesional de dotfiles mediante repositorios Git bare directamente sobre `$HOME`.

---

## 📖 Cómo Abrir este Vault en Obsidian

Este repositorio está estructurado como una bóveda (*vault*) nativa de **Obsidian**:
1. Abre **Obsidian**.
2. Selecciona **Open folder as vault** (Abrir carpeta como bóveda).
3. Selecciona la carpeta de este repositorio: `2026-10-23-robert-flo-PJ-NIRI-rf-omarchy-workstation`.
4. Abre la nota principal: **`00 - MOC y Topologia/00.0 - Mapa General del Sistema (MOC).md`**.

Podrás navegar con enlaces bidireccionales (`[[wikilinks]]`), diagramas interactivos de Mermaid, visualización del Graph View por clusters temáticos, etiquetas (*tags*), bloques de alerta (*callouts*) y reproductores de video embebidos.

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
│   └── 01.5 - Snapshots y Recuperacion con Btrfs.md
├── 02 - Almacenamiento Compartido/
│   ├── 02.1 - Directorio Compartido (z) y Permisos ACL.md
│   └── 02.2 - Repositorio de Wallpapers y Medios (z).md
├── 03 - Toolchain Global y Estacion de Trabajo/
│   ├── 03.1 - Paquetes Globales y Navegadores Web.md
│   ├── 03.2 - Toolchain de Desarrollo (C, Rust, Node, Python).md
│   ├── 03.3 - Terminal GPU (Ghostty) y Multiplexores (tmux, herdr).md
│   └── 03.4 - Tipografias y Fuentes del Sistema.md
├── 04 - Entornos de Escritorio/
│   ├── 04.1 - Niri Core (niri-edge y key-cli).md
│   ├── 04.2 - Desktop Flavor Clavis (Quickshell y Actualizaciones).md
│   ├── 04.3 - Apariencia Clavis (MacTahoe y Fcitx5).md
│   ├── 04.4 - Suite de Aplicaciones Clavis.md
│   └── 04.5 - Desktop Flavor Nyxuri (Noctalia Shell y mpvpaper).md
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
│   └── 07.4 - Archivos de Sistema de Referencia (assets-system).md
├── assets/
│   ├── system/                                        # Espejo exacto de archivos /etc y /usr
│   ├── niri_showcase_unixporn_720p.mp4
│   ├── m2-res_1080p.mp4
│   ├── nyxury-showcase.mp4
│   └── nyxury-showcase-2.mp4
├── AGENTS.md                                          # Reglas de operación para agentes IA
└── README.md                                          # Portada principal
```

---

## 👥 Matriz de Usuarios y Perfiles

| Usuario | Rol en la Máquina | Entorno de Escritorio | Dotfiles y Gestión |
|---|---|---|---|
| **`omarchy` / `gracie`** | Administración del Sistema | Omarchy / Hyprland base | Dotfiles privados (`sura-home`) |
| **`niri`** | Producción Wayland Clavis | `niri-edge` + Clavis Shell | `robert-flo/niri-dotfiles` (dotbare) |
| **`sura`** | Testbench Visual Clavis | `niri-edge` + Clavis Shell | Desechable (recreable desde dotfiles) |
| **`nyxuri`** | Producción Wayland Nyxuri | `niri-edge` + Noctalia Shell | `robert-flo/PJ-NIRI-fo-nyxuri` |
| **`nyxuri-test`** | Testbench Visual Nyxuri | `niri-edge` + Noctalia Shell | Desechable (recreable desde dotfiles) |

---

## 📜 Créditos y Agradecimientos

- **Clavis Shell & Niri-edge:** [StatIndet](https://github.com/StatIndet) por la creación de Clavis, key-cli y personalizaciones estéticas.
- **Nyxuri / Noctalia:** [ech678](https://github.com/ech678) por la arquitectura modular de Nyxuri y Noctalia Shell.
- **Craftzdog Dotfiles:** [craftzdog](https://github.com/craftzdog) por la configuración de referencia de Neovim 0.12 con `vim.pack`.
- **Iconos y GTK MacTahoe:** [Vince Liuice](https://github.com/vinceliuice).
- **Proyectos Base:** [YaLTeR/niri](https://github.com/YaLTeR/niri), [outfoxxed/quickshell](https://github.com/outfoxxed/quickshell), [kazhala/dotbare](https://github.com/kazhala/dotbare), [InioX/matugen](https://github.com/InioX/matugen).

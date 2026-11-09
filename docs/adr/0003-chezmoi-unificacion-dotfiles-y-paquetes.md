---
title: "ADR 0003: Unificación de Dotfiles y Manifiesto de Paquetes en Chezmoi SSoT (rf-dotfiles)"
tags:
  - adr
  - arquitectura
  - dotfiles
  - chezmoi
  - pacman
  - idempotencia
aliases:
  - ADR 0003
  - Chezmoi SSoT Dotfiles y Paquetes
date: 2026-11-09
---

# 🏛️ ADR 0003: Unificación de Dotfiles y Manifiesto de Paquetes en Chezmoi SSoT (rf-dotfiles)

> [!NOTE]
> **Navegación y Metadatos:**
> * **Estado:** Aceptado (Vigente).
> * **Fecha:** 2026-11-09.
> * **Decisor:** Roberto Flores.
> * **Repositorio Canónico:** [robert-flo/rf-dotfiles](https://github.com/robert-flo/rf-dotfiles) (alojado en `/z/rf-dotfiles`).
> * **Vault de Referencia:** [[00.0 - Mapa General del Sistema (MOC)|MOC]], [[06.1 - Gestion de Dotfiles con dotbare|06.1 Dotfiles]], [[06.2 - Validacion en Usuario Limpio (Testbench sura y nyxuri-test)|06.2 Testbench]], [[docs/adr/0001-una-sola-puerta-y-meta-workspace|ADR 0001]].

---

## 1. Estado

**Aceptado**. Sustituye el modelo histórico fragmentado basado en múltiples repositorios huérfanos (`niri-dotfiles`, `sura-home`, `pj-domina-home_forever`, `PJ-LAETA-dotfiles`, `dotfiles-craftzdog`) y la gestión con `dotbare` por un **único repositorio canónico gestionado por [Chezmoi](https://www.chezmoi.io/)** (`robert-flo/rf-dotfiles`). Establece además que `.chezmoidata/packages.json` es la **Única Fuente de la Verdad (SSoT)** para la declaración de paquetes del sistema operativo, integrando la ejecución con `make converge` y `chezmoi apply`.

---

## 2. Contexto y Problemática Previa

Hasta la adopción de este ADR, la gestión de dotfiles y paquetes presentaba fricciones severas:

1. **Fragmentación y Cero Compartición:**
   - Cada perfil (`omarchy`, `niri`, `nyxuri`) tenía mecanismos dispares o inexistentes para dotfiles comunes (ej. `~/.config/lazygit/config.yml` pesaba 0 bytes en todos los usuarios salvo en `rollo`).
   - Existían 5 repositorios de dotfiles dispersos con ramas divergentes y configuraciones incompletas.
2. **Defasaje de Omarchy 4.6 (Dock del Workspace 1):**
   - El usuario inicial `rollo` y el entorno de pruebas `omarchy-test` no mostraban el dock de Omarchy 4.6 en el primer escritorio porque carecían del archivo de layout flotante `~/.local/state/omarchy/workspace-layouts/1.lua` exigido por el diseño upstream de Omarchy Quattro.
3. **Duplicidad de Listas de Paquetes:**
   - Los paquetes de Pacman oficiales, los paquetes del repositorio personal `[omarchy-personal]` y los paquetes de AUR estaban definidos como arrays bash estáticos dentro de `scripts/omarchy-onboarding/converge-workstation.sh`, desconectados de cualquier herramienta declarativa portable.
4. **Limitaciones de `dotbare` en Ambientes Multiusuario y Rutas Absolutas:**
   - La clonación bare (`dotbare finit` / `git clone --bare`) copiaba archivos con rutas absolutas estáticas (`/home/niri/...`), provocando que herramientas como `niri-dotfiles-postinstall` sufrieran colisiones por reemplazos de texto (ej. `/home/niri-test-test`).

---

## 3. Decisión

Se acuerdan e implementan de forma vinculante las siguientes directivas:

### 3.1. Creación del Repositorio Monorepo Canónico (`rf-dotfiles`)

Se consolida toda la configuración de dotfiles en un único repositorio Git:
- **URL remota:** `https://github.com/robert-flo/rf-dotfiles.git` (rama canónica `master`).
- **Ubicación central multiusuario:** `/z/rf-dotfiles` con permisos `2775`, propietario `root:wheel` y ACLs con herencia para que todos los usuarios del sistema puedan leer y aplicar los dotfiles sin duplicar almacenamiento.

### 3.2. Segregación Elegante de Perfiles vía `.chezmoiignore.tmpl`

Chezmoi detecta automáticamente el perfil del usuario mediante `.chezmoi.username` o la variable de entorno `CHEZMOI_PROFILE`:
- **Perfil Común (Compartido por todos):** `.config/lazygit/` (con Delta renderer y Commitizen integrado de Craftzdog), `.config/fish/`, `.config/alacritty/`, `.bashrc`.
- **Perfil Clavis (`niri`, `niri-test`, `sura`):** `.config/niri/`, `.config/clavis/`, temas MacTahoe GTK, MPV (uosc), Obsidian y hooks de postinstalación.
- **Perfil Omarchy (`rollo`, `omarchy-test`):** `.config/omarchy/` (con dock completo y relojes de mundo), `.local/state/omarchy/workspace-layouts/1.lua` (`floating`).
- **Perfil Nyxuri (`nyxuri`, `nyxuri-test`):** Recibe las herramientas comunes sin contaminación cruzada de otros entornos.

### 3.3. Rutas Absolutas Dinámicas con Plantillas Chezmoi

Todos los archivos que requieren rutas absolutas (`config.json`, `clavis-mpvpaper.conf`, `obsidian.json`) se convierten en plantillas `.tmpl` usando `{{ .chezmoi.homeDir }}`. Esto elimina por completo el uso de scripts destructivos con `sed` y garantiza 0 diffs en cualquier nombre de usuario (`niri`, `niri-test`, `sura`).

### 3.4. Manifiesto SSoT de Paquetes en `.chezmoidata/packages.json`

Se define el archivo declarativo `.chezmoidata/packages.json` con tres categorías:
- `packages.official`: Paquetes oficiales de Arch Linux (base-devel, compilers, Qt6, libs Wayland, Chezmoi, etc.).
- `packages.personal`: Paquetes empaquetados por `pj-omarchy` en `[omarchy-personal]` (`herdr`, suite `ravn-*`).
- `packages.aur`: Paquetes de AUR (`mpvpaper-git`, `android-studio-canary`, `google-chrome`, etc.).

### 3.5. Convergencia Dual: Playbook Orchestrator + Chezmoi Executor

1. **Chezmoi como Ejecutor Autónomo:**
   - Contiene el hook `run_onchange_before_01-install-packages.sh.tmpl` atado al hash SHA-256 de `packages.json`.
   - Cualquier invocación de `chezmoi apply` verifica e instala automáticamente paquetes faltantes si cuenta con privilegios sudo.
2. **`make converge` / `converge-workstation.sh` como Validador y Orquestador:**
   - La Capa 02 mantiene `/z/rf-dotfiles` sincronizado contra `origin/master`.
   - La Capa 03 lee directamente `packages.json` vía `jq` para auditar e instalar paquetes.
   - La Capa 04 ejecuta `sudo -u "$u" -H chezmoi apply --source=/z/rf-dotfiles --force` en todos los perfiles de forma 100% idempotente (0 cambios en subsecuentes ejecuciones).
3. **`make doctor`:**
   - Incorpora validación de salud de Chezmoi y conteo de paquetes declarados vs instalados.

---

## 4. Consecuencias y Beneficios

- **Reproducibilidad Inmediata:** Cualquier máquina nueva en modo PADRE o HIJA queda completamente aprovisionada clonando `/z/rf-dotfiles` y ejecutando `make converge`.
- **Cero Adivinanzas:** El usuario dispone de su entorno `lazygit` optimizado, shell fish y dock Omarchy 4.6 listo para usar en todos sus perfiles.
- **Idempotencia Estricta:** Las ejecuciones subsecuentes de `make converge` reportan exactamente `Cambios aplicados en capas 01-07: 0`.
- **Preservación Segura:** Los repositorios históricos (`sura-home`, `pj-domina-home_forever`, etc.) permanecen en staging en `~/Work/tries/dotfiles-staging/` para cherry-picking antes de cualquier archivado formal.

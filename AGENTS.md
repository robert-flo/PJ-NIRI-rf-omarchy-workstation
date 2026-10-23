# Reglas para agentes en este vault

Este repositorio es un vault de Obsidian que define y mantiene la **arquitectura integral, bootstrap y operación por capas de la estación de trabajo** (Niri, Clavis, Nyxuri, Neovim dual, almacenamiento compartido y toolchain global) sobre Omarchy/Arch Linux. Debe coincidir exactamente con lo que realmente está aplicado y funcionando en la máquina.

## Git

- Rama por defecto: `master` (nunca `main`).
- Nunca commit directo a `master`: rama auxiliar → push → PR a `master` → rebase sobre el `master` más reciente → merge → borrar la rama local y remota.
- Sin trailers `Co-authored-by` ni atribución a agentes. Si el entorno los inyecta en `git commit`, usar:
  ```bash
  git commit-tree "$(git write-tree)" -p HEAD -m "..."
  git update-ref refs/heads/<rama> <sha>
  ```
- Las mismas reglas aplican a `robert-flo/niri-dotfiles` (`master`) y a los forks (`personal`).

## Fuentes y upstream

- `niri-edge`, `quickshell` (Clavis), `key-cli` y `nyxuri` se compilan/sincronizan desde los forks de `robert-flo`, rama `personal` (ver capa `07 - Referencias del Sistema/07.2`).
- **Nunca abrir pull requests a StatIndet**: no acepta PRs hechos con IA. Los cambios entran por PR a `personal` del fork correspondiente.

## Entorno y Usuarios

- Usuarios del sistema:
  - `gracie` / `omarchy`: Administración del sistema + entorno Omarchy/Hyprland base.
  - `niri`: Producción de escritorio Wayland bajo Clavis Shell (Quickshell).
  - `sura`: Entorno de pruebas visuales y testbench para Clavis (desechable, se recrea desde dotfiles).
  - `nyxuri`: Producción de escritorio Wayland bajo Noctalia Shell / Nyxuri Engine.
  - `nyxuri-test`: Entorno de pruebas y testbench para Nyxuri (desechable).
- Configuración de usuario de `niri`/`sura`: `robert-flo/niri-dotfiles` con dotbare.
- Configuración de usuario de `nyxuri`/`nyxuri-test`: `robert-flo/PJ-NIRI-fo-nyxuri`.
- Almacenamiento compartido multiusuario: `/z/` (`/z/nvims`, `/z/wallpaper-collection`, `/z/nyxuri`) con permisos `2775` (setgid + wheel) y ACLs por defecto.
- Archivos de sistema (fuera de `$HOME`): copia exacta en `assets/system/<ruta absoluta>`. Si cambias uno en la máquina, actualiza su copia y la nota que lo explica (`07.4`).

## Formato y Estándares de las Notas en Obsidian

- Frontmatter YAML completo (`title`, `tags`, `aliases`, `date`).
- Callouts nativos de Obsidian (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`).
- Wikilinks estándar `[[Nombre de Nota|Texto visible]]`. En tablas Markdown, el pipe debe escaparse obligatoriamente como `\|`.
- Cada nota abre con su bloque de navegación superior (Anterior, Siguiente, Volver al MOC).
- Las notas `PENDIENTE - *.md` son de trabajo local y no se versionan (`.git/info/exclude`).

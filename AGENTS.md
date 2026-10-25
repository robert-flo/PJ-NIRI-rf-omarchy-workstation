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
  - `niri-test` (referenciado también como `sura`): Entorno de pruebas visuales y testbench para Clavis (desechable, se recrea desde dotfiles).
  - `nyxuri`: Producción de escritorio Wayland bajo Noctalia Shell / Nyxuri Engine (Edge T3 M4).
  - `nyxuri-test`: Entorno de pruebas y testbench para Nyxuri Edge (desechable).
  - `nyxuri-legacy`: Entorno de escritorio bajo Nyxuri Stable (tag `v3.1.0` de upstream).
- Configuración de usuario de `niri`/`niri-test`: `robert-flo/niri-dotfiles` con dotbare.
- Configuración de usuario de `nyxuri`/`nyxuri-test`: `robert-flo/PJ-NIRI-fo-nyxuri` (Edge).
- Configuración de usuario de `nyxuri-legacy`: `ech678/Nyxuri` tag `v3.1.0` (Estable).
- Almacenamiento compartido multiusuario: `/z/` (`/z/nvims`, `/z/wallpaper-collection`, `/z/nyxuri`) con permisos `2775` (setgid + wheel) y ACLs por defecto.
- Archivos de sistema (fuera de `$HOME`): copia exacta en `assets/system/<ruta absoluta>`. Si cambias uno en la máquina, actualiza su copia y la nota que lo explica (`07.4`).

### Protocolo de Wipe / Regeneración de Modificaciones en Usuarios

Cuando el usuario pida "wipe", "reseteo" o "regeneración a estado original" de las modificaciones de usuario:
1. **Obligatorio preguntar:** El agente **NUNCA** debe ejecutar el wipe a ciegas. Debe preguntar de forma explícita en cuáles usuarios se desea aplicar (generalmente serán los usuarios `*-test` como `niri-test` y `nyxuri-test`, pero permitiendo seleccionar o confirmar cuentas de producción como `niri`, `nyxuri` o `nyxuri-legacy`).
2. **Procedimiento formal:** Seguir los pasos detallados en la nota `[[06.2 - Validacion en Usuario Limpio (Testbench sura y nyxuri-test)]]` según la familia de configuración del usuario (dotbare vs nyxuri edge vs nyxuri stable).
3. **Persistencia Neovim:** Siempre re-enlazar la suite unificada de `/z/nvims/` (`nvim`, `rvim`, `2kvim`) y validar que levanten en modo `--headless`.
4. **Stack Android / Google:** Asegurar la presencia de variables `ANDROID_HOME` y rutas compartidas en `~/.bashrc` y `~/.config/fish/conf.d/android.fish`.

## Formato y Estándares de las Notas en Obsidian

- Frontmatter YAML completo (`title`, `tags`, `aliases`, `date`).
- Callouts nativos de Obsidian (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`).
- Wikilinks estándar `[[Nombre de Nota|Texto visible]]`. En tablas Markdown, el pipe debe escaparse obligatoriamente como `\|`.
- Cada nota abre con su bloque de navegación superior (Anterior, Siguiente, Volver al MOC).
- Las notas `PENDIENTE - *.md` son de trabajo local y no se versionan (`.git/info/exclude`).

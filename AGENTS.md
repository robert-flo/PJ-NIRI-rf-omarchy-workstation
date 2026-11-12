# Reglas para agentes en este vault

Este repositorio es un vault de Obsidian que define y mantiene la **arquitectura integral, bootstrap y operación por capas de la estación de trabajo** (Niri, Clavis, Nyxuri, Neovim dual, almacenamiento compartido, toolchain global y suite de desarrollo Google/Android) sobre Omarchy/Arch Linux. Debe coincidir exactamente con lo que realmente está aplicado y funcionando en la máquina.

---

## 🎯 Propósito, Visión y Principios Innegociables

Este repositorio (`PJ-NIRI-rf-omarchy-workstation`) persigue una visión fundamental de la cual ningún agente debe desviarse:

1. **Reproducibilidad e Idempotencia Absoluta:**
   - La arquitectura debe ser 100% reproducible en cualquier máquina Arch/Omarchy nueva o existente.
   - Cualquier script, playbook o procedimiento debe ser rigurosamente idempotente: ejecutarlo una o diez veces debe llevar siempre al mismo estado exacto, predecible y libre de errores (*el "punto dulce"* del sistema).

2. **Cero Adivinanzas (Zero-Guesswork Policy):**
   - El usuario no debe tener que reexplicar conceptos, decisiones o rutas previamente acordadas.
   - Todo componente debe estar formalmente documentado con pasos secuenciales, rutas canónicas y bloques de código listos para copiar y ejecutar directamente a su destino final.
   - Si un agente tiene dudas sobre el alcance de una acción destructiva (ej. wipes de usuario), debe preguntar explícitamente antes de actuar, pero nunca improvisar arquitectura o tomar atajos al margen de este vault.

3. **Arquitectura Espejo del Sistema (`assets/system/`):**
   - Ninguna configuración del sistema operativo (fuera de `$HOME`) debe quedar como un ajuste huérfano en la máquina.
   - Todo archivo de sistema (`/etc/`, `/usr/`, plantillas `/etc/skel/`, servicios systemd, reglas de sudoers, etc.) **DEBE** tener su copia exacta e idéntica en `assets/system/<ruta absoluta>` y estar registrado en [[07.4 - Archivos de Sistema de Referencia (assets-system)]].
   - *Regla de oro:* Si cambias un archivo en la máquina, actualizas su espejo en el vault; si despliegas en una máquina nueva, se instala desde `assets/system/`.
   - *Nota de arquitectura y gobernanza:* La única puerta a `/` es `pacman` (paquetes publicados por `pj-omarchy` en `robert-flo/omarchy-personal-repo`). `assets/system/` queda reservado exclusivamente para configuraciones en `/etc/` y huérfanos sin empaquetar. Ver [[docs/adr/0001-una-sola-puerta-y-meta-workspace|ADR 0001 — Una Sola Puerta y Meta-Workspace]].

4. **El "Punto Dulce" Multi-Usuario Permanente:**
   - Todos los perfiles gestionados (`omarchy`, `niri`, `nyxuri`, etc.) deben disponer de sus herramientas compartidas (Neovim dual, SDK oficial de Android, fondos de pantalla, binarios globales) listas para usar sin fricción ni configuraciones manuales repetitivas en cada usuario.

5. **Decisiones de Arquitectura Formalizadas (ADR):**
   - Las decisiones arquitectónicas de fondo están formalizadas en los registros de decisiones (ADR). Consultá [[docs/adr/0001-una-sola-puerta-y-meta-workspace|ADR 0001 — Una Sola Puerta y Meta-Workspace]] para el modelo de empaquetado, meta-workspace `/z/pj-omarchy` y convergencia del onboarding.

6. **Única Fuente Canónica de Atajos de Teclado (SSoT):**
   - El documento oficial y canónico de referencia para todos los atajos de teclado y keybindings de la estación de trabajo (Niri, Clavis, Quickshell suite y módulos auxiliares) reside **exclusivamente** en [[07.1 - Mapa Completo de Atajos de Teclado (Niri, Clavis, Nyxuri)]].
   - **Regla de oro:** Cualquier adición, ajuste o eliminación de keybindings en la configuración activa (`config.kdl`, Chezmoi en `/z/rf-dotfiles`, llamadas IPC de Clavis, etc.) **DEBE reflejarse de inmediato en la nota 07.1**.
   - No se permiten atajos huérfanos sin documentar ni copias duplicadas fuera del vault. La nota `07.1` debe mantenerse siempre 100% confiable y al día con lo que realmente opera en el escritorio.

---

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

- Usuarios del sistema (agnóstico del nombre de usuario administrador principal de cada máquina: ej. `rollo`, `omarchy`, etc.):
  - `<admin>` (`rollo`, `omarchy`, etc.): Administración del sistema + entorno Omarchy/Hyprland base (nunca asumir un nombre fijo como `omarchy`; cualquier máquina con cualquier nombre de usuario puede tomar rol PADRE o HIJA).
  - `niri`: Producción de escritorio Wayland bajo Clavis Shell (Quickshell).
  - `niri-classic`: Entorno de escritorio bajo Clavis Shell Classic (rama `personal-classic` con banner de perfil y sección device settings restaurados, aislado en `/opt/clavis-classic`).
  - `niri-test` (referenciado también como `sura`): Entorno de pruebas visuales y testbench para Clavis (desechable, se recrea desde dotfiles).
  - `nyxuri`: Producción de escritorio Wayland bajo Noctalia Shell / Nyxuri Engine (Edge T3 M4).
  - `nyxuri-test`: Entorno de pruebas y testbench para Nyxuri Edge (desechable).
  - `nyxuri-legacy`: Entorno de escritorio bajo Nyxuri Stable (tag `v3.1.0` de upstream).
  - `guest`: Entorno amnésico volátil montado en RAM (`tmpfs` 8GB, destrucción inmediata al logout).
  - `sandbox`: Entorno amnésico desechable de alto rendimiento sobre Btrfs CoW (aceleración GPU nativa, rollback automático en 3 capas al arranque, login y logout).
- Configuración unificada de dotfiles y manifiesto de paquetes: `robert-flo/rf-dotfiles` con **Chezmoi** (alojado en `/z/rf-dotfiles`, ver [[docs/adr/0003-chezmoi-unificacion-dotfiles-y-paquetes|ADR 0003]]).
- Configuración de usuario de `nyxuri`/`nyxuri-test`: `robert-flo/PJ-NIRI-fo-nyxuri` (Edge) y dotfiles compartidos vía Chezmoi.
- Configuración de usuario de `nyxuri-legacy`: `ech678/Nyxuri` tag `v3.1.0` (Estable).
- Almacenamiento compartido multiusuario: `/z/` (`/z/rf-dotfiles`, `/z/nvims`, `/z/wallpaper-collection`, `/z/nyxuri`) con permisos `2775` (setgid + wheel) y ACLs por defecto.
- Archivos de sistema (fuera de `$HOME`): copia exacta en `assets/system/<ruta absoluta>`. Si cambias uno en la máquina, actualiza su copia y la nota que lo explica (`07.4`).

### Protocolo de Wipe / Regeneración de Modificaciones en Usuarios

Cuando el usuario pida "wipe", "reseteo" o "regeneración a estado original" de las modificaciones de usuario:
1. **Obligatorio preguntar:** El agente **NUNCA** debe ejecutar el wipe a ciegas. Debe preguntar de forma explícita en cuáles usuarios se desea aplicar (generalmente serán los usuarios `*-test` como `niri-test` y `nyxuri-test`, pero permitiendo seleccionar o confirmar cuentas de producción como `niri`, `nyxuri` o `nyxuri-legacy`).
2. **Procedimiento formal:** Seguir los pasos detallados en la nota `[[06.2 - Validacion en Usuario Limpio (Testbench sura y nyxuri-test)]]` según la familia de configuración del usuario (dotbare vs nyxuri edge vs nyxuri stable).
3. **Persistencia Neovim:** La suite unificada de `/z/nvims/` (`nvim`, `rvim`, `cvim`, `2kvim`) opera nativamente vía XDG (`XDG_CONFIG_DIRS="/z/nvims"`) sin requerir symlinks de usuario; validar siempre que levanten limpiamente en modo `--headless`.
4. **Stack Android / Google:** Asegurar la presencia de variables `ANDROID_HOME` y rutas compartidas en `~/.bashrc` y `~/.config/fish/conf.d/android.fish`.

## Formato y Estándares de las Notas en Obsidian

- Frontmatter YAML completo (`title`, `tags`, `aliases`, `date`).
- Callouts nativos de Obsidian (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`).
- Wikilinks estándar `[[Nombre de Nota|Texto visible]]`. En tablas Markdown, el pipe debe escaparse obligatoriamente como `\|`.
- Cada nota abre con su bloque de navegación superior (Anterior, Siguiente, Volver al MOC).
- Las notas `PENDIENTE - *.md` son de trabajo local y no se versionan (`.git/info/exclude`).

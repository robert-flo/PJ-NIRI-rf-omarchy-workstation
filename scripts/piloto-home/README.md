# Suite Piloto Home por Capas (`scripts/piloto-home/`)

Esta suite implementa el arnés de pruebas automatizado y reproducible para el experimento de **$HOME por capas** ([#40](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/40), [#48](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/48)), diseñado para evaluar y comparar métodos de configuración en cuentas de usuario desechables del sistema.

---

## 🛡️ Principios Innegociables de Seguridad

1. **Restricción Estricta a Usuarios `*-test`:**
   - La suite valida de forma estricta que el usuario objetivo termine en `-test` (ej. `niri-test`, `omarchy-test`, `nyxuri-test`).
   - Cualquier intento de operar sobre cuentas de producción (`omarchy`, `niri`, `nyxuri`, `root`, etc.) o nombres genéricos es abortado de inmediato con código de error fatal.
2. **Aislamiento Btrfs sin Formateos:**
   - El home del usuario opera sobre su propio subvolumen Btrfs independiente dentro de `@home` (`/home/<usuario>`).
   - El proceso de wipe borra y recrea el subvolumen específico; **nunca** formatea discos ni altera particiones.
3. **Protección de Almacenamiento Compartido (`/z` y `/z-drive`):**
   - Nunca se siguen ni desreferencian enlaces simbólicos que apunten hacia `/z`, `/z-drive` o bóvedas.
4. **Idempotencia Absoluta:**
   - La captura de snapshots verifica si el destino ya existe; no lo sobrescribe a menos que se especifique explícitamente `--force-snapshot`.
5. **Persistencia Limpia de Logs y Reportes:**
   - Toda salida, diff y registro se almacena en `~/.local/state/piloto-home/` del usuario que ejecuta el comando.
   - **Nunca** se escribe en `/tmp` (volátil/inseguro) ni en `/z-drive`.

---

## 📁 Estructura de la Suite

```text
scripts/piloto-home/
├── piloto-home.sh       # CLI principal con subcomandos por fase
├── test-piloto-home.sh  # Suite de pruebas unitarias y validación dry-run
├── README.md            # Documentación técnica de uso y arquitectura
└── plugins/             # Plugins modulares de despliegue por método
    ├── niri-actual.sh     # Método actual: dotbare + niri-dotfiles + postinstall
    ├── niri-nuevo.sh      # Método nuevo: pacman ravn-home-* + perfil dotbare + sync
    ├── hyprland-actual.sh # Stub enchufable para Omarchy / Hyprland actual
    └── hyprland-nuevo.sh  # Stub enchufable para paquetes ravn-home-hyprland
```

---

## 🚀 Subcomandos

### 1. `wipe`
Limpia completamente el home del usuario desechable asegurando aislamiento en Btrfs:
1. Crea un snapshot de seguridad en `/home/.<usuario>-snaps/safety-pre-wipe-<timestamp>`.
2. Detiene el servicio de systemd del usuario (`user@<uid>`) y termina procesos residuales.
3. Elimina y recrea el subvolumen Btrfs `/home/<usuario>`.
4. Restaura permisos estrictos (`0700`) y propiedad `<usuario>:<usuario>`.

```bash
./scripts/piloto-home/piloto-home.sh wipe --user niri-test
```

### 2. `deploy <metodo>`
Despliega la configuración del usuario invocando el plugin correspondiente:
- **`niri-actual`**: Clona el repositorio bare con `dotbare finit` (`robert-flo/niri-dotfiles`, rama `master`) y ejecuta `~/.local/bin/niri-dotfiles-postinstall`.
- **`niri-nuevo`**: Instala los paquetes Pacman del sistema (`sudo pacman -S --needed ravn-home-common ravn-home-niri`), despliega el perfil de usuario con dotbare y corre `ravn-home-sync`.
- **`hyprland-actual` / `hyprland-nuevo`**: Stubs enchufables para `omarchy-test`.

```bash
./scripts/piloto-home/piloto-home.sh deploy niri-actual --user niri-test
./scripts/piloto-home/piloto-home.sh deploy niri-nuevo --user niri-test
```

### 3. `snapshot <etiqueta>`
Captura un snapshot Btrfs de solo lectura del estado actual de `/home/<usuario>` en `/home/.<usuario>-snaps/<etiqueta>`. Es completamente idempotente:

```bash
./scripts/piloto-home/piloto-home.sh snapshot snap-niri-test-metodo-actual --user niri-test
```

Para forzar la sobreescritura si ya existe:
```bash
./scripts/piloto-home/piloto-home.sh snapshot snap-niri-test-metodo-actual --user niri-test --force-snapshot
```

### 4. `diff <origen_a> <origen_b>`
Compara dos snapshots o directorios aplicando exclusiones de ruido volátil (`.cache`, `.local/state`, `.local/share/Trash`, historiales de shell, sockets, locks, logs, temporales). Genera un reporte Markdown detallado en `~/.local/state/piloto-home/`:

```bash
./scripts/piloto-home/piloto-home.sh diff backup-pre-piloto-20261026/niri-test snap-niri-test-metodo-actual --user niri-test
```

### 5. `checklist`
Imprime en pantalla y guarda en log el protocolo de verificación manual para comprobar la funcionalidad del escritorio vía SDDM:

```bash
./scripts/piloto-home/piloto-home.sh checklist --user niri-test
```

Puntos auditados:
- Inicio limpio desde SDDM.
- Compositor Niri (navegación por columnas y workspaces).
- Barra Clavis / Quickshell (widgets, lanzador, notificaciones).
- Terminal Alacritty/Foot y temas Matugen.
- Shell Bash/Fish (prompt, variables, toolchain).
- Fcitx5 (método de entrada).
- Apariencia GTK (prefer-light/dark, cursor, íconos).
- Neovim dual (`rvim --headless`, `2kvim --headless`).

### 6. `run`
Encadena el flujo completo de prueba (`wipe` → `deploy` → `snapshot`) en una sola orden:

```bash
./scripts/piloto-home/piloto-home.sh run --user niri-test --metodo niri-actual --etiqueta snap-niri-test-metodo-actual
```

Soporta simulación con `--dry-run`:
```bash
./scripts/piloto-home/piloto-home.sh run --user niri-test --metodo niri-nuevo --dry-run
```

---

## 🧪 Pruebas Automatizadas

La suite incluye pruebas estáticas con `shellcheck` y pruebas de comportamiento en modo `--dry-run` y con fixtures en espacio de usuario:

```bash
./scripts/piloto-home/test-piloto-home.sh
```

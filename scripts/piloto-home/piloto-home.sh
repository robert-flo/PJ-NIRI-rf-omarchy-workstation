#!/usr/bin/env bash
# scripts/piloto-home/piloto-home.sh
# Suite reproducible de pruebas para validación de $HOME por capas en usuarios *-test (#40, #48).
#
# Subcomandos:
#   wipe                   - Snapshot de seguridad, detiene user@uid y recrea subvolumen /home/<u>
#   deploy <metodo>        - Despliega dotfiles/perfil según plugin (niri-actual, niri-nuevo, hyprland-*)
#   snapshot <etiqueta>    - Crea snapshot btrfs de solo lectura (idempotente)
#   diff <a> <b>           - Compara dos snapshots con exclusiones y genera reporte
#   checklist              - Imprime el protocolo de verificación manual para sesión SDDM
#   run                    - Encadena las fases de prueba (soporta --dry-run)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="${SCRIPT_DIR}/plugins"

# Determinar usuario y home del invocador (nunca root para reportes)
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    CALLER_USER="$SUDO_USER"
    CALLER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    CALLER_USER="$(id -un)"
    CALLER_HOME="${HOME:-/home/$CALLER_USER}"
fi

# Variables por defecto
TARGET_USER=""
TARGET_UID=""
TARGET_HOME=""
METODO=""
ETIQUETA=""
SNAP_DIR=""
FORCE_SNAPSHOT=0
DRY_RUN=0
VERBOSE=0
export VERBOSE
PROFILE_REPO="https://github.com/robert-flo/ravn-home-profile-niri.git"
PROFILE_BRANCH="main"
DOTFILES_REPO="https://github.com/robert-flo/niri-dotfiles.git"
DOTFILES_BRANCH="master"
STATE_DIR="${CALLER_HOME}/.local/state/piloto-home"

# Exclusiones estándar para diff
DIFF_EXCLUDES=(
    "-x" ".cache"
    "-x" "state"
    "-x" "Trash"
    "-x" ".bash_history"
    "-x" ".zsh_history"
    "-x" "*history*"
    "-x" "*.hist"
    "-x" "*.log"
    "-x" "*.sock"
    "-x" "*.lock"
    "-x" "*.pid"
    "-x" "*.swp"
    "-x" "*~"
    "-x" "*.tmp"
    "-x" "FETCH_HEAD"
)

log() {
    echo "==> $*"
}

log_error() {
    echo "ERROR: $*" >&2
}

log_warn() {
    echo "AVISO: $*" >&2
}

# -----------------------------------------------------------------------------
# Validaciones duras de seguridad
# -----------------------------------------------------------------------------
validar_usuario_test() {
    local u="$1"
    if [[ -z "$u" ]]; then
        log_error "Debe especificar un usuario con --user <usuario> (ej. niri-test)."
        exit 1
    fi

    # Requisito duro: solo usuarios que terminen en -test
    if [[ ! "$u" =~ ^[a-zA-Z0-9._-]+-test$ ]]; then
        log_error "Operación rechazada. El usuario '${u}' NO termina en '-test'."
        log_error "REQUISITO DURO DE SEGURIDAD: Esta suite opera EXCLUSIVAMENTE sobre usuarios desechables *-test."
        exit 1
    fi

    if ! id "$u" >/dev/null 2>&1; then
        log_error "El usuario '${u}' no existe en este sistema."
        exit 1
    fi

    TARGET_UID="$(id -u "$u")"
    TARGET_HOME="$(getent passwd "$u" | cut -d: -f6)"

    if [[ "$TARGET_HOME" != "/home/${u}" ]]; then
        log_error "El HOME del usuario '${u}' debe residir estrictamente en /home/${u} (detectado: '${TARGET_HOME}')."
        exit 1
    fi

    if [[ -z "$SNAP_DIR" ]]; then
        SNAP_DIR="/home/.${u}-snaps"
    fi
}

asegurar_state_dir() {
    if [[ ! -d "$STATE_DIR" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "[DRY-RUN] Crearía directorio de estado en ${STATE_DIR}"
            return 0
        fi
        mkdir -p "$STATE_DIR"
        chmod 700 "$STATE_DIR"
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            chown -R "${CALLER_USER}:${CALLER_USER}" "$STATE_DIR"
        fi
    fi
}

es_subvolumen() {
    local path="$1"
    if [[ $EUID -eq 0 ]]; then
        btrfs subvolume show "$path" >/dev/null 2>&1
    else
        sudo btrfs subvolume show "$path" >/dev/null 2>&1
    fi
}

# -----------------------------------------------------------------------------
# Fase 1: Wipe
# -----------------------------------------------------------------------------
cmd_wipe() {
    validar_usuario_test "$TARGET_USER"
    asegurar_state_dir

    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local safety_snap="${SNAP_DIR}/safety-pre-wipe-${ts}"

    log "[wipe] Iniciando wipe controlado para usuario desechable '${TARGET_USER}'..."
    log "       Home: ${TARGET_HOME} (UID: ${TARGET_UID})"
    log "       Directorio de snapshots: ${SNAP_DIR}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[DRY-RUN] [wipe] Crearía snapshot de seguridad en ${safety_snap}"
        log "[DRY-RUN] [wipe] Detendría servicio user@${TARGET_UID} y procesos de ${TARGET_USER}"
        log "[DRY-RUN] [wipe] Eliminaría y recrearía subvolumen btrfs ${TARGET_HOME}"
        log "[DRY-RUN] [wipe] Asignaría dueño ${TARGET_USER}:${TARGET_USER} y permisos 700"
        return 0
    fi

    # 1. Asegurar directorio de snapshots
    if [[ ! -d "$SNAP_DIR" ]]; then
        log "[wipe] Creando directorio de snapshots en ${SNAP_DIR}..."
        sudo mkdir -p "$SNAP_DIR"
        sudo chmod 700 "$SNAP_DIR"
    fi

    # 2. Snapshot de seguridad previo
    if [[ -d "$TARGET_HOME" ]]; then
        log "[wipe] Creando snapshot de seguridad antes de wipe: ${safety_snap}..."
        if es_subvolumen "$TARGET_HOME"; then
            sudo btrfs subvolume snapshot -r "$TARGET_HOME" "$safety_snap"
        else
            log_warn "[wipe] ${TARGET_HOME} no es un subvolumen btrfs; creando copia reflink de seguridad..."
            sudo cp -a --reflink=auto --no-dereference "$TARGET_HOME" "$safety_snap"
        fi
    fi

    # 3. Detener servicios de systemd del usuario
    log "[wipe] Deteniendo servicios de usuario (user@${TARGET_UID})..."
    if sudo systemctl is-active --quiet "user@${TARGET_UID}"; then
        sudo systemctl stop "user@${TARGET_UID}" || true
    fi
    sudo pkill -u "$TARGET_USER" -9 2>/dev/null || true
    sleep 0.3

    # 4. Borrar y recrear subvolumen sin seguir symlinks hacia /z ni /z-drive
    log "[wipe] Recreando subvolumen dedicado en ${TARGET_HOME}..."
    if [[ -e "$TARGET_HOME" ]]; then
        if es_subvolumen "$TARGET_HOME"; then
            sudo btrfs subvolume delete "$TARGET_HOME"
        else
            local tmp_backup="/home/.${TARGET_USER}-wipe-old-${ts}"
            sudo mv "$TARGET_HOME" "$tmp_backup"
            # Eliminación segura sin seguir symlinks
            sudo rm -rf --no-preserve-root "$tmp_backup"
        fi
    fi

    sudo btrfs subvolume create "$TARGET_HOME"
    sudo chown "${TARGET_USER}:${TARGET_USER}" "$TARGET_HOME"
    sudo chmod 700 "$TARGET_HOME"

    log "[wipe] Subvolumen btrfs /home/${TARGET_USER} recreado en estado limpio (modo 700)."
}

# -----------------------------------------------------------------------------
# Fase 2: Deploy <metodo>
# -----------------------------------------------------------------------------
cmd_deploy() {
    local metodo="$1"
    validar_usuario_test "$TARGET_USER"
    asegurar_state_dir

    if [[ -z "$metodo" ]]; then
        log_error "Debe especificar un método de despliegue (ej. niri-actual, niri-nuevo, hyprland-actual, hyprland-nuevo)."
        exit 1
    fi

    local plugin_script="${PLUGINS_DIR}/${metodo}.sh"
    if [[ ! -f "$plugin_script" ]]; then
        # Buscar variantes o scripts directos
        if [[ -f "$metodo" ]]; then
            plugin_script="$metodo"
        else
            log_error "No se encontró el plugin de despliegue para método '${metodo}' en ${PLUGINS_DIR}."
            exit 1
        fi
    fi

    log "[deploy] Ejecutando plugin de despliegue '${metodo}' para ${TARGET_USER}..."

    # Exportar variables de entorno para el plugin
    export TARGET_USER
    export TARGET_HOME
    export TARGET_UID
    export PROFILE_REPO
    export PROFILE_BRANCH
    export DOTFILES_REPO
    export DOTFILES_BRANCH
    export DRY_RUN

    bash "$plugin_script"
}

# -----------------------------------------------------------------------------
# Fase 3: Snapshot <etiqueta>
# -----------------------------------------------------------------------------
cmd_snapshot() {
    local etiqueta="$1"
    validar_usuario_test "$TARGET_USER"
    asegurar_state_dir

    if [[ -z "$etiqueta" ]]; then
        log_error "Debe especificar una etiqueta para el snapshot (ej. snap-niri-test-metodo-actual)."
        exit 1
    fi

    local target_snap="${SNAP_DIR}/${etiqueta}"
    log "[snapshot] Verificando snapshot '${target_snap}'..."

    # Idempotencia: si ya existe y no se forzó, terminar limpiamente con exit 0
    if [[ -e "$target_snap" ]]; then
        if [[ "$FORCE_SNAPSHOT" -eq 1 ]]; then
            log "[snapshot] Snapshot existente detectado. --force-snapshot activo: reemplazando..."
            if [[ "$DRY_RUN" -eq 1 ]]; then
                log "[DRY-RUN] [snapshot] Eliminaría snapshot anterior ${target_snap}"
                log "[DRY-RUN] [snapshot] Crearía snapshot read-only de ${TARGET_HOME} en ${target_snap}"
                return 0
            fi
            if es_subvolumen "$target_snap"; then
                sudo btrfs subvolume delete "$target_snap"
            else
                sudo rm -rf "$target_snap"
            fi
        else
            log "[snapshot] Snapshot '${target_snap}' ya existe. Omitiendo recreación (idempotente)."
            log "           (Usá --force-snapshot para sobreescribir)."
            return 0
        fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[DRY-RUN] [snapshot] Crearía snapshot de solo lectura: sudo btrfs subvolume snapshot -r ${TARGET_HOME} ${target_snap}"
        return 0
    fi

    if [[ ! -d "$SNAP_DIR" ]]; then
        sudo mkdir -p "$SNAP_DIR"
        sudo chmod 700 "$SNAP_DIR"
    fi

    log "[snapshot] Creando snapshot read-only en ${target_snap}..."
    sudo btrfs subvolume snapshot -r "$TARGET_HOME" "$target_snap"

    log "[snapshot] Snapshot creado exitosamente:"
    sudo btrfs subvolume show "$target_snap" | grep -E "(Name|UUID|Flags)" || true
}

# -----------------------------------------------------------------------------
# Fase 4: Diff <a> <b>
# -----------------------------------------------------------------------------
resolver_ruta_snap() {
    local ruta="$1"
    if [[ -e "$ruta" ]] || sudo test -e "$ruta" 2>/dev/null; then
        echo "$ruta"
        return 0
    fi

    # Probar con SNAP_DIR
    if [[ -n "$SNAP_DIR" ]]; then
        if [[ -e "${SNAP_DIR}/${ruta}" ]] || sudo test -e "${SNAP_DIR}/${ruta}" 2>/dev/null; then
            echo "${SNAP_DIR}/${ruta}"
            return 0
        fi
    fi

    # Probar con /home/.niri-test-snaps si no se definió
    if [[ -e "/home/.niri-test-snaps/${ruta}" ]] || sudo test -e "/home/.niri-test-snaps/${ruta}" 2>/dev/null; then
        echo "/home/.niri-test-snaps/${ruta}"
        return 0
    fi

    echo "$ruta"
}

cmd_diff() {
    local origen_a="$1"
    local origen_b="$2"

    if [[ -n "$TARGET_USER" ]]; then
        validar_usuario_test "$TARGET_USER"
    fi
    asegurar_state_dir

    if [[ -z "$origen_a" || -z "$origen_b" ]]; then
        log_error "Uso: diff <origen_a> <origen_b> [--user <usuario>]"
        exit 1
    fi

    local ruta_a
    local ruta_b
    ruta_a="$(resolver_ruta_snap "$origen_a")"
    ruta_b="$(resolver_ruta_snap "$origen_b")"

    log "[diff] Comparando snapshots:"
    log "       A: ${ruta_a}"
    log "       B: ${ruta_b}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[DRY-RUN] [diff] Simulación de comparación entre ${ruta_a} y ${ruta_b}"
        return 0
    fi

    # Validar existencia de ambas rutas (con sudo si SNAP_DIR es root)
    if ! sudo test -e "$ruta_a"; then
        log_error "La ruta o snapshot A no existe: ${ruta_a}"
        exit 1
    fi
    if ! sudo test -e "$ruta_b"; then
        log_error "La ruta o snapshot B no existe: ${ruta_b}"
        exit 1
    fi

    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local label_a
    local label_b
    label_a="$(basename "$ruta_a")"
    label_b="$(basename "$ruta_b")"
    local report_file="${STATE_DIR}/diff-${label_a}-vs-${label_b}-${ts}.md"

    log "[diff] Ejecutando diff con exclusiones..."
    log "       Exclusiones: .cache, state, Trash, historiales, *.log, *.sock, *.lock, *.pid..."

    local raw_output
    raw_output="$(sudo diff -r --no-dereference --brief "${DIFF_EXCLUDES[@]}" "$ruta_a" "$ruta_b" 2>&1 || true)"

    # Clasificar diferencias
    local only_a=()
    local only_b=()
    local differ=()
    local special=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^"Only in ${ruta_a}" ]]; then
            only_a+=("${line#"Only in "}")
        elif [[ "$line" =~ ^"Only in ${ruta_b}" ]]; then
            only_b+=("${line#"Only in "}")
        elif [[ "$line" =~ ^"Files ".*" differ" ]]; then
            differ+=("$line")
        else
            special+=("$line")
        fi
    done <<< "$raw_output"

    # Redactar reporte estructurado
    {
        echo "# Reporte de Diff Piloto Home"
        echo ""
        echo "- **Fecha:** $(date "+%Y-%m-%d %H:%M:%S %Z")"
        echo "- **Origen A:** \`${ruta_a}\`"
        echo "- **Origen B:** \`${ruta_b}\`"
        echo "- **Exclusiones aplicadas:** \`.cache\`, \`.local/state\`, \`.local/share/Trash\`, historiales de shell (\`*history*\`), sockets (\`*.sock\`), locks/pids (\`*.lock\`, \`*.pid\`), temporales."
        echo ""
        echo "## Resumen Cuantitativo"
        echo ""
        echo "| Métrica | Cantidad |"
        echo "| --- | ---: |"
        echo "| Elementos exclusivos de A | ${#only_a[@]} |"
        echo "| Elementos exclusivos de B | ${#only_b[@]} |"
        echo "| Archivos modificados/diferentes | ${#differ[@]} |"
        echo "| Diferencias especiales (symlinks/tipos) | ${#special[@]} |"
        echo ""
        
        echo "## 1. Elementos Solo en A (\`${label_a}\`)"
        if [[ ${#only_a[@]} -gt 0 ]]; then
            echo '```text'
            printf '%s\n' "${only_a[@]}"
            echo '```'
        else
            echo "_Ninguno._"
        fi
        echo ""

        echo "## 2. Elementos Solo en B (\`${label_b}\`)"
        if [[ ${#only_b[@]} -gt 0 ]]; then
            echo '```text'
            printf '%s\n' "${only_b[@]}"
            echo '```'
        else
            echo "_Ninguno._"
        fi
        echo ""

        echo "## 3. Archivos que Difieren en Contenido"
        if [[ ${#differ[@]} -gt 0 ]]; then
            echo '```text'
            printf '%s\n' "${differ[@]}"
            echo '```'
        else
            echo "_Ninguno._"
        fi
        echo ""

        if [[ ${#special[@]} -gt 0 ]]; then
            echo "## 4. Diferencias de Tipo de Archivo / Symlinks"
            echo '```text'
            printf '%s\n' "${special[@]}"
            echo '```'
            echo ""
        fi

        echo "## 5. Salida en Bruto Completa"
        echo '```text'
        echo "$raw_output"
        echo '```'
    } > "$report_file"

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        chown "${CALLER_USER}:${CALLER_USER}" "$report_file" 2>/dev/null || true
    fi

    log "[diff] Reporte generado exitosamente en:"
    log "       ${report_file}"
    echo ""
    echo "--- RESUMEN DE DIFERENCIAS ---"
    echo "Solo en A: ${#only_a[@]}"
    echo "Solo en B: ${#only_b[@]}"
    echo "Diferentes: ${#differ[@]}"
    echo "Especiales: ${#special[@]}"
    echo "------------------------------"
}

# -----------------------------------------------------------------------------
# Fase 5: Checklist
# -----------------------------------------------------------------------------
cmd_checklist() {
    local target="${TARGET_USER:-niri-test}"
    asegurar_state_dir

    cat << 'EOF'

===============================================================================
       PROTOCOLO DE VERIFICACIÓN MANUAL SDDM - PILOTO HOME POR CAPAS
===============================================================================

1. Inicio de Sesión SDDM:
   [ ] Cerrar sesión actual o cambiar a SDDM (Ctrl+Alt+F1 / Logout).
   [ ] Seleccionar el usuario objetivo en la lista de usuarios.
   [ ] Seleccionar la sesión correspondiente (ej. 'Niri' o 'Hyprland').
   [ ] Ingresar contraseña y confirmar arranque limpio sin errores visuales.

2. Compositor Niri:
   [ ] Escritorio Wayland inicia sin cuelgues ni parpadeos anómalos.
   [ ] Navegación de columnas con teclado:
       - Super+Left / Super+Right (desplazamiento horizontal fluido).
       - Super+Shift+Left / Super+Shift+Right (mover ventanas entre columnas).
   [ ] Gestión de workspaces (Super+1 .. Super+9).

3. Shell Clavis (Quickshell):
   [ ] Barra superior visible y responsiva.
   [ ] Widgets operativos: reloj, estado de red, selector de layout de teclado.
   [ ] Lanzador de aplicaciones / Control Center (Super+Space o clic de ratón).
   [ ] Notificaciones de escritorio renderizadas correctamente.

4. Terminal y Entorno de Entrada:
   [ ] Abrir terminal Alacritty / Foot con Super+Enter.
   [ ] Colores de paleta Matugen aplicados al terminal.
   [ ] Renderizado correcto de glifos Nerd Fonts y espaciado de texto.

5. Shell Interactivo (Bash / Fish):
   [ ] Prompt interactivo cargado con decoraciones y tema activo.
   [ ] PATH operativo: acceso a binarios globales (/usr/bin, /usr/local/bin, ~/.local/bin).
   [ ] Toolchain compartido operativo (git, mise, etc.).

6. Método de Entrada Fcitx5:
   [ ] Ícono de Fcitx5 presente en la bandeja de la barra.
   [ ] Conmutación de método de entrada con Ctrl+Space operativa en terminal y apps.

7. Apariencia y Theming GTK:
   [ ] Modo claro / oscuro respetado según configuración preferida.
   [ ] Tema de íconos (Papirus / MacTahoe) y tema de cursor consistente en ventanas GTK.

8. Suite Neovim Dual (/z/nvims):
   [ ] Ejecutar rvim --headless y confirmar carga sin advertencias de plugins.
   [ ] Ejecutar 2kvim --headless y confirmar carga de isolated pack.

===============================================================================
EOF

    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local check_log="${STATE_DIR}/checklist-${target}-${ts}.txt"
    if [[ "$DRY_RUN" -ne 1 ]]; then
        echo "Checklist SDDM desplegado para ${target} en $(date)" > "$check_log"
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            chown "${CALLER_USER}:${CALLER_USER}" "$check_log" 2>/dev/null || true
        fi
        log "[checklist] Registro de checklist guardado en: ${check_log}"
    fi
}

# -----------------------------------------------------------------------------
# Fase 6: Run (orquestador)
# -----------------------------------------------------------------------------
cmd_run() {
    validar_usuario_test "$TARGET_USER"

    log "[run] Iniciando corrida de prueba para ${TARGET_USER}..."
    if [[ -z "$METODO" ]]; then
        log_error "Debe especificar un método con --metodo <nombre> para encadenar."
        exit 1
    fi

    local etiqueta="${ETIQUETA:-snap-${TARGET_USER}-${METODO}}"

    # Paso 1: Wipe
    log "[run] Paso 1: Wipe de /home/${TARGET_USER}..."
    cmd_wipe

    # Paso 2: Deploy
    log "[run] Paso 2: Despliegue con método '${METODO}'..."
    cmd_deploy "$METODO"

    # Paso 3: Snapshot
    log "[run] Paso 3: Captura de snapshot con etiqueta '${etiqueta}'..."
    cmd_snapshot "$etiqueta"

    log "[run] Corrida completada exitosamente."
}

# -----------------------------------------------------------------------------
# CLI y Argumentos
# -----------------------------------------------------------------------------
mostrar_ayuda() {
    cat << EOF
Uso: $(basename "$0") <subcomando> [opciones]

Subcomandos disponibles:
  wipe                   Realiza wipe seguro de /home/<u> (subvolumen btrfs dedicado).
  deploy <metodo>        Despliega dotfiles con el método especificado (niri-actual, niri-nuevo, etc.).
  snapshot <etiqueta>    Crea snapshot btrfs de solo lectura (idempotente).
  diff <a> <b>           Compara dos snapshots con exclusiones estándar y guarda reporte.
  checklist              Imprime el protocolo de verificación manual para sesión SDDM.
  run                    Encadena wipe -> deploy -> snapshot en una sola operación.

Opciones:
  -u, --user <usuario>       Usuario objetivo (OBLIGATORIO que termine en '-test').
  -m, --metodo <nombre>      Método de despliegue para 'deploy' o 'run'.
  -l, --etiqueta <nombre>    Etiqueta para 'snapshot' o 'run'.
  -s, --snap-dir <dir>       Directorio base de snapshots (default: /home/.<usuario>-snaps).
  --force-snapshot           Fuerza la sobreescritura de un snapshot existente.
  --profile-repo <url>       URL del repositorio de perfil dotbare (default: ravn-home-profile-niri).
  --profile-branch <rama>    Rama del repositorio de perfil (default: master).
  --dotfiles-repo <url>      URL del repositorio de dotfiles tradicional (default: niri-dotfiles).
  --dotfiles-branch <rama>   Rama del repositorio de dotfiles (default: master).
  --state-dir <dir>          Directorio de logs/reportes (default: ~/.local/state/piloto-home).
  --dry-run                  Simula la ejecución sin aplicar cambios en el sistema.
  -v, --verbose              Salida detallada.
  -h, --help                 Muestra esta ayuda.

Ejemplos:
  $(basename "$0") diff backup-pre-piloto-20261026/niri-test snap-niri-test-metodo-actual --user niri-test
  $(basename "$0") checklist --user niri-test
  $(basename "$0") wipe --user niri-test --dry-run
  $(basename "$0") deploy niri-actual --user niri-test --dry-run
  $(basename "$0") run --user niri-test --metodo niri-actual --etiqueta snap-niri-test-metodo-actual --dry-run
EOF
}

if [[ $# -eq 0 ]]; then
    mostrar_ayuda
    exit 0
fi

SUBCOMANDO="$1"
shift

# Parsing de argumentos posicionales adicionales para subcomandos específicos
POS_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            TARGET_USER="$2"
            shift 2
            ;;
        -m|--metodo)
            METODO="$2"
            shift 2
            ;;
        -l|--etiqueta)
            ETIQUETA="$2"
            shift 2
            ;;
        -s|--snap-dir)
            SNAP_DIR="$2"
            shift 2
            ;;
        --force-snapshot)
            FORCE_SNAPSHOT=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --profile-repo)
            PROFILE_REPO="$2"
            shift 2
            ;;
        --profile-branch)
            PROFILE_BRANCH="$2"
            shift 2
            ;;
        --dotfiles-repo)
            DOTFILES_REPO="$2"
            shift 2
            ;;
        --dotfiles-branch)
            DOTFILES_BRANCH="$2"
            shift 2
            ;;
        --state-dir)
            STATE_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        -*)
            log_error "Opción desconocida: $1"
            mostrar_ayuda
            exit 1
            ;;
        *)
            POS_ARGS+=("$1")
            shift
            ;;
    esac
done

case "$SUBCOMANDO" in
    wipe)
        cmd_wipe
        ;;
    deploy)
        metodo_param="${POS_ARGS[0]:-$METODO}"
        cmd_deploy "$metodo_param"
        ;;
    snapshot)
        etiqueta_param="${POS_ARGS[0]:-$ETIQUETA}"
        cmd_snapshot "$etiqueta_param"
        ;;
    diff)
        if [[ ${#POS_ARGS[@]} -lt 2 ]]; then
            log_error "Uso: diff <origen_a> <origen_b> [--user <usuario>]"
            exit 1
        fi
        cmd_diff "${POS_ARGS[0]}" "${POS_ARGS[1]}"
        ;;
    checklist)
        cmd_checklist
        ;;
    run)
        cmd_run
        ;;
    help|--help|-h)
        mostrar_ayuda
        ;;
    *)
        log_error "Subcomando desconocido: '$SUBCOMANDO'"
        mostrar_ayuda
        exit 1
        ;;
esac

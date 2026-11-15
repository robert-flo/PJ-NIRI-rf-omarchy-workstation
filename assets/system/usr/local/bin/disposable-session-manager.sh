#!/usr/bin/env bash
# ==============================================================================
# disposable-session-manager.sh — Gestor de Sesiones Desechables con Chezmoi
# ==============================================================================
# Regenera de forma idempotente, automática y prístina el $HOME de los usuarios
# desechables (niri-upstream, niri-test, nyxuri, nyxuri-test, nyxuri-legacy,
# omarchy-test) al iniciar sesión vía PAM (Greetd/SDDM/TTY) o mediante comando CLI.
#
# Flujo en cada inicio de sesión (open_session):
# 1. Purgado total amnésico de $HOME (eliminación completa de estado residual).
# 2. Despliegue fresco y canónico desde /z/rf-dotfiles vía Chezmoi SSoT.
# 3. Post-aprovisionamiento especializado según la familia de escritorio:
#    - niri-upstream: Configuración pura StatIndet upstream desde /opt/clavis-upstream.
#    - niri-test: Verificación de paleta Matugen y servicios Clavis Shell.
#    - nyxuri / nyxuri-test: Despliegue modular de unidades Noctalia / Nyxuri Engine.
#    - omarchy-test: Layout de espacio de trabajo flotante en workspace 1.
# ==============================================================================

set -eo pipefail

LOG_FILE="/var/log/disposable-sessions.log"
CHEZMOI_SOURCE="/z/rf-dotfiles"

# Matriz de usuarios desechables gestionados
DISPOSABLE_USERS=(
    "niri-upstream"
    "niri-test"
    "nyxuri"
    "nyxuri-test"
    "nyxuri-legacy"
    "omarchy-test"
)

# Cuentas estrictamente protegidas (prohibido purgar)
PROTECTED_USERS=(
    "root"
    "rollo"
    "niri"
    "niri-classic"
    "guest"
    "sandbox"
)

log() {
    local msg="[$(date "+%Y-%m-%d %H:%M:%S")] [disposable-manager] $*"
    echo "$msg"
    if [[ -w "$LOG_FILE" ]] || [[ ! -e "$LOG_FILE" && -w "/var/log" ]]; then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

is_disposable() {
    local user="$1"
    for u in "${DISPOSABLE_USERS[@]}"; do
        if [[ "$u" == "$user" ]]; then
            return 0
        fi
    done
    return 1
}

is_protected() {
    local user="$1"
    for u in "${PROTECTED_USERS[@]}"; do
        if [[ "$u" == "$user" ]]; then
            return 0
        fi
    done
    return 1
}

reset_user() {
    local target_user="$1"

    if is_protected "$target_user"; then
        log "ERROR DE SEGURIDAD: Intento de purgar usuario protegido '$target_user'. Operación abortada."
        return 1
    fi

    if ! is_disposable "$target_user"; then
        log "Aviso: '$target_user' no está registrado en la lista de usuarios desechables."
        return 0
    fi

    if ! id "$target_user" >/dev/null 2>&1; then
        log "Aviso: El usuario '$target_user' no existe en el sistema. Omitiendo."
        return 0
    fi

    local target_home
    target_home="$(getent passwd "$target_user" | cut -d: -f6)"
    local target_uid
    target_uid="$(id -u "$target_user")"
    local target_gid
    target_gid="$(id -g "$target_user")"

    # Barrera de contención defensiva
    if [[ -z "$target_home" || "$target_home" == "/" || "$target_home" == "/root" || "$target_home" == "/home" ]]; then
        log "ERROR CRÍTICO: Ruta de home no válida o peligrosa: '$target_home'. Abortando."
        return 1
    fi

    log "Iniciando regeneración amnésica prístina para '$target_user' en '$target_home'..."

    # 1. Terminar procesos residuales del usuario si no es una sesión PAM interactiva
    if [[ -z "${PAM_USER:-}" ]]; then
        pkill -u "$target_uid" -9 2>/dev/null || true
        sleep 0.2
    fi

    # 2. Asegurar existencia del directorio home con permisos iniciales
    mkdir -p "$target_home"
    chmod 700 "$target_home"
    chown "$target_uid:$target_gid" "$target_home"

    # 3. Purga total amnésica de $HOME (elimina todo archivo o subcarpeta)
    log "Vaciando contenido completo de '$target_home'..."
    find "$target_home" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

    # 4. Despliegue canónico de Dotfiles vía Chezmoi SSoT
    if [[ -d "$CHEZMOI_SOURCE" ]]; then
        log "Aplicando Chezmoi SSoT desde $CHEZMOI_SOURCE para '$target_user'..."
        sudo -u "$target_user" -H chezmoi apply --source="$CHEZMOI_SOURCE" --force 2>/dev/null || {
            log "Advertencia: chezmoi apply retornó código distinto de cero para '$target_user'."
        }
    else
        log "ERROR: No se encontró el repositorio central de dotfiles en $CHEZMOI_SOURCE."
    fi

    # 5. Post-aprovisionamiento especializado por familia de entorno
    case "$target_user" in
        niri-upstream)
            log "Configurando entorno de referencia pura vanilla (niri-upstream)..."
            # Validar sintaxis de niri
            if [[ -f "$target_home/.config/niri/config.kdl" ]]; then
                sudo -u "$target_user" niri validate -c "$target_home/.config/niri/config.kdl" >/dev/null 2>&1 || true
            fi
            ;;

        niri-test)
            log "Configurando entorno de pruebas Clavis (niri-test)..."
            # Generar paleta Matugen inicial si el script del sistema está disponible
            if [[ -x /etc/xdg/quickshell/clavis/scripts/theme/generate_matugen_colors.sh ]]; then
                sudo -u "$target_user" -H /etc/xdg/quickshell/clavis/scripts/theme/generate_matugen_colors.sh >/dev/null 2>&1 || true
            fi
            if [[ -f "$target_home/.config/niri/config.kdl" ]]; then
                sudo -u "$target_user" niri validate -c "$target_home/.config/niri/config.kdl" >/dev/null 2>&1 || true
            fi
            ;;

        nyxuri|nyxuri-test)
            log "Desplegando unidades modulares Nyxuri Engine para '$target_user'..."
            # Enlazar colección compartida local /z/wallpaper-collection evitando descargas por red
            if [[ -d /z/wallpaper-collection ]]; then
                mkdir -p "$target_home/Pictures"
                ln -snf /z/wallpaper-collection "$target_home/Pictures/Wallpapers"
            fi

            local base_units="niri noctalia kitty fastfetch fish starship theme xdg-desktop-portal zed"
            local optional_units="fcitx5-rime greeter mango obsidian-theme"
            local shell_units="shell.bar shell.desktopcards shell.dock shell.launcher shell.lock shell.notifications shell.regionselector shell.session shell.settings shell.sidebars shell.wallpaper"

            if [[ -x /usr/local/bin/nyxuri ]]; then
                for unit in $base_units $optional_units $shell_units; do
                    sudo -u "$target_user" env NYXURI_TEST_MODE=1 /usr/local/bin/nyxuri on "$unit" >/dev/null 2>&1 || true
                done
                sudo -u "$target_user" -H /usr/local/bin/nyxuri shell set nyxuri-shell /usr/local/bin/nyxuri-shell >/dev/null 2>&1 || true
            fi

            if [[ -d /opt/src/nyxuri ]]; then
                sudo -u "$target_user" -H python3 -c "import sys; sys.path.insert(0, '/opt/src/nyxuri'); from nyxuri.deploy.templates import _phase_render_templates; _phase_render_templates()" >/dev/null 2>&1 || true
            fi

            if [[ -f "$target_home/.config/niri/config.kdl" ]]; then
                sudo -u "$target_user" niri validate -c "$target_home/.config/niri/config.kdl" >/dev/null 2>&1 || true
            fi
            ;;

        nyxuri-legacy)
            log "Configurando entorno Nyxuri Stable (nyxuri-legacy)..."
            if [[ -f "$target_home/.config/niri/config.kdl" ]]; then
                sudo -u "$target_user" niri validate -c "$target_home/.config/niri/config.kdl" >/dev/null 2>&1 || true
            fi
            ;;

        omarchy-test)
            log "Configurando entorno de prueba Omarchy 4.6 (omarchy-test)..."
            # Chezmoi ya despliega ~/.local/state/omarchy/workspace-layouts/1.lua
            ;;
    esac

    # 6. Sincronización y consistencia de permisos finales
    chown -R "$target_uid:$target_gid" "$target_home"
    chmod 700 "$target_home"

    log "¡Regeneración completada con éxito para '$target_user'!"
    return 0
}

# ==============================================================================
# Flujo 1: Invocación interactiva vía PAM (pam_exec.so)
# ==============================================================================
if [[ -n "${PAM_USER:-}" ]]; then
    # Solo actuar en la apertura de sesión
    if [[ "${PAM_TYPE:-}" != "open_session" ]]; then
        exit 0
    fi

    # Verificar si el usuario que abre sesión es desechable
    if is_disposable "$PAM_USER"; then
        log "PAM open_session interceptado para '$PAM_USER'. Procediendo con regeneración..."
        reset_user "$PAM_USER"
        exit 0
    fi

    exit 0
fi

# ==============================================================================
# Flujo 2: Invocación manual vía CLI / Scripts
# ==============================================================================
COMMAND="${1:-}"

case "$COMMAND" in
    reset)
        TARGET="${2:-}"
        if [[ -z "$TARGET" ]]; then
            echo "Uso: $0 reset <usuario|all>"
            exit 1
        fi

        if [[ "$TARGET" == "all" ]]; then
            echo "==> Reseteando todos los usuarios desechables..."
            for u in "${DISPOSABLE_USERS[@]}"; do
                reset_user "$u"
            done
            echo "==> Todos los usuarios desechables fueron regenerados exitosamente."
        else
            reset_user "$TARGET"
        fi
        ;;

    list)
        echo "Usuarios desechables gestionados:"
        for u in "${DISPOSABLE_USERS[@]}"; do
            echo "  - $u"
        done
        ;;

    status)
        echo "=== Estado de Usuarios Desechables ==="
        for u in "${DISPOSABLE_USERS[@]}"; do
            if id "$u" >/dev/null 2>&1; then
                u_home="$(getent passwd "$u" | cut -d: -f6)"
                file_count=$(sudo find "$u_home" -mindepth 1 2>/dev/null | wc -l || echo 0)
                echo "  [✓] $u (Home: $u_home, Elementos: $file_count)"
            else
                echo "  [✗] $u (No existe en /etc/passwd)"
            fi
        done
        ;;

    help|--help|-h|"")
        echo "Uso: $0 <comando> [argumentos]"
        echo ""
        echo "Comandos disponibles:"
        echo "  reset <usuario>    Regenera y purga de forma amnésica el usuario especificado."
        echo "  reset all          Regenera y purga todos los usuarios desechables."
        echo "  list               Lista los usuarios configurados como desechables."
        echo "  status             Muestra el estado de cada cuenta desechable en el sistema."
        echo ""
        echo "Invocación PAM:"
        echo "  Configurado en /etc/pam.d/system-login para ejecutarse automáticamente en open_session."
        ;;

    *)
        echo "Comando desconocido: $COMMAND. Ejecuta '$0 help' para más información."
        exit 1
        ;;
esac

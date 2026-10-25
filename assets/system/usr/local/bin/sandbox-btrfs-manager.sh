#!/usr/bin/env bash
#
# sandbox-btrfs-manager.sh: Gestor de Sesión Amnésica Desechable con Btrfs CoW
# Restaura instantáneamente /home/sandbox desde la plantilla /home/.sandbox-golden
# al cerrar sesión o por comando administrativo, con velocidad nativa de NVMe.
#

set -eo pipefail

LOG_FILE="/var/log/sandbox-btrfs.log"
TARGET_USER="sandbox"
TARGET_HOME="/home/sandbox"
GOLDEN_SUBVOL="/home/.sandbox-golden"

log() {
    local msg="[$(date "+%Y-%m-%d %H:%M:%S")] [sandbox-btrfs] $*"
    echo "$msg"
    if [[ -w "$LOG_FILE" ]] || [[ ! -e "$LOG_FILE" && -w "/var/log" ]]; then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

ensure_golden() {
    if [[ ! -d "$GOLDEN_SUBVOL" ]]; then
        log "Creando subvolumen dorado en $GOLDEN_SUBVOL..."
        btrfs subvolume create "$GOLDEN_SUBVOL"
    fi
}

do_rollback() {
    log "Ejecutando rollback instantáneo CoW para 'sandbox'..."
    ensure_golden

    # 1. Terminar procesos residuales
    if id "$TARGET_USER" &>/dev/null; then
        local user_uid
        user_uid=$(id -u "$TARGET_USER")
        pkill -u "$TARGET_USER" -9 2>/dev/null || true
        systemctl stop "user@${user_uid}.service" 2>/dev/null || true
    fi

    sleep 0.5

    # 2. Eliminar subvolumen modificado si existe
    if [[ -d "$TARGET_HOME" ]]; then
        if btrfs subvolume show "$TARGET_HOME" >/dev/null 2>&1; then
            log "Eliminando subvolumen anterior de $TARGET_HOME..."
            btrfs subvolume delete "$TARGET_HOME" >/dev/null 2>&1 || rm -rf "$TARGET_HOME"
        else
            rm -rf "$TARGET_HOME"
        fi
    fi

    # 3. Crear nuevo snapshot instantáneo desde la plantilla dorada
    log "Creando nuevo snapshot limpio en $TARGET_HOME..."
    btrfs subvolume snapshot "$GOLDEN_SUBVOL" "$TARGET_HOME" >/dev/null

    # 4. Asegurar permisos estrictos
    chown -R "${TARGET_USER}:${TARGET_USER}" "$TARGET_HOME"
    chmod 700 "$TARGET_HOME"

    log "¡Rollback completado con éxito! Entorno restaurado a estado de fábrica."
}

# Invocación desde PAM (pam_exec.so)
if [[ -n "${PAM_USER:-}" ]]; then
    if [[ "$PAM_USER" != "$TARGET_USER" ]]; then
        exit 0
    fi

    case "${PAM_TYPE:-}" in
        open_session)
            # Si no existe el home, inicializarlo
            if [[ ! -d "$TARGET_HOME" ]]; then
                do_rollback
            fi
            exit 0
            ;;
        close_session)
            # Comprobar si quedan otras sesiones activas del usuario
            active_sessions=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$TARGET_USER" "$3 == u {print $1}" | wc -l)
            if [[ $active_sessions -le 1 ]]; then
                do_rollback
            fi
            exit 0
            ;;
        *)
            exit 0
            ;;
    esac
fi

# Invocación manual / CLI
case "${1:-}" in
    reset|rollback)
        do_rollback
        ;;
    status)
        if [[ -d "$TARGET_HOME" ]] && btrfs subvolume show "$TARGET_HOME" >/dev/null 2>&1; then
            echo "Estado: [ACTIVO] Subvolumen Btrfs operativo en $TARGET_HOME:"
            btrfs subvolume show "$TARGET_HOME" | grep -E "Name|Creation time|Subvolume ID"
            df -h "$TARGET_HOME"
        else
            echo "Estado: [INACTIVO] $TARGET_HOME no es un subvolumen activo."
        fi
        ;;
    *)
        echo "Uso: sandbox-btrfs-manager.sh [reset|rollback|status]"
        exit 1
        ;;
esac

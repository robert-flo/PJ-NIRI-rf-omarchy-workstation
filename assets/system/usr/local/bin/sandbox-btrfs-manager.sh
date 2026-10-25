#!/usr/bin/env bash
#
# sandbox-btrfs-manager.sh: Gestor de Sesión Amnésica Desechable con Btrfs CoW
# Restaura instantáneamente /home/sandbox desde la plantilla /home/.sandbox-golden
# al arrancar el sistema, al iniciar sesión, al cerrar sesión o por comando manual.
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
    log "Ejecutando rollback instantáneo CoW para '$TARGET_USER'..."
    ensure_golden

    # 1. Terminar de forma contundente cualquier proceso residual del usuario
    if id "$TARGET_USER" &>/dev/null; then
        local user_uid
        user_uid=$(id -u "$TARGET_USER")
        pkill -u "$TARGET_USER" -9 2>/dev/null || true
    fi

    sleep 0.3

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

    # 4. Asegurar propiedad y permisos estrictos
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
            # En login inicial, garantizar un snapshot 100% fresco y limpio
            log "PAM open_session detectado para '$TARGET_USER'. Forzando snapshot limpio..."
            do_rollback
            exit 0
            ;;
        close_session)
            log "PAM close_session detectado para '$TARGET_USER'. Ejecutando limpieza y rollback..."
            do_rollback
            exit 0
            ;;
        *)
            exit 0
            ;;
    esac
fi

# Invocación manual / CLI / systemd
case "${1:-}" in
    reset|rollback|start|stop)
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

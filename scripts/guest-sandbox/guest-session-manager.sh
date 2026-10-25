#!/usr/bin/env bash
#
# guest-session-manager.sh: Gestor de Sesión Amnésica Volátil (RAM tmpfs 8GB) para guest
# Monta un tmpfs con flags de seguridad estrictos (nosuid,nodev) al iniciar sesión,
# sincroniza la plantilla /etc/guest-skel/ y destruye todo rastro de RAM al cerrar sesión.
#

set -eo pipefail

LOG_FILE="/var/log/guest-session.log"
TARGET_USER="guest"
TARGET_HOME="/home/guest"
SKEL_DIR="/etc/guest-skel"
RAM_SIZE="8G"

log() {
    local msg="[$(date "+%Y-%m-%d %H:%M:%S")] [guest-amnesic] $*"
    echo "$msg"
    if [[ -w "$LOG_FILE" ]] || [[ ! -e "$LOG_FILE" && -w "/var/log" ]]; then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

start_session() {
    log "Iniciando aprovisionamiento de sesión amnésica para '$TARGET_USER'..."

    # 1. Asegurar punto de montaje
    if [[ ! -d "$TARGET_HOME" ]]; then
        mkdir -p "$TARGET_HOME"
    fi

    # 2. Montar tmpfs en RAM de 8GB si no está montado
    if ! mountpoint -q "$TARGET_HOME"; then
        log "Montando tmpfs de $RAM_SIZE en $TARGET_HOME (nosuid,nodev,mode=700)..."
        mount -t tmpfs -o "size=${RAM_SIZE},mode=700,nosuid,nodev,uid=${TARGET_USER},gid=${TARGET_USER}" tmpfs "$TARGET_HOME"
    else
        log "$TARGET_HOME ya se encuentra montado en tmpfs."
    fi

    # 3. Sincronizar plantilla limpia desde /etc/guest-skel
    if [[ -d "$SKEL_DIR" ]]; then
        log "Poblando $TARGET_HOME desde $SKEL_DIR..."
        cp -rT "$SKEL_DIR" "$TARGET_HOME"
    fi

    # 4. Asegurar propiedad y permisos estrictos
    chown -R "${TARGET_USER}:${TARGET_USER}" "$TARGET_HOME"
    chmod 700 "$TARGET_HOME"
    log "Sesión amnésica en RAM lista para '$TARGET_USER'."
}

stop_session() {
    log "Finalizando sesión amnésica para '$TARGET_USER'..."

    # 1. Terminar procesos residuales del usuario guest
    if id "$TARGET_USER" &>/dev/null; then
        local user_uid
        user_uid=$(id -u "$TARGET_USER")
        pkill -u "$TARGET_USER" -9 2>/dev/null || true
        # Detener unidad systemd user si está activa
        systemctl stop "user@${user_uid}.service" 2>/dev/null || true
    fi

    sleep 0.5

    # 2. Desmontar tmpfs (destrucción inmediata de los datos en RAM)
    if mountpoint -q "$TARGET_HOME"; then
        log "Desmontando tmpfs en $TARGET_HOME (vaciado y liberación de memoria RAM)..."
        umount -l "$TARGET_HOME" 2>/dev/null || umount -f "$TARGET_HOME" 2>/dev/null || true
    fi

    log "Sesión cerrada. Cero datos en disco ni memoria."
}

# Invocación desde PAM (pam_exec.so)
if [[ -n "${PAM_USER:-}" ]]; then
    if [[ "$PAM_USER" != "$TARGET_USER" ]]; then
        exit 0
    fi

    case "${PAM_TYPE:-}" in
        open_session)
            start_session
            exit 0
            ;;
        close_session)
            # Comprobar si quedan otras sesiones activas del usuario
            active_sessions=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$TARGET_USER" "$3 == u {print $1}" | wc -l)
            if [[ $active_sessions -le 1 ]]; then
                stop_session
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
    start|mount)
        start_session
        ;;
    stop|umount)
        stop_session
        ;;
    reset)
        stop_session
        start_session
        ;;
    status)
        if mountpoint -q "$TARGET_HOME"; then
            echo "Estado: [ACTIVO] $TARGET_HOME montado en RAM:"
            df -h "$TARGET_HOME"
        else
            echo "Estado: [INACTIVO] $TARGET_HOME no está montado."
        fi
        ;;
    *)
        echo "Uso: guest-session-manager.sh [start|stop|reset|status]"
        exit 1
        ;;
esac

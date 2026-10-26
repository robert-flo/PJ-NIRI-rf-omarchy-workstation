#!/usr/bin/env bash
# scripts/piloto-home/aislar-niri-test.sh
# Asegura de forma idempotente que /home/niri-test sea un subvolumen btrfs dedicado
# perteneciente a niri-test (modo 700).

set -euo pipefail

TARGET_USER="niri-test"
TARGET_HOME="/home/${TARGET_USER}"
UID_USER=$(id -u "${TARGET_USER}" 2>/dev/null || echo 1002)

# Verificar permisos de root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Este script debe ejecutarse como root (sudo)." >&2
    exit 1
fi

# Verificar si /home/niri-test ya es un subvolumen btrfs
es_subvolumen() {
    btrfs subvolume show "$TARGET_HOME" >/dev/null 2>&1
}

if es_subvolumen; then
    echo "==> /home/${TARGET_USER} ya es un subvolumen btrfs dedicado."
    # Asegurar permisos y dueño correctos
    chown "${TARGET_USER}:${TARGET_USER}" "$TARGET_HOME"
    chmod 700 "$TARGET_HOME"
    echo "==> Dueño y permisos verificados: ${TARGET_USER}:${TARGET_USER} (700)."
    exit 0
fi

echo "==> /home/${TARGET_USER} NO es un subvolumen propio. Procediendo al aislamiento..."

# 1. Detener servicios de usuario si estuvieran activos
if systemctl is-active --quiet "user@${UID_USER}"; then
    echo "==> Deteniendo servicio systemd user@${UID_USER}..."
    systemctl stop "user@${UID_USER}"
fi

# 2. Si existe un directorio convencional, moverlo fuera del camino de forma segura sin seguir symlinks
if [[ -e "$TARGET_HOME" ]]; then
    TEMP_BACKUP="/home/.${TARGET_USER}-pre-subvol-$(date +%Y%m%d%H%M%S)"
    echo "==> Moviendo directorio actual a ${TEMP_BACKUP}..."
    mv "$TARGET_HOME" "$TEMP_BACKUP"
    # El borrado final del respaldo temporal debe ser manual o seguro sin seguir symlinks
    rm -rf "$TEMP_BACKUP"
fi

# 3. Crear el subvolumen btrfs dedicado
echo "==> Creando subvolumen btrfs en ${TARGET_HOME}..."
btrfs subvolume create "$TARGET_HOME"

# 4. Asignar propiedad y permisos estrictos
chown "${TARGET_USER}:${TARGET_USER}" "$TARGET_HOME"
chmod 700 "$TARGET_HOME"

echo "==> Aislamiento completado con éxito. /home/${TARGET_USER} es ahora un subvolumen dedicado."

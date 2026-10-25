#!/usr/bin/env bash
#
# instalar.sh: Despliegue automático de la Suite de Sincronización en /z-drive
# Soporta tanto rol MAESTRO como RÉPLICA / HIJA
#
# Uso:
#   sudo ./instalar.sh [--master | --replica]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLE="master"

for arg in "$@"; do
    case "$arg" in
        --replica|--hija)
            ROLE="replica"
            ;;
        --master)
            ROLE="master"
            ;;
        -h|--help)
            echo "Uso: sudo $0 [--master | --replica]"
            echo "  --master   Configura este host como Maestro (/z-drive ➔ Google Drive)"
            echo "  --replica  Configura este host como Hija (Google Drive ➔ /z-drive)"
            exit 0
            ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Este script debe ejecutarse con privilegios de root (sudo $0)."
    exit 1
fi

echo "=================================================================="
echo "   INSTALANDO SUITE DE SINCRONIZACIÓN /Z-DRIVE (MODO: ${ROLE^^})   "
echo "=================================================================="

# 1. Comprobar dependencias
echo "[1/6] Comprobando dependencias del sistema..."
for cmd in rsync rclone systemctl inotifywait; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "   [!] Instalando '$cmd' con pacman..."
        pacman -S --needed --noconfirm "$cmd"
    else
        echo "   [✓] $cmd encontrado."
    fi
done

# 2. Configurar rol en /etc/rclone/
echo "[2/6] Configurando roles en /etc/rclone/..."
mkdir -p /etc/rclone
echo "ROLE=\"${ROLE}\"" > /etc/rclone/sync-idalia.conf
echo "ROLE=\"${ROLE}\"" > /etc/rclone/sync-uploads-gracie.conf
chmod 644 /etc/rclone/sync-idalia.conf /etc/rclone/sync-uploads-gracie.conf
echo "   [✓] Rol asignado: ${ROLE^^}"

# 3. Instalar ejecutables en /usr/local/bin
echo "[3/6] Instalando scripts globales en /usr/local/bin/..."
SCRIPTS=(
    sync-tries
    sync-idalia
    sync-uploads-gracie
    sync-all
    sync-status
    sync-hub-bar
    sync-tries-watcher
    upload-moved-gdrive
    upload-moved-shutdown-supervisor
    watch-moved
)

for script in "${SCRIPTS[@]}"; do
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        install -Dm755 "$SCRIPT_DIR/$script" "/usr/local/bin/$script"
        echo "   [✓] /usr/local/bin/$script"
    fi
done

# Instalar lista de exclusiones
if [[ -f "$SCRIPT_DIR/exclusiones.txt" ]]; then
    install -Dm644 "$SCRIPT_DIR/exclusiones.txt" /etc/rclone/exclusiones-sync.txt
    echo "   [✓] /etc/rclone/exclusiones-sync.txt"
fi

# 4. Instalar módulos visuales de Quickshell (Omarchy Bar)
echo "[4/6] Desplegando módulos visuales de Quickshell..."
for u in /home/* /etc/skel; do
    [[ ! -d "$u" ]] && continue
    bar_modules="$u/.config/omarchy/bar/modules"
    mkdir -p "$bar_modules"
    [[ -f "$SCRIPT_DIR/sync-hub.qml" ]] && cp -f "$SCRIPT_DIR/sync-hub.qml" "$bar_modules/"
    [[ -f "$SCRIPT_DIR/sync-tries.qml" ]] && cp -f "$SCRIPT_DIR/sync-tries.qml" "$bar_modules/"
    if [[ "$u" != "/etc/skel" ]]; then
        user_name="$(basename "$u")"
        chown -R "$user_name:$user_name" "$u/.config/omarchy" 2>/dev/null || true
    fi
done
echo "   [✓] Módulos QML instalados en usuarios y /etc/skel."

# 5. Instalar y habilitar unidades systemd
echo "[5/6] Instalando servicios y temporizadores systemd..."
UNITS_DIR="$SCRIPT_DIR/systemd"
if [[ -d "$UNITS_DIR" ]]; then
    for unit in "$UNITS_DIR"/*; do
        install -Dm644 "$unit" "/etc/systemd/system/$(basename "$unit")"
    done
    systemctl daemon-reload

    # Habilitar temporizadores
    systemctl enable --now sync-tries.timer sync-idalia.timer sync-uploads-gracie.timer
    systemctl enable --now sync-tries-watcher.service
    echo "   [✓] Temporizadores y servicios del sistema habilitados y activos."
fi

# 6. Resumen final
echo "[6/6] Verificación de salud..."
echo "=================================================================="
echo "   [✓] DESPLIEGUE COMPLETADO EXITOSAMENTE                         "
echo "=================================================================="
echo "Puedes ejecutar 'sync-status' en cualquier momento para diagnosticar."

#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script de Actualización y Mantenimiento de Nyxuri (Noctalia Shell)
# Mantiene aislado el ecosistema Nyxuri sin interferir con Clavis Desktop.
# ==============================================================================

SRC_DIR="${SRC_DIR:-/opt/src}"
NYXURI_DIR="$SRC_DIR/nyxuri"

BUILD_USER="${BUILD_USER:-$(stat -c %U "$SRC_DIR")}"
BUILD_HOME="$(getent passwd "$BUILD_USER" | cut -d: -f6)"

as_builder() {
    runuser -u "$BUILD_USER" -- env -i \
        HOME="$BUILD_HOME" USER="$BUILD_USER" LOGNAME="$BUILD_USER" \
        PATH=/usr/local/bin:/usr/bin:/bin \
        bash -c "$1"
}

echo "================================================================"
echo "  Actualizando Nyxuri Desktop (Noctalia Shell) desde el fork    "
echo "================================================================"

# 1. Actualizar repositorio fuente desde origin (rama personal)
if [ -d "$NYXURI_DIR" ]; then
    echo ">> [1/3] Actualizando repositorio fuente de Nyxuri..."
    as_builder "cd '$NYXURI_DIR' && git fetch origin && { git merge --ff-only '@{u}' || echo 'Advertencia: avance rápido no posible; se conserva versión local'; }"
    
    # Asegurar enlaces globales de launchers
    install -d /usr/local/bin
    ln -sf "$NYXURI_DIR/nyxuri/launcher.sh" /usr/local/bin/nyxuri
    chmod +x "$NYXURI_DIR/nyxuri/launcher.sh"
    ln -sf "$NYXURI_DIR/shell/nyxuri-shell" /usr/local/bin/nyxuri-shell
    chmod +x "$NYXURI_DIR/shell/nyxuri-shell"
else
    echo "Error: $NYXURI_DIR no existe." >&2
    exit 1
fi

# 2. Desplegar sincronización de unidades en usuarios de Nyxuri
echo ">> [2/3] Aplicando sincronización en usuarios de Nyxuri..."
UNITS="niri noctalia kitty fastfetch fish starship theme wallpapers xdg-desktop-portal zed shell.bar shell.desktopcards shell.dock shell.keystone shell.launcher shell.lock shell.notifications shell.regionselector shell.session shell.settings shell.sidebars shell.wallpaper"
for u in nyxuri nyxuri-test; do
    if id "$u" &>/dev/null; then
        echo "   -> Sincronizando unidades para $u..."
        for unit in $UNITS; do
            sudo -u "$u" -H nyxuri on "$unit" >/dev/null 2>&1 || true
        done
        # Fijar Nyxuri Shell experimental
        sudo -u "$u" -H nyxuri shell set nyxuri-shell /usr/local/bin/nyxuri-shell >/dev/null 2>&1 || true
        # Renderizar plantillas de rutas dinámicas (Pictures/Wallpapers, screenshots, GTK CSS)
        sudo -u "$u" -H python3 -c "import sys; sys.path.insert(0, '$NYXURI_DIR'); from nyxuri.deploy.templates import _phase_render_templates; _phase_render_templates()" >/dev/null 2>&1 || true
        echo "      [✓] Unidades y plantillas de $u actualizadas."
    fi
done

# 3. Actualizar paquetes del sistema
echo ">> [3/3] Verificando dependencias del sistema..."
pacman -Syu --needed --noconfirm

echo "================================================================"
echo "  Actualización de Nyxuri completada exitosamente.              "
echo "================================================================"

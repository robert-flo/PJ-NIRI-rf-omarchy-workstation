#!/usr/bin/env bash
# ==============================================================================
# Script de aprovisionamiento de espacio de usuario ($HOME) para otros usuarios
# Permite a cualquier usuario de esta PC tener acceso a:
# - agy (Antigravity CLI)
# - firebase CLI
# - google-chrome (alias)
# - google-antigravity (Python SDK)
# - Variables de entorno de Android y Java en ~/.bashrc
# ==============================================================================
set -euo pipefail

CURRENT_USER=$(whoami)
echo "==> Configurando entorno de desarrollo Google/Android para usuario: $CURRENT_USER..."

# 1. Variables de entorno en ~/.bashrc
BASHRC="$HOME/.bashrc"
if ! grep -q "ANDROID_HOME" "$BASHRC" 2>/dev/null; then
    cat << 'EOF' >> "$BASHRC"

# --- ANDROID & JAVA ENVIRONMENT ---
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_USER_HOME="$HOME/.android"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
# --- FIN ANDROID & JAVA ENVIRONMENT ---
EOF
    echo "[OK] Variables de entorno añadidas a ~/.bashrc"
else
    echo "[OK] Variables de entorno ya presentes en ~/.bashrc"
fi

# 2. Herramientas CLI de usuario (agy y firebase)
mkdir -p "$HOME/.local/bin"
if command -v omarchy-mise-install &>/dev/null; then
    omarchy-mise-install antigravity-cli agy
    omarchy-mise-install npm:firebase-tools firebase
    echo "[OK] 'agy' y 'firebase' vinculados vía omarchy-mise-install"
elif command -v mise &>/dev/null; then
    mise use -g antigravity-cli
    mise use -g firebase
    echo "[OK] 'agy' y 'firebase' vinculados vía mise"
fi

# 3. Google Chrome alias si no existe comando directo
if ! command -v google-chrome &>/dev/null && [[ -f /usr/bin/google-chrome-stable ]]; then
    ln -sf /usr/bin/google-chrome-stable "$HOME/.local/bin/google-chrome"
    echo "[OK] Enlace google-chrome creado en ~/.local/bin/google-chrome"
fi

# 4. Python SDK google-antigravity
if ! python3 -c "import google.antigravity" &>/dev/null; then
    echo "Instalando Python SDK google-antigravity..."
    python3 -m pip install --user --upgrade google-antigravity
    echo "[OK] Python SDK google-antigravity instalado"
else
    echo "[OK] Python SDK google-antigravity ya disponible"
fi

echo ""
echo "==> ¡Configuración completada exitosamente para $CURRENT_USER!"
echo "Puedes recargar tu terminal con: source ~/.bashrc"

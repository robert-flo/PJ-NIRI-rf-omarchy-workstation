#!/usr/bin/env bash
# ==============================================================================
# nuevo-usuario.sh
# Script de aprovisionamiento inmediato para un nuevo usuario o agente (ej. niri)
# Configura automáticamente:
#  - Bash (~/.bashrc)
#  - Fish Shell (~/.config/fish/config.fish)
#  - CLI tools (agy, firebase) vía omarchy/mise
#  - Alias de Google Chrome
#  - Python SDK (google-antigravity)
#  - Acceso a carpetas compartidas: /opt/android-sdk y /z/android-projects
# ==============================================================================
set -euo pipefail

CURRENT_USER="$(whoami)"
USER_HOME="${HOME}"

# Colores para salida
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
NC="\033[0m"

echo -e "${BLUE}==>${NC} ${GREEN}Configurando entorno de desarrollo Android / Google para usuario: ${CYAN}${CURRENT_USER}${NC}..."

# ------------------------------------------------------------------------------
# 1. Verificación de Grupos del Sistema (wheel y kvm)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[1/6]${NC} Verificando membresía en grupos..."
if id -nG "$CURRENT_USER" | grep -qw "kvm"; then
    echo -e "  ${GREEN}[OK]${NC} Usuario pertenece al grupo 'kvm' (aceleración de emulador AVD activa)."
else
    echo -e "  ${YELLOW}[AVISO]${NC} El usuario no pertenece al grupo 'kvm'. Un admin debe ejecutar: sudo usermod -aG kvm $CURRENT_USER"
fi

if id -nG "$CURRENT_USER" | grep -qw "wheel"; then
    echo -e "  ${GREEN}[OK]${NC} Usuario pertenece al grupo 'wheel' (acceso a carpetas compartidas)."
else
    echo -e "  ${YELLOW}[AVISO]${NC} El usuario no pertenece al grupo 'wheel'. Un admin debe ejecutar: sudo usermod -aG wheel $CURRENT_USER"
fi

# ------------------------------------------------------------------------------
# 2. Configuración de Bash (~/.bashrc)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[2/6]${NC} Configurando ~/.bashrc..."
BASHRC="$USER_HOME/.bashrc"
mkdir -p "$(dirname "$BASHRC")"
touch "$BASHRC"

if ! grep -q "ANDROID_HOME" "$BASHRC" 2>/dev/null; then
    cat << 'EOF' >> "$BASHRC"

# --- ANDROID & JAVA ENVIRONMENT (BASH) ---
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_USER_HOME="$HOME/.android"
export ANDROID_PROJECTS_DIR="/z/android-projects"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$HOME/.local/bin"
# --- FIN ANDROID & JAVA ENVIRONMENT ---
EOF
    echo -e "  ${GREEN}[OK]${NC} Variables de entorno añadidas a ~/.bashrc"
else
    # Asegurar que apunte a /opt/android-sdk si tenía la ruta local previa
    if grep -q 'ANDROID_HOME="$HOME/Android/Sdk"' "$BASHRC" 2>/dev/null; then
        sed -i 's|ANDROID_HOME="$HOME/Android/Sdk"|ANDROID_HOME="/opt/android-sdk"|g' "$BASHRC"
        echo -e "  ${GREEN}[OK]${NC} Ruta ANDROID_HOME actualizada a /opt/android-sdk en ~/.bashrc"
    else
        echo -e "  ${GREEN}[OK]${NC} ~/.bashrc ya contiene configuración válida."
    fi
fi

# ------------------------------------------------------------------------------
# 3. Configuración de Fish Shell (~/.config/fish/config.fish)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[3/6]${NC} Configurando Fish Shell (~/.config/fish/config.fish)..."
FISH_CONFIG_DIR="$USER_HOME/.config/fish"
FISH_CONFIG="$FISH_CONFIG_DIR/config.fish"
mkdir -p "$FISH_CONFIG_DIR"
touch "$FISH_CONFIG"

if ! grep -q "ANDROID_HOME" "$FISH_CONFIG" 2>/dev/null; then
    cat << 'EOF' >> "$FISH_CONFIG"

# --- ANDROID & JAVA ENVIRONMENT (FISH) ---
set -gx ANDROID_HOME "/opt/android-sdk"
set -gx ANDROID_USER_HOME "$HOME/.android"
set -gx ANDROID_PROJECTS_DIR "/z/android-projects"

# Agregar rutas al PATH de Fish de manera idempotente
fish_add_path -a $ANDROID_HOME/emulator $ANDROID_HOME/platform-tools $ANDROID_HOME/cmdline-tools/latest/bin $HOME/.local/bin
# --- FIN ANDROID & JAVA ENVIRONMENT ---
EOF
    echo -e "  ${GREEN}[OK]${NC} Configuración añadida exitosamente a ~/.config/fish/config.fish"
else
    echo -e "  ${GREEN}[OK]${NC} ~/.config/fish/config.fish ya contiene variables de Android."
fi

# ------------------------------------------------------------------------------
# 4. Herramientas CLI de Usuario (agy y firebase)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[4/6]${NC} Configurando agentes CLI (agy y firebase)..."
mkdir -p "$USER_HOME/.local/bin"

if command -v omarchy-mise-install &>/dev/null; then
    omarchy-mise-install antigravity-cli agy >/dev/null 2>&1 || true
    omarchy-mise-install npm:firebase-tools firebase >/dev/null 2>&1 || true
    echo -e "  ${GREEN}[OK]${NC} 'agy' y 'firebase' vinculados vía omarchy-mise-install."
elif command -v mise &>/dev/null; then
    mise use -g antigravity-cli >/dev/null 2>&1 || true
    mise use -g firebase >/dev/null 2>&1 || true
    echo -e "  ${GREEN}[OK]${NC} 'agy' y 'firebase' vinculados vía mise."
else
    echo -e "  ${YELLOW}[AVISO]${NC} mise / omarchy-mise-install no detectado; se asume uso de binarios en /usr/bin."
fi

# Symlink de conveniencia para google-chrome en caso de no estar en /usr/local/bin
if ! command -v google-chrome &>/dev/null && [[ -f /usr/bin/google-chrome-stable ]]; then
    ln -sf /usr/bin/google-chrome-stable "$USER_HOME/.local/bin/google-chrome"
    echo -e "  ${GREEN}[OK]${NC} Enlace google-chrome creado en ~/.local/bin."
fi

# ------------------------------------------------------------------------------
# 5. Verificación de Python SDK (google-antigravity)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[5/6]${NC} Verificando Python SDK (google-antigravity)..."
if python3 -c "import google.antigravity" &>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC} SDK google.antigravity disponible."
else
    echo -e "  ${CYAN}[INFO]${NC} Instalando google-antigravity en espacio de usuario..."
    python3 -m pip install --user --upgrade google-antigravity >/dev/null 2>&1 || true
    echo -e "  ${GREEN}[OK]${NC} SDK google.antigravity instalado."
fi

# ------------------------------------------------------------------------------
# 6. Verificación de Carpetas Compartidas (/opt/android-sdk y /z/android-projects)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[6/6]${NC} Verificando permisos en carpetas compartidas..."

check_dir_access() {
    local target="$1"
    local desc="$2"
    if [[ -d "$target" ]]; then
        if [[ -w "$target" ]]; then
            echo -e "  ${GREEN}[OK]${NC} $desc ($target): Acceso de lectura y escritura confirmado."
        else
            echo -e "  ${YELLOW}[AVISO]${NC} $desc ($target): No se tienen permisos de escritura. Ejecuta en sesión admin: sudo ./shared_dir $target"
        fi
    else
        echo -e "  ${YELLOW}[AVISO]${NC} $desc ($target) aún no ha sido creado en el sistema."
    fi
}

check_dir_access "/z" "Directorio Raíz Compartido"
check_dir_access "/opt/android-sdk" "SDK de Android Compartido"
check_dir_access "/z/android-projects" "Directorio Compartido de Proyectos"

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN} ¡ENTORNO LISTO PARA DESARROLLAR ANDROID EN BASH Y FISH SHELL! ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "Usuario configurado: ${CYAN}${CURRENT_USER}${NC}"
echo -e "SDK compartido:     ${CYAN}/opt/android-sdk${NC}"
echo -e "Proyectos compart.: ${CYAN}/z/android-projects${NC}"
echo -e ""
echo -e "Para comenzar a programar:"
echo -e "  • En Fish: Abre una nueva terminal o ejecuta: ${CYAN}source ~/.config/fish/config.fish${NC}"
echo -e "  • En Bash: Abre una nueva terminal o ejecuta: ${CYAN}source ~/.bashrc${NC}"
echo -e "  • Inicia el IDE: ${CYAN}android-studio-canary &${NC}"
echo -e "  • Inicia el agente: ${CYAN}antigravity &${NC} o ${CYAN}agy${NC}"
echo -e "${GREEN}================================================================${NC}"

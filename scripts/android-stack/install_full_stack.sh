#!/usr/bin/env bash
# ==============================================================================
# Script de Instalación Automatizada "One-Shot" para Todo el Ecosistema Google:
# - Google Antigravity 2.0 (AUR)
# - Google Antigravity IDE (AUR)
# - Google Antigravity CLI / agy (AUR)
# - Google Antigravity Python SDK (google-antigravity)
# - Android Studio Rabbit 2 Canary con soporte BYOA (AUR)
# - Google Cloud CLI / gcloud (AUR)
# - Firebase CLI / firebase (AUR)
# - Google Chrome (AUR si falta)
# - Entorno completo Android, Kotlin, Java (JDK 21 & 17), Gradle y reglas udev
# ==============================================================================
set -euo pipefail

# Colores para salida formateada
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_step() { echo -e "${CYAN}==>${NC} ${GREEN}$1${NC}"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Validar que NO se ejecute como root (makepkg requiere usuario estándar)
if [[ $EUID -eq 0 ]]; then
    log_error "No ejecutes este script como root. makepkg requiere ejecutarse como usuario estándar."
    exit 1
fi

# Directorio de trabajo seguro en disco (evita saturar el tmpfs de RAM en /tmp)
BUILD_CACHE_BASE="${HOME}/.cache/google_dev_stack_build"
mkdir -p "$BUILD_CACHE_BASE"
export TMPDIR="$BUILD_CACHE_BASE/tmp"
mkdir -p "$TMPDIR"
WORK_DIR=$(mktemp -d -p "$BUILD_CACHE_BASE" build_XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

log_info "Directorio de trabajo seguro en disco: $WORK_DIR (TMPDIR: $TMPDIR)"

# ------------------------------------------------------------------------------
# 1. Dependencias base oficiales de Arch Linux (pacman)
# ------------------------------------------------------------------------------
log_step "1/8: Instalando dependencias base del sistema, compiladores y toolchain oficial..."

sudo pacman -S --needed --noconfirm \
    base-devel \
    git \
    curl \
    unzip \
    zip \
    jq \
    python \
    python-pip \
    python-installer \
    jdk21-openjdk \
    jdk17-openjdk \
    kotlin \
    gradle \
    android-tools \
    android-udev \
    alsa-lib \
    gtk3 \
    nss \
    nspr \
    webkit2gtk-4.1 \
    libsecret \
    libsoup3 \
    mesa \
    vulkan-icd-loader \
    acl \
    inotify-tools \
    fish

# Configurar OpenJDK 21 como versión predeterminada del sistema
if command -v archlinux-java >/dev/null 2>&1; then
    sudo archlinux-java set java-21-openjdk || true
    log_success "Java predeterminado configurado a OpenJDK 21."
fi

# Lista para acumular paquetes locales compilados para instalación conjunta
declare -a LOCAL_PACKAGES=()

# Helper para compilar paquetes AUR si no están instalados
build_aur_if_missing() {
    local pkg_name="$1"
    local check_cmd="${2:-}"
    local aur_repo="${3:-$pkg_name}"

    if pacman -Q "$pkg_name" &>/dev/null; then
        log_success "Paquete '$pkg_name' ya está instalado en pacman."
        return 0
    fi

    if [[ -n "$check_cmd" ]] && command -v "$check_cmd" &>/dev/null; then
        log_success "Comando '$check_cmd' ya está disponible en el sistema."
        return 0
    fi

    log_info "Compilando paquete AUR: $pkg_name..."
    cd "$WORK_DIR"
    rm -rf "$aur_repo"
    git clone "https://aur.archlinux.org/${aur_repo}.git"
    cd "$aur_repo"
    makepkg -s --noconfirm
    local -a built_pkgs=()
    while IFS= read -r p; do
        [[ -n "$p" && -f "$p" ]] && built_pkgs+=("$p")
    done < <(ls -1 *.pkg.tar.zst 2>/dev/null || true)

    if (( ${#built_pkgs[@]} > 0 )); then
        for p in "${built_pkgs[@]}"; do
            log_success "Compilado exitosamente: $p"
        done
        log_info "Instalando $pkg_name vía pacman..."
        sudo pacman -U --needed --noconfirm "${built_pkgs[@]}"
        log_success "Instalado exitosamente: $pkg_name"
        cd "$WORK_DIR"
        rm -rf "$aur_repo"
    else
        log_error "No se pudo generar el paquete para $pkg_name"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 2. Google Chrome (navegador para OAuth y DevTools)
# ------------------------------------------------------------------------------
log_step "2/8: Verificando Google Chrome..."
if ! command -v google-chrome &>/dev/null && ! pacman -Q google-chrome &>/dev/null; then
    build_aur_if_missing "google-chrome" "google-chrome"
else
    log_success "Google Chrome ya está disponible."
fi

# ------------------------------------------------------------------------------
# 3. Google Antigravity 2.0 (Plataforma Multi-Agente)
# ------------------------------------------------------------------------------
log_step "3/8: Verificando Google Antigravity 2.0..."
build_aur_if_missing "antigravity" ""

# ------------------------------------------------------------------------------
# 4. Google Antigravity IDE (Entorno basado en VS Code)
# ------------------------------------------------------------------------------
log_step "4/8: Verificando Google Antigravity IDE..."
build_aur_if_missing "antigravity-ide" "antigravity-ide"

# ------------------------------------------------------------------------------
# 5. Google Antigravity CLI (agy)
# ------------------------------------------------------------------------------
log_step "5/8: Verificando Google Antigravity CLI (agy)..."
if command -v agy &>/dev/null; then
    log_success "Google Antigravity CLI ('agy') ya está disponible."
elif command -v omarchy-mise-install &>/dev/null; then
    log_info "Detectado Omarchy: instalando 'antigravity-cli' vía omarchy-mise-install..."
    omarchy-mise-install antigravity-cli agy
    log_success "Instalado vía omarchy-mise-install."
elif command -v mise &>/dev/null; then
    log_info "Detectado mise: instalando 'antigravity-cli' vía mise..."
    mise use -g antigravity-cli
    log_success "Instalado vía mise."
else
    build_aur_if_missing "antigravity-cli" "agy"
fi

# ------------------------------------------------------------------------------
# 6. Android Studio Canary (Rabbit 2 con soporte BYOA)
# ------------------------------------------------------------------------------
log_step "6/8: Verificando Android Studio Canary (Rabbit 2)..."
build_aur_if_missing "android-studio-canary" "android-studio-canary"

# ------------------------------------------------------------------------------
# 7. Herramientas Google Cloud & Firebase
# ------------------------------------------------------------------------------
log_step "7/8: Verificando Google Cloud CLI y Firebase Tools..."
build_aur_if_missing "google-cloud-cli" "gcloud"

if command -v firebase &>/dev/null; then
    log_success "Firebase CLI ('firebase') ya está disponible."
elif command -v omarchy-mise-install &>/dev/null; then
    log_info "Detectado Omarchy: instalando 'firebase-tools' vía omarchy-mise-install..."
    omarchy-mise-install npm:firebase-tools firebase
    log_success "Instalado vía omarchy-mise-install."
elif command -v mise &>/dev/null; then
    log_info "Detectado mise: instalando 'firebase' vía mise..."
    mise use -g firebase
    log_success "Instalado vía mise."
else
    build_aur_if_missing "firebase-tools-bin" "firebase"
fi

# Instalar todos los paquetes AUR generados en una sola transacción
if (( ${#LOCAL_PACKAGES[@]} > 0 )); then
    log_info "Instalando paquetes compilados mediante pacman..."
    sudo pacman -U --needed --noconfirm "${LOCAL_PACKAGES[@]}"
    log_success "Paquetes AUR instalados correctamente."
else
    log_info "No hay paquetes nuevos pendientes de instalación con pacman."
fi

# ------------------------------------------------------------------------------
# 8. Python SDK de Antigravity (google-antigravity)
# ------------------------------------------------------------------------------
log_step "8/8: Verificando Google Antigravity Python SDK..."
if ! python3 -c "import google.antigravity" &>/dev/null; then
    log_info "Instalando SDK de Python 'google-antigravity' vía pip..."
    sudo pip install --break-system-packages google-antigravity 2>/dev/null || \
        python3 -m pip install --user --upgrade google-antigravity 2>/dev/null || \
        log_warn "No se pudo instalar el SDK de Python automáticamente."
    log_success "SDK de Python 'google-antigravity' instalado."
else
    log_success "El SDK de Python 'google.antigravity' ya se encuentra disponible."
fi

# ------------------------------------------------------------------------------
# 9. Configuración Global Multi-Usuario: Carpetas Compartidas (pj-domina-rf-shared_dir)
# ------------------------------------------------------------------------------
log_step "Configuración Global Multi-Usuario (Enfoque 1)..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR_REPO="$SCRIPT_DIR/pj-domina-rf-shared_dir"

if [[ ! -d "$SHARED_DIR_REPO" ]]; then
    log_info "Clonando repositorio de directorios compartidos pj-domina-rf-shared_dir..."
    git clone "https://github.com/robert-flo/pj-domina-rf-shared_dir.git" "$SHARED_DIR_REPO"
fi

log_info "Configurando permisos multi-usuario (SGID + ACLs + monitores en tiempo real)..."
sudo bash "$SHARED_DIR_REPO/shared_dir" /z /opt/android-sdk /z/android-projects

# Garantizar membresía en kvm para el usuario actual y niri
sudo usermod -aG kvm "$USER" 2>/dev/null || true
if id -u niri &>/dev/null; then
    sudo usermod -aG kvm,wheel niri 2>/dev/null || true
    log_success "Usuario 'niri' añadido a los grupos 'kvm' y 'wheel'."
fi

# ------------------------------------------------------------------------------
# 10. Perfil de Entorno Global del Sistema (/etc/profile.d/android.sh)
# ------------------------------------------------------------------------------
log_info "Creando perfil de entorno global en /etc/profile.d/android.sh..."
sudo tee /etc/profile.d/android.sh << 'EOF'
# Configuración global Android SDK & Proyectos Compartidos
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_USER_HOME="$HOME/.android"
export ANDROID_PROJECTS_DIR="/z/android-projects"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
EOF
sudo chmod +x /etc/profile.d/android.sh
log_success "Perfil /etc/profile.d/android.sh activo para todos los usuarios."

# Symlink global para Google Chrome
if [[ -f /usr/bin/google-chrome-stable ]]; then
    sudo ln -sf /usr/bin/google-chrome-stable /usr/local/bin/google-chrome
    log_success "Symlink global /usr/local/bin/google-chrome configurado."
fi

# ------------------------------------------------------------------------------
# 11. Ejecución de nuevo-usuario.sh para configurar shells (Bash y Fish)
# ------------------------------------------------------------------------------
if [[ -f "$SCRIPT_DIR/nuevo-usuario.sh" ]]; then
    log_info "Aprovisionando shells (Bash y Fish) para el usuario actual ($USER)..."
    bash "$SCRIPT_DIR/nuevo-usuario.sh"
fi

# ------------------------------------------------------------------------------
# Comprobación de aceleración KVM
# ------------------------------------------------------------------------------
if [[ -e /dev/kvm ]]; then
    log_success "Virtualización KVM (/dev/kvm) activa para emuladores AVD (Compose a 60/120 fps)."
else
    log_warn "No se detectó /dev/kvm. Habilita VT-x / AMD-V en la BIOS si vas a usar emuladores."
fi

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}       ¡SUITE COMPLETA DE GOOGLE INSTALADA Y CONFIGURADA!       ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "Ecosistema Antigravity:"
echo -e "  - Antigravity 2.0 (Orquestador): /usr/bin/antigravity"
echo -e "  - Antigravity IDE (VS Code):     /usr/bin/antigravity-ide"
echo -e "  - Antigravity CLI (TUI/agy):     $(which agy 2>/dev/null || echo '/usr/bin/agy')"
echo -e "  - Python SDK:                    google.antigravity"
echo -e ""
echo -e "Desarrollo Android y Compose:"
echo -e "  - Android Studio Canary:         /usr/bin/android-studio-canary"
echo -e "  - Java Runtime (LTS):            $(java -version 2>&1 | head -n 1)"
echo -e "  - Kotlin CLI:                    $(kotlinc -version 2>&1)"
echo -e "  - Gradle:                        $(gradle --version 2>&1 | grep '^Gradle ')"
echo -e "  - Android Debug Bridge:          $(adb version 2>&1 | head -n 1)"
echo -e ""
echo -e "Servicios Cloud y Firebase:"
echo -e "  - Google Cloud CLI (gcloud):     $(command -v gcloud || echo 'Pendiente de recargar terminal')"
echo -e "  - Firebase CLI:                  $(command -v firebase || echo 'Pendiente de recargar terminal')"
echo -e "  - Google Chrome:                 $(command -v google-chrome || echo 'Instalado')"
echo -e ""
echo -e "Para conectar Antigravity en Android Studio:"
echo -e "  1. Ejecuta: 'android-studio-canary &'"
echo -e "  2. En el panel de agentes / AI Assistant, selecciona Google Antigravity"
echo -e "     (o ve a: Settings > Tools > AI > Agents)."
echo -e "  3. Inicia sesión con tu cuenta de Antigravity."
echo -e "${GREEN}================================================================${NC}"

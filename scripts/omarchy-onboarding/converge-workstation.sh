#!/usr/bin/env bash
# ==============================================================================
# converge-workstation.sh — Convergencia Integral Idempotente por Capas (01 a 07)
# ==============================================================================
# Despliega y reconcilia de forma 100% idempotente todas las capas de la
# estación de trabajo (PJ-NIRI-rf-omarchy-workstation):
#   - Capa 01: Sudoers infalible, Fix Intel i915 (SAGV), /etc/skel, Usuarios
#              (niri, niri-test, nyxuri, nyxuri-test, nyxuri-legacy, omarchy-test,
#               guest, sandbox), SDDM Catppuccin Mocha (sin autologin).
#   - Capa 02: Almacenamiento compartido (/z, /zt, /z-drive), Wallpapers,
#              watchers de permisos y suite declarativa synchub + rclone.
#   - Capa 03: Paquetes [omarchy-personal] (ravn-*, herdr), Toolchain global
#              (C/C++, Rust, Go, Java, Node/pnpm, Ghostty, Yazi, Atuin, etc.),
#              tipografías, variables Android SDK y fork-docs.
#   - Capa 04: Compilación e instalación de niri-edge, key-cli, Clavis Shell
#              (Quickshell), MacTahoe, Nyxuri (Edge + Stable) y dotfiles.
#   - Capa 05: Suite Neovim Dual (/z/nvims: rvim, craftzdog:personal, nvim2k) y
#              wrappers globales XDG (/usr/local/bin/{nvim,rvim,cvim,2kvim}).
#   - Capa 07: CLI forkhub, definiciones en /etc/forkhub/repos.d y forkhub.timer.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SYS_ASSETS="${REPO_ROOT}/assets/system"
BUILD_DIR="${BUILD_DIR:-/opt/src}"

DRY_RUN=false
SKIP_BUILDS=false
NON_INTERACTIVE=false
UNLOCK_SECRETS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-builds)
      SKIP_BUILDS=true
      shift
      ;;
    --unlock-secrets|--secrets)
      UNLOCK_SECRETS=true
      shift
      ;;
    --non-interactive|--batch|-y)
      NON_INTERACTIVE=true
      shift
      ;;
    -h|--help)
      cat << 'EOF'
Uso:
  sudo ./scripts/omarchy-onboarding/converge-workstation.sh [opciones]

Opciones:
  -n, --dry-run          Simula y audita las capas sin modificar el sistema
  --skip-builds          Omite la compilación pesada de niri-edge / quickshell (Clavis)
  --unlock-secrets       Fuerza el desbloqueo interactivo del paquete de secretos (age)
  --non-interactive, -y  Ejecución desatendida sin prompts (hereda credenciales del admin)
  -h, --help             Muestra esta ayuda
EOF
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -t 1 ]]; then
  C_RESET="\033[0m"
  C_INFO="\033[1;34m"
  C_OK="\033[1;32m"
  C_WARN="\033[1;33m"
  C_ERR="\033[1;31m"
else
  C_RESET="" C_INFO="" C_OK="" C_WARN="" C_ERR=""
fi

log_info()   { echo -e "${C_INFO}[INFO]${C_RESET} $*"; }
log_ok()     { echo -e "${C_OK}$*${C_RESET}"; }
log_change() { echo -e "${C_WARN}$*${C_RESET}"; }
log_warn()   { echo -e "${C_WARN}[WARN]${C_RESET} $*" >&2; }
log_err()    { echo -e "${C_ERR}[ERROR]${C_RESET} $*" >&2; }

CHANGES=0

run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${C_WARN}[DRY-RUN]${C_RESET} $*"
  else
    "$@"
  fi
}

if [[ "$DRY_RUN" == false && $EUID -ne 0 ]]; then
  log_err "Ejecuta este script con sudo: sudo $0 $*"
  exit 1
fi

INVOKING_USER="${SUDO_USER:-${USER:-$(id -un)}}"
if [[ "$INVOKING_USER" == "root" ]]; then
  INVOKING_USER="$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd || echo "rollo")"
fi
INVOKING_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6)"

# Helper idempotente para instalar un archivo desde assets/system/<ruta>
install_sys_file() {
  local rel_path="$1"
  local mode="${2:-0644}"
  local owner="${3:-root:root}"
  local src="${SYS_ASSETS}${rel_path}"
  local dst="${rel_path}"

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    return 0
  fi

  if [[ -L "$src" ]]; then
    local target_link
    target_link="$(readlink "$src")"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$target_link" ]]; then
      return 0
    fi
    log_change "[CAMBIO] Creando symlink $dst -> $target_link..."
    CHANGES=$((CHANGES + 1))
    run mkdir -p "$(dirname "$dst")"
    run ln -sfn "$target_link" "$dst"
    return 0
  fi

  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    local cur_mode
    cur_mode="$(stat -c '%a' "$dst" 2>/dev/null || echo "")"
    if [[ "0${cur_mode}" == "$mode" || "$cur_mode" == "${mode#0}" ]]; then
      return 0
    fi
  fi

  log_change "[CAMBIO] Instalando $dst ($mode $owner)..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == true ]]; then
    run install -D -m "$mode" -o "${owner%:*}" -g "${owner#*:}" "$src" "$dst"
  else
    mkdir -p "$(dirname "$dst")"
    install -D -m "$mode" -o "${owner%:*}" -g "${owner#*:}" "$src" "$dst"
  fi
}

# ==============================================================================
# CAPA 01: Core del Sistema, Sudoers, Hardware i915, Usuarios y SDDM
# ==============================================================================
echo ""
log_info "=== [Capa 01] Core del Sistema: Sudoers, Intel i915, Usuarios y SDDM ==="

# 1.1 Sudoers infalible (00-omarchy-wheel + 04_* + zz_04_<admin> para ganar siempre en orden léxico)
install_sys_file "/etc/sudoers.d/00-omarchy-wheel" "0440" "root:root"
for sf in "$SYS_ASSETS"/etc/sudoers.d/04_* "$SYS_ASSETS"/etc/sudoers.d/99_guest-deny; do
  [[ -f "$sf" ]] || continue
  install_sys_file "/etc/sudoers.d/$(basename "$sf")" "0440" "root:root"
done

# Asegurar que el usuario administrador invocador tenga también zz_04_<user> para ganar a cualquier regla alfabética posterior
ZZ_SUDO="/etc/sudoers.d/zz_04_${INVOKING_USER}"
TMP_ZZ="$(mktemp "${TMPDIR:-/tmp}/zz_sudo.XXXXXX")"
trap 'rm -f "$TMP_ZZ"' EXIT
printf "%s\n" "${INVOKING_USER} ALL=(ALL) NOPASSWD: ALL" "Defaults:${INVOKING_USER} verifypw = any" > "$TMP_ZZ"
if [[ -r "$ZZ_SUDO" ]] && cmp -s "$TMP_ZZ" "$ZZ_SUDO"; then
  log_ok "[✓] ya $ZZ_SUDO está activo (NOPASSWD garantizado en orden léxico)."
else
  log_change "[CAMBIO] Instalando regla final $ZZ_SUDO para garantizar NOPASSWD inmediato..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == true ]]; then
    run install -o root -g root -m 0440 "$TMP_ZZ" "$ZZ_SUDO"
  else
    visudo -cf "$TMP_ZZ" >/dev/null
    install -o root -g root -m 0440 "$TMP_ZZ" "$ZZ_SUDO"
  fi
fi

# 1.2 Desbloqueo y Aprovisionamiento de Secretos (age) en memoria segura
SECRETS_SCRIPT="${REPO_ROOT}/scripts/secrets/desbloquear-secretos.sh"
SECRETS_ARCHIVE="${REPO_ROOT}/scripts/secrets/secrets.tar.gz.age"
if [[ -f "$SECRETS_ARCHIVE" && -x "$SECRETS_SCRIPT" && "$DRY_RUN" == false ]]; then
  if [[ "$UNLOCK_SECRETS" == true || ! -f "/etc/rclone/rclone.conf" || ! -f "$INVOKING_HOME/.ssh/id_ed25519" ]]; then
    log_info "Desbloqueando paquete de secretos cifrados (${SECRETS_ARCHIVE})..."
    bash "$SECRETS_SCRIPT" "$SECRETS_ARCHIVE" || log_warn "[!] No se pudo descifrar el paquete de secretos (verifique su clave de age)."
  else
    log_ok "[✓] ya los secretos esenciales (/etc/rclone/rclone.conf y ~/.ssh) están presentes (usa --unlock-secrets para re-desbloquear)."
  fi
fi

# 1.2 Fix Intel i915 (FIFO Underrun / SAGV)
if lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qi 'intel'; then
  if [[ -f /etc/modprobe.d/i915.conf ]] && cmp -s "$SYS_ASSETS/etc/modprobe.d/i915.conf" /etc/modprobe.d/i915.conf; then
    log_ok "[✓] ya /etc/modprobe.d/i915.conf (enable_sagv=0) está aplicado."
  else
    install_sys_file "/etc/modprobe.d/i915.conf" "0644" "root:root"
    log_change "[CAMBIO] Regenerando initramfs/UKI con mkinitcpio -P para aplicar i915.conf..."
    run mkinitcpio -P || true
  fi
fi

# 1.3 Plantilla /etc/skel y Creación de Usuarios de la Estación
while IFS= read -r -d '' skel_f; do
  rel="${skel_f#"$SYS_ASSETS"}"
  install_sys_file "$rel" "0644" "root:root"
done < <(find "$SYS_ASSETS/etc/skel" \( -type f -o -type l \) -print0 2>/dev/null)

if ! getent group adbusers >/dev/null 2>&1; then
  log_change "[CAMBIO] Creando grupo de sistema 'adbusers'..."
  CHANGES=$((CHANGES + 1))
  run groupadd -f adbusers
fi

WORKSTATION_USERS=("niri" "niri-test" "nyxuri" "nyxuri-test" "nyxuri-legacy" "omarchy-test")
REQ_GROUPS="wheel,audio,input,video,kvm,storage,render,adbusers"

# Selección interactiva y gestión de contraseñas de usuarios de la estación
ADMIN_HASH=""
if [[ $EUID -eq 0 ]]; then
  ADMIN_HASH="$(awk -F: -v u="$INVOKING_USER" '$1 == u {print $2}' /etc/shadow 2>/dev/null || true)"
fi

PASS_DESKTOP_HASH=""
PASS_VOLATILE_HASH=""
resp_pass=""

# Comprobar si existen cuentas no inicializadas o bloqueadas ('L' o sin contraseña)
NEED_PASSWD_SETUP=false
for chk_u in "${WORKSTATION_USERS[@]}" guest sandbox; do
  if ! id "$chk_u" >/dev/null 2>&1 || [[ "$(passwd -S "$chk_u" 2>/dev/null | awk '{print $2}')" != "P" ]]; then
    NEED_PASSWD_SETUP=true
    break
  fi
done

if [[ "$DRY_RUN" == false && "$NON_INTERACTIVE" == false && "$NEED_PASSWD_SETUP" == true && -t 0 ]]; then
  echo ""
  echo "=========================================================================="
  echo "           Configuración de Cuentas y Contraseñas de la Estación          "
  echo "=========================================================================="
  echo "Cuentas estándar: ${WORKSTATION_USERS[*]}"
  echo "Cuentas volátiles / amnésicas: guest sandbox"
  echo ""
  read -r -p "¿Deseas configurar contraseñas interactivamente para las cuentas creadas? [s/N]: " resp_pass
  if [[ "$resp_pass" =~ ^[sSyY] ]]; then
    read -r -s -p "Introduce contraseña para perfiles de escritorio (${WORKSTATION_USERS[*]}): " p_desk
    echo ""
    read -r -s -p "Confirma contraseña para perfiles de escritorio: " p_desk2
    echo ""
    if [[ -n "$p_desk" && "$p_desk" == "$p_desk2" ]]; then
      PASS_DESKTOP_HASH="$(openssl passwd -6 "$p_desk")"
      log_ok "[✓] Contraseña asignada para perfiles de escritorio estándar."
    else
      log_warn "[!] Las contraseñas no coinciden o están vacías; se usará la clave de '$INVOKING_USER' como fallback."
    fi

    echo ""
    read -r -s -p "Introduce contraseña para perfiles amnésicos/volátiles (guest, sandbox) [Enter para usar la misma]: " p_vol
    echo ""
    if [[ -n "$p_vol" ]]; then
      read -r -s -p "Confirma contraseña para perfiles amnésicos/volátiles: " p_vol2
      echo ""
      if [[ "$p_vol" == "$p_vol2" ]]; then
        PASS_VOLATILE_HASH="$(openssl passwd -6 "$p_vol")"
        log_ok "[✓] Contraseña diferenciada asignada para perfiles volátiles."
      else
        log_warn "[!] Las contraseñas de volátiles no coinciden; se usará la de escritorio."
      fi
    fi
  fi
elif [[ "$NEED_PASSWD_SETUP" == false ]]; then
  log_ok "[✓] ya todas las cuentas cuentan con contraseña activa configurada."
fi

# Fallback por defecto: si no se ingresó contraseña interactiva, usar la del admin para que no queden bloqueadas
if [[ -z "$PASS_DESKTOP_HASH" ]]; then
  PASS_DESKTOP_HASH="$ADMIN_HASH"
fi
if [[ -z "$PASS_VOLATILE_HASH" ]]; then
  PASS_VOLATILE_HASH="$PASS_DESKTOP_HASH"
fi

for wu in "${WORKSTATION_USERS[@]}"; do
  if ! id "$wu" >/dev/null 2>&1; then
    log_change "[CAMBIO] Creando usuario '$wu' con grupos ($REQ_GROUPS)..."
    CHANGES=$((CHANGES + 1))
    run useradd -m -s /bin/bash -G "$REQ_GROUPS" "$wu"
  else
    for grp in wheel audio input video kvm storage render adbusers; do
      if getent group "$grp" >/dev/null 2>&1 && ! id -nG "$wu" | tr ' ' '\n' | grep -qx "$grp"; then
        log_change "[CAMBIO] Añadiendo usuario '$wu' al grupo '$grp'..."
        CHANGES=$((CHANGES + 1))
        run usermod -aG "$grp" "$wu"
      fi
    done
  fi

  # Desbloquear cuenta si está bloqueada ('L' o '!' en shadow) o aplicar el hash elegido
  if [[ "$DRY_RUN" == false && -n "$PASS_DESKTOP_HASH" && "$PASS_DESKTOP_HASH" != "!"* && "$PASS_DESKTOP_HASH" != "*" ]]; then
    cur_status="$(passwd -S "$wu" 2>/dev/null | awk '{print $2}' || echo "")"
    if [[ "$cur_status" != "P" || -n "$resp_pass" ]]; then
      log_change "[CAMBIO] Estableciendo contraseña y desbloqueando cuenta '$wu' en SDDM..."
      CHANGES=$((CHANGES + 1))
      usermod -p "$PASS_DESKTOP_HASH" "$wu"
    fi
  fi

  if [[ ! -f "/var/lib/systemd/linger/$wu" ]]; then
    log_change "[CAMBIO] Habilitando systemd linger para '$wu'..."
    CHANGES=$((CHANGES + 1))
    run loginctl enable-linger "$wu" || true
  fi
done
log_ok "[✓] ya los perfiles multi-usuario (${WORKSTATION_USERS[*]}) están aprovisionados."

# 1.4 Usuarios Amnésicos (guest UID 1007 y sandbox UID 1008) y Plantilla /etc/amnesic-skel
install_sys_file "/etc/pam.d/su" "0644" "root:root"
install_sys_file "/etc/pam.d/system-login" "0644" "root:root"
install_sys_file "/etc/ufw/before.rules" "0640" "root:root"
if command -v ufw >/dev/null 2>&1 && systemctl is-active --quiet ufw 2>/dev/null; then
  run ufw reload >/dev/null 2>&1 || true
fi

while IFS= read -r -d '' amn_f; do
  rel="${amn_f#"$SYS_ASSETS"}"
  install_sys_file "$rel" "0644" "root:root"
done < <(find "$SYS_ASSETS/etc/amnesic-skel" \( -type f -o -type l \) -print0 2>/dev/null)
install_sys_file "/etc/guest-skel"
install_sys_file "/etc/sandbox-skel"
install_sys_file "/etc/polkit-1/rules.d/00-guest-block.rules" "0644" "root:root"
install_sys_file "/etc/systemd/system/user-1007.slice" "0644" "root:root"
install_sys_file "/etc/systemd/system/user-1008.slice" "0644" "root:root"
install_sys_file "/etc/systemd/system/user@1007.service.d/cleanup.conf" "0644" "root:root"
install_sys_file "/etc/systemd/system/user@1008.service.d/rollback.conf" "0644" "root:root"
install_sys_file "/etc/systemd/system/sandbox-btrfs-boot-reset.service" "0644" "root:root"
install_sys_file "/usr/local/bin/guest-session-manager.sh" "0755" "root:root"
install_sys_file "/usr/local/bin/sandbox-btrfs-manager.sh" "0755" "root:root"
install_sys_file "/usr/local/bin/power-menu.sh" "0755" "root:root"

if ! id guest >/dev/null 2>&1; then
  log_change "[CAMBIO] Creando usuario amnésico 'guest' (UID 1007)..."
  CHANGES=$((CHANGES + 1))
  run useradd -u 1007 -m -s /bin/bash -G render,video,audio,input,storage,users guest || true
fi
if ! id sandbox >/dev/null 2>&1; then
  log_change "[CAMBIO] Creando usuario amnésico 'sandbox' (UID 1008)..."
  CHANGES=$((CHANGES + 1))
  run useradd -u 1008 -m -s /bin/bash -G render,video,audio,input,users sandbox || true
fi

# Desbloquear y asignar contraseña para guest y sandbox
for vol_u in guest sandbox; do
  if id "$vol_u" >/dev/null 2>&1 && [[ "$DRY_RUN" == false && -n "$PASS_VOLATILE_HASH" && "$PASS_VOLATILE_HASH" != "!"* && "$PASS_VOLATILE_HASH" != "*" ]]; then
    cur_vol_status="$(passwd -S "$vol_u" 2>/dev/null | awk '{print $2}' || echo "")"
    if [[ "$cur_vol_status" != "P" || -n "$resp_pass" ]]; then
      log_change "[CAMBIO] Estableciendo contraseña y desbloqueando cuenta volátil '$vol_u' en SDDM..."
      CHANGES=$((CHANGES + 1))
      usermod -p "$PASS_VOLATILE_HASH" "$vol_u"
    fi
  fi
done

# 1.5 SDDM (Catppuccin Mocha y desactivación de autologin.conf)
if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
  log_change "[CAMBIO] Moviendo /etc/sddm.conf.d/autologin.conf a /etc/sddm.conf.d-disabled/..."
  CHANGES=$((CHANGES + 1))
  run mkdir -p /etc/sddm.conf.d-disabled
  run mv /etc/sddm.conf.d/autologin.conf /etc/sddm.conf.d-disabled/autologin.conf
else
  log_ok "[✓] ya el autologin de SDDM está desactivado."
fi
install_sys_file "/etc/sddm.conf.d/10-theme.conf" "0644" "root:root"
install_sys_file "/etc/sddm.conf.d/99-omarchy-login.conf" "0644" "root:root"

if [[ ! -d /usr/share/sddm/themes/catppuccin-mocha-mauve ]]; then
  log_change "[CAMBIO] Instalando tema SDDM catppuccin-mocha-mauve..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == false ]]; then
    tmp_sddm="$(mktemp -d)"
    theme_zip="$tmp_sddm/theme.zip"
    if curl -sSL "https://github.com/catppuccin/sddm/releases/download/v1.1.2/catppuccin-mocha-mauve-sddm.zip" -o "$theme_zip" 2>/dev/null; then
      mkdir -p /usr/share/sddm/themes/catppuccin-mocha-mauve
      unzip -q -o "$theme_zip" -d "$tmp_sddm/extracted"
      if [[ -d "$tmp_sddm/extracted/catppuccin-mocha-mauve" ]]; then
        cp -r "$tmp_sddm/extracted/catppuccin-mocha-mauve"/* /usr/share/sddm/themes/catppuccin-mocha-mauve/
      else
        cp -r "$tmp_sddm/extracted"/* /usr/share/sddm/themes/catppuccin-mocha-mauve/
      fi
    elif git clone --depth 1 https://github.com/catppuccin/sddm.git "$tmp_sddm/sddm" 2>/dev/null; then
      mkdir -p /usr/share/sddm/themes/catppuccin-mocha-mauve
      cp -r "$tmp_sddm/sddm/src"/* /usr/share/sddm/themes/catppuccin-mocha-mauve/
    fi
    rm -rf "$tmp_sddm"
  fi
else
  log_ok "[✓] ya el tema SDDM catppuccin-mocha-mauve está instalado."
fi

# Garantizar grupos multimedia, hardware y adbusers para el usuario admin
if id "$INVOKING_USER" >/dev/null 2>&1; then
  for grp in wheel audio input video kvm storage render adbusers; do
    if getent group "$grp" >/dev/null 2>&1 && ! id -nG "$INVOKING_USER" | tr ' ' '\n' | grep -qx "$grp"; then
      log_change "[CAMBIO] Añadiendo administrador '$INVOKING_USER' al grupo '$grp'..."
      CHANGES=$((CHANGES + 1))
      run usermod -aG "$grp" "$INVOKING_USER"
    fi
  done
fi

# Sincronizar variables Android, symlink ~/Android/Sdk y fish en todos los perfiles de usuario
ALL_ACCOUNTS=("$INVOKING_USER" "${WORKSTATION_USERS[@]}" guest sandbox)
for acc in "${ALL_ACCOUNTS[@]}"; do
  acc_home=$(getent passwd "$acc" 2>/dev/null | cut -d: -f6)
  if [[ -n "$acc_home" && -d "$acc_home" ]]; then
    acc_bashrc="$acc_home/.bashrc"
    if [[ -f "$acc_bashrc" ]] && ! grep -q "ANDROID_HOME" "$acc_bashrc"; then
      log_change "[CAMBIO] Inyectando variables ANDROID_HOME en $acc_bashrc..."
      CHANGES=$((CHANGES + 1))
      if [[ "$DRY_RUN" == false ]]; then
        if grep -q "\[\[ \$- != \*i\* \]\] && return" "$acc_bashrc"; then
          awk '
            /\[\[ \$- != \*i\* \]\] && return/ {
              print "# --- ANDROID & JAVA ENVIRONMENT ---"
              print "export ANDROID_HOME=\"$HOME/Android/Sdk\""
              print "export ANDROID_USER_HOME=\"$HOME/.android\""
              print "export ANDROID_PROJECTS_DIR=\"/z/android-projects\""
              print "export PATH=\"$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$HOME/.local/bin\""
              print "# --- FIN ANDROID & JAVA ENVIRONMENT ---\n"
            }
            { print }
          ' "$acc_bashrc" > "$acc_bashrc.tmp" && mv "$acc_bashrc.tmp" "$acc_bashrc"
        else
          cat << 'EOF' >> "$acc_bashrc"

# --- ANDROID & JAVA ENVIRONMENT ---
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_USER_HOME="$HOME/.android"
export ANDROID_PROJECTS_DIR="/z/android-projects"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$HOME/.local/bin"
# --- FIN ANDROID & JAVA ENVIRONMENT ---
EOF
        fi
        chown "$acc:$acc" "$acc_bashrc" 2>/dev/null || true
      fi
    fi

    # Symlink ~/Android/Sdk -> /opt/android-sdk
    if [[ ! -e "$acc_home/Android/Sdk" ]]; then
      if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$acc_home/Android"
        ln -sfn /opt/android-sdk "$acc_home/Android/Sdk"
        chown -h "$acc:$acc" "$acc_home/Android" "$acc_home/Android/Sdk" 2>/dev/null || true
      fi
    fi

    # Symlinks para espacio colaborativo /z-drive y Cloud FUSE (para usuarios wheel)
    if id -nG "$acc" 2>/dev/null | tr ' ' '\n' | grep -qx "wheel"; then
      # Limpiar posibles alias redundantes previos
      rm -f "$acc_home/google-drive" "$acc_home/Google-Drive" 2>/dev/null || true

      for zl_entry in "Cloud:/z-drive/cloud" \
                      "Idalia:/z-drive/idalia" "Uploads-Gracie:/z-drive/uploads-gracie" "_boveda:/z-drive/boveda"; do
        zl_name="${zl_entry%:*}"
        zl_target="${zl_entry#*:}"
        if [[ ! -L "$acc_home/$zl_name" ]]; then
          log_change "[CAMBIO] Creando symlink $acc_home/$zl_name -> $zl_target ($acc)..."
          CHANGES=$((CHANGES + 1))
          if [[ "$DRY_RUN" == false ]]; then
            ln -sfn "$zl_target" "$acc_home/$zl_name"
            chown -h "$acc:$acc" "$acc_home/$zl_name" 2>/dev/null || true
          fi
        fi
      done

      # Enlace ~/Work/tries -> /z-drive/tries
      if [[ ! -L "$acc_home/Work/tries" ]]; then
        log_change "[CAMBIO] Configurando symlink $acc_home/Work/tries -> /z-drive/tries ($acc)..."
        CHANGES=$((CHANGES + 1))
        if [[ "$DRY_RUN" == false ]]; then
          mkdir -p "$acc_home/Work"
          if [[ -d "$acc_home/Work/tries" ]]; then
            cp -a "$acc_home/Work/tries/." /z-drive/tries/ 2>/dev/null || true
            rm -rf "$acc_home/Work/tries"
          fi
          ln -sfn /z-drive/tries "$acc_home/Work/tries"
          chown -h "$acc:$acc" "$acc_home/Work" "$acc_home/Work/tries" 2>/dev/null || true
        fi
      fi

      # Enlace ~/.config/rclone/rclone.conf -> /etc/rclone/rclone.conf
      if [[ ! -L "$acc_home/.config/rclone/rclone.conf" ]]; then
        log_change "[CAMBIO] Configurando symlink $acc_home/.config/rclone/rclone.conf -> /etc/rclone/rclone.conf ($acc)..."
        CHANGES=$((CHANGES + 1))
        if [[ "$DRY_RUN" == false ]]; then
          mkdir -p "$acc_home/.config/rclone"
          ln -sfn /etc/rclone/rclone.conf "$acc_home/.config/rclone/rclone.conf"
          chown -R "$acc:$acc" "$acc_home/.config/rclone" 2>/dev/null || true
        fi
      fi
    fi

    # Sincronizar plantilla de fish si existe
    acc_fish_d="$acc_home/.config/fish/conf.d"
    if [[ -f /etc/skel/.config/fish/conf.d/android.fish && ! -f "$acc_fish_d/android.fish" ]]; then
      if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$acc_fish_d"
        cp -u /etc/skel/.config/fish/conf.d/android.fish "$acc_fish_d/android.fish" 2>/dev/null || true
        chown -R "$acc:$acc" "$acc_home/.config" 2>/dev/null || true
      fi
    fi
  fi
done

# Provisionar herramientas de bóveda y disco seguro en .bashrc del administrador principal
admin_home=$(getent passwd "$INVOKING_USER" 2>/dev/null | cut -d: -f6)
if [[ -n "$admin_home" && -d "$admin_home" ]]; then
  admin_bashrc="$admin_home/.bashrc"
  if [[ -f "$admin_bashrc" ]] && ! grep -q "DISCO_LUKS_UUID" "$admin_bashrc"; then
    log_change "[CAMBIO] Inyectando herramientas de Disco Seguro y Bóveda Cifrada en $admin_bashrc..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false ]]; then
      cat << 'EOF' >> "$admin_bashrc"

alias agy="$HOME/.local/bin/agy"

# --- SELLO DE GESTION DE DISCO SEGURO LUKS + BTRFS ---
export DISCO_LUKS_UUID="a9d0a6e3-a102-4688-84f4-33b38f7b5320"
export DISCO_MAPPER="luks-$DISCO_LUKS_UUID"
export DISCO_PUNTO_MONTAJE="$HOME/DiscoSeguro"

abrir-disco() {
    local dev_path="/dev/disk/by-uuid/$DISCO_LUKS_UUID"
    if [ ! -b "$dev_path" ]; then
        echo "Error: El disco seguro con UUID $DISCO_LUKS_UUID no está conectado por USB."
        return 1
    fi

    local auto_mount
    auto_mount=$(lsblk -ln -o MOUNTPOINTS "$dev_path" 2>/dev/null | grep -v '^$' || true)
    if [ -z "$auto_mount" ] && [ -e "/dev/mapper/$DISCO_MAPPER" ]; then
        auto_mount=$(lsblk -ln -o MOUNTPOINTS "/dev/mapper/$DISCO_MAPPER" 2>/dev/null | grep -v '^$' || true)
    fi

    if [ -n "$auto_mount" ]; then
        mkdir -p "$DISCO_PUNTO_MONTAJE"
        if ! mountpoint -q "$DISCO_PUNTO_MONTAJE"; then
            sudo mount --bind "$auto_mount" "$DISCO_PUNTO_MONTAJE" 2>/dev/null || true
        fi
        echo "¡Listo! Disco seguro montado y disponible en: $DISCO_PUNTO_MONTAJE"
        return 0
    fi

    if [ ! -e "/dev/mapper/$DISCO_MAPPER" ] && [ ! -e "/dev/mapper/disco_externo_seguro" ]; then
        echo "Desbloqueando contenedor LUKS..."
        if command -v udisksctl >/dev/null 2>&1; then
            udisksctl unlock -b "$dev_path" || sudo cryptsetup open "$dev_path" disco_externo_seguro || return 1
        else
            sudo cryptsetup open "$dev_path" disco_externo_seguro || return 1
        fi
    fi

    local active_mapper=""
    if [ -e "/dev/mapper/$DISCO_MAPPER" ]; then
        active_mapper="/dev/mapper/$DISCO_MAPPER"
    elif [ -e "/dev/mapper/disco_externo_seguro" ]; then
        active_mapper="/dev/mapper/disco_externo_seguro"
    fi

    mkdir -p "$DISCO_PUNTO_MONTAJE"
    if mountpoint -q "$DISCO_PUNTO_MONTAJE"; then
        echo "Aviso: Ya está montado en $DISCO_PUNTO_MONTAJE."
    else
        echo "Montando Btrfs con compresión zstd en $DISCO_PUNTO_MONTAJE..."
        if command -v udisksctl >/dev/null 2>&1; then
            udisksctl mount -b "$active_mapper" 2>/dev/null || sudo mount -o compress=zstd:1,noatime,space_cache=v2 "$active_mapper" "$DISCO_PUNTO_MONTAJE"
        else
            sudo mount -o compress=zstd:1,noatime,space_cache=v2 "$active_mapper" "$DISCO_PUNTO_MONTAJE"
        fi
        local current_mnt
        current_mnt=$(lsblk -ln -o MOUNTPOINTS "$active_mapper" 2>/dev/null | grep -v '^$' | head -n 1 || true)
        if [ -n "$current_mnt" ] && [ "$current_mnt" != "$DISCO_PUNTO_MONTAJE" ]; then
            sudo mount --bind "$current_mnt" "$DISCO_PUNTO_MONTAJE" 2>/dev/null || true
        fi
        echo "¡Listo! Disco seguro disponible en: $DISCO_PUNTO_MONTAJE"
    fi
}

cerrar-disco() {
    local dev_path="/dev/disk/by-uuid/$DISCO_LUKS_UUID"
    
    # 1. Desmontar el bind mount en ~/DiscoSeguro si existe
    if mountpoint -q "$DISCO_PUNTO_MONTAJE"; then
        echo "Desmontando $DISCO_PUNTO_MONTAJE..."
        sync
        if ! sudo umount "$DISCO_PUNTO_MONTAJE" 2>/dev/null; then
            if pgrep -x nautilus >/dev/null 2>&1; then
                echo "Cerrando Nautilus para liberar $DISCO_PUNTO_MONTAJE..."
                nautilus -q 2>/dev/null || true
                sleep 1
            fi
            sudo umount "$DISCO_PUNTO_MONTAJE" 2>/dev/null || sudo umount -l "$DISCO_PUNTO_MONTAJE" 2>/dev/null || true
        fi
    fi

    # 2. Localizar mapper activo
    local mapper_dev=""
    if [ -e "/dev/mapper/$DISCO_MAPPER" ]; then
        mapper_dev="/dev/mapper/$DISCO_MAPPER"
    elif [ -e "/dev/mapper/disco_externo_seguro" ]; then
        mapper_dev="/dev/mapper/disco_externo_seguro"
    fi

    if [ -n "$mapper_dev" ]; then
        # 3. Desmontar todos los puntos de montaje (ej. /run/media/rust/ALMACEN_BTRFS)
        local mnt
        for mnt in $(lsblk -ln -o MOUNTPOINTS "$mapper_dev" 2>/dev/null | grep -v '^$'); do
            echo "Desmontando $mnt..."
            sync
            if ! udisksctl unmount -b "$mapper_dev" 2>/dev/null && ! sudo umount "$mnt" 2>/dev/null; then
                echo "Aviso: $mnt está ocupado por otros procesos. Intentando liberar..."
                if pgrep -x nautilus >/dev/null 2>&1; then
                    echo "Cerrando Nautilus para liberar el almacenamiento..."
                    nautilus -q 2>/dev/null || true
                    sleep 1
                fi
                if command -v fuser >/dev/null 2>&1; then
                    fuser -km -TERM "$mnt" 2>/dev/null || true
                    sleep 1
                fi
                udisksctl unmount -b "$mapper_dev" 2>/dev/null || sudo umount "$mnt" 2>/dev/null || sudo umount -l "$mnt" 2>/dev/null || true
            fi
        done

        # 4. Bloquear el contenedor LUKS
        echo "Bloqueando contenedor cifrado LUKS..."
        local closed=0
        for _ in 1 2 3; do
            if udisksctl lock -b "$dev_path" 2>/dev/null || sudo cryptsetup close "$mapper_dev" 2>/dev/null; then
                closed=1
                break
            fi
            sleep 1
        done

        if [ "$closed" -eq 1 ]; then
            echo "Disco seguro cerrado con éxito. Puedes desconectarlo con seguridad."
        else
            sudo cryptsetup close "$mapper_dev" && echo "Disco seguro cerrado con éxito. Puedes desconectarlo."
        fi
    else
        echo "El contenedor LUKS ya se encuentra cerrado."
    fi
}

alias disco-on="abrir-disco"
alias disco-off="cerrar-disco"
# --- FIN SELLO DISCO SEGURO ---

# === INICIO CONFIGURACION BOVEDA CIFRADA ===
export VAULT_IMAGE="$HOME/.boveda_segura.img"
export VAULT_MAPPER="boveda_privada"
export VAULT_DIR="$HOME/Boveda"

abrir-boveda() {
    if [ ! -f "$VAULT_IMAGE" ]; then
        echo "Error: No se encuentra el archivo de la bóveda en $VAULT_IMAGE"
        return 1
    fi

    if [ -e "/dev/mapper/$VAULT_MAPPER" ]; then
        echo "Aviso: El mapeador $VAULT_MAPPER ya está abierto."
    else
        echo "Abriendo contenedor LUKS..."
        sudo cryptsetup open "$VAULT_IMAGE" "$VAULT_MAPPER" || return 1
    fi

    mkdir -p "$VAULT_DIR"
    if mountpoint -q "$VAULT_DIR"; then
        echo "Aviso: $VAULT_DIR ya está montado."
    else
        echo "Montando Btrfs en $VAULT_DIR..."
        sudo mount -o compress=zstd:1 "/dev/mapper/$VAULT_MAPPER" "$VAULT_DIR" && \
        echo "Bóveda montada y lista en: $VAULT_DIR"
    fi
}

cerrar-boveda() {
    if mountpoint -q "$VAULT_DIR"; then
        echo "Desmontando $VAULT_DIR..."
        sync
        if ! sudo umount "$VAULT_DIR" 2>/dev/null; then
            echo "Aviso: $VAULT_DIR está ocupado por procesos. Intentando liberar..."
            if pgrep -x nautilus >/dev/null 2>&1; then
                echo "Cerrando Nautilus para liberar la bóveda..."
                nautilus -q 2>/dev/null || true
                sleep 1
            fi
            if ! sudo umount "$VAULT_DIR" 2>/dev/null; then
                if command -v fuser >/dev/null 2>&1; then
                    echo "Liberando procesos bloqueantes en $VAULT_DIR..."
                    fuser -km -TERM "$VAULT_DIR" 2>/dev/null || true
                    sleep 1
                fi
                sudo umount "$VAULT_DIR" 2>/dev/null || sudo umount -l "$VAULT_DIR" || { echo "Error: Hay procesos usando $VAULT_DIR"; return 1; }
            fi
        fi
    fi

    if [ -e "/dev/mapper/$VAULT_MAPPER" ]; then
        echo "Bloqueando contenedor LUKS..."
        local closed=0
        for _ in 1 2 3; do
            if sudo cryptsetup close "$VAULT_MAPPER" 2>/dev/null; then
                closed=1
                break
            fi
            sleep 1
        done

        if [ "$closed" -eq 1 ]; then
            echo "Bóveda cerrada y bloqueada con éxito."
        else
            sudo cryptsetup close "$VAULT_MAPPER" && echo "Bóveda cerrada y bloqueada con éxito."
        fi
    else
        echo "La bóveda ya se encuentra cerrada."
    fi
}

alias boveda-on="abrir-boveda"
alias boveda-off="cerrar-boveda"
# === FIN CONFIGURACION BOVEDA CIFRADA ===
EOF
      chown "$INVOKING_USER:$INVOKING_USER" "$admin_bashrc" 2>/dev/null || true
    fi
  fi
fi

# ==============================================================================
# CAPA 02: Almacenamiento Compartido (/z, /zt, /z-drive), Wallpapers y synchub
# ==============================================================================
echo ""
log_info "=== [Capa 02] Almacenamiento Compartido (/z, /zt, /z-drive), Wallpapers y synchub ==="

SHARED_DIRS=(
  "/z:2775"
  "/z/nvims:2775"
  "/z/wallpaper-collection:2775"
  "/z/android-projects:2770"
  "/zt:2770"
  "/z-drive:2770"
  "/z-drive/tries:2770"
  "/z-drive/idalia:2770"
  "/z-drive/uploads-gracie:2770"
  "/z-drive/boveda:2770"
  "/z-drive/cloud:2770"
  "/opt/android-sdk:2770"
)

for entry in "${SHARED_DIRS[@]}"; do
  dir_path="${entry%:*}"
  dir_mode="${entry#*:}"
  if [[ ! -d "$dir_path" ]]; then
    log_change "[CAMBIO] Creando directorio compartido $dir_path ($dir_mode root:wheel)..."
    CHANGES=$((CHANGES + 1))
    run install -d -o root -g wheel -m "$dir_mode" "$dir_path"
    run setfacl -m g:wheel:rwx -m d:g:wheel:rwx "$dir_path"
  fi
done
log_ok "[✓] ya la estructura de directorios compartidos (/z, /zt, /z-drive, /opt/android-sdk) existe."

# Watchers de permisos y unidades systemd
for bin_f in fix_shared_dir_perms.sh z-perms_watcher.sh z-drive-perms_watcher.sh android-sdk-perms_watcher.sh android-projects-perms_watcher.sh; do
  install_sys_file "/usr/local/bin/${bin_f}" "0755" "root:root"
done
for unit_f in z-perms.service z-perms.timer z-drive-perms.service z-drive-perms.timer android-sdk-perms.service android-sdk-perms.timer android-projects-perms.service android-projects-perms.timer; do
  install_sys_file "/etc/systemd/system/${unit_f}" "0644" "root:root"
done

# Wallpapers de sistema para Clavis
mkdir -p /usr/share/backgrounds 2>/dev/null || true
if [[ ! -f /usr/share/backgrounds/wallhaven-5y3571.jpg ]]; then
  log_change "[CAMBIO] Descargando wallpaper /usr/share/backgrounds/wallhaven-5y3571.jpg..."
  CHANGES=$((CHANGES + 1))
  run curl -sL -o /usr/share/backgrounds/wallhaven-5y3571.jpg https://w.wallhaven.cc/full/5y/wallhaven-5y3571.jpg || true
fi
if [[ ! -f /usr/share/backgrounds/wallhaven-rq6yqm.jpg ]]; then
  log_change "[CAMBIO] Descargando wallpaper /usr/share/backgrounds/wallhaven-rq6yqm.jpg..."
  CHANGES=$((CHANGES + 1))
  run curl -sL -o /usr/share/backgrounds/wallhaven-rq6yqm.jpg https://w.wallhaven.cc/full/rq/wallhaven-rq6yqm.jpg || true
fi

# Suite declarativa synchub y rclone
install_sys_file "/etc/fuse.conf" "0644" "root:root"
install_sys_file "/etc/environment.d/20-rclone.conf" "0644" "root:root"
install_sys_file "/etc/profile.d/20-rclone.sh" "0755" "root:root"
install_sys_file "/etc/fish/conf.d/rclone.fish" "0644" "root:root"
install_sys_file "/etc/rclone/exclusiones-sync.txt" "0644" "root:wheel"
install_sys_file "/etc/rclone/sync-idalia.conf" "0644" "root:wheel"
install_sys_file "/etc/rclone/sync-uploads-gracie.conf" "0644" "root:wheel"
if [[ ! -f /etc/rclone/rclone.conf ]]; then
  install_sys_file "/etc/rclone/rclone.conf" "0660" "root:wheel"
fi

for sh_conf in "$SYS_ASSETS"/etc/synchub/targets.d/*.conf; do
  [[ -f "$sh_conf" ]] || continue
  install_sys_file "/etc/synchub/targets.d/$(basename "$sh_conf")" "0644" "root:wheel"
done
for sh_bin in synchub sync-all sync-hub-bar sync-idalia sync-status sync-tries sync-tries-watcher sync-uploads-gracie upload-moved-gdrive upload-moved-shutdown-supervisor watch-moved; do
  install_sys_file "/usr/local/bin/${sh_bin}" "0755" "root:root"
done
for sh_unit in synchub@.service synchub@.timer synchub-btrfs-attach.service rclone-gdrive-mount.service \
               sync-idalia.service sync-idalia.timer sync-tries.service sync-tries.timer sync-tries-watcher.service \
               sync-uploads-gracie.service sync-uploads-gracie.timer; do
  install_sys_file "/etc/systemd/system/${sh_unit}" "0644" "root:root"
done
install_sys_file "/etc/udev/rules.d/99-almacen-btrfs.rules" "0644" "root:root"

# Escudo de Primera Sincronización: Restaurar /z-drive/tries si está vacío y hay disco local montado
if [[ -d "/z-drive/tries" && $(find /z-drive/tries -maxdepth 1 -mindepth 1 2>/dev/null | wc -l) -eq 0 ]]; then
  if [[ -x /usr/local/bin/sync-tries ]] && findmnt -n -o TARGET /run/media/*/ALMACEN_BTRFS >/dev/null 2>&1; then
    log_change "[CAMBIO] Restaurando proyectos iniciales en /z-drive/tries desde ALMACEN_BTRFS..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false ]]; then
      /usr/local/bin/sync-tries --pull || true
    fi
  fi
fi

# ==============================================================================
# CAPA 03: Paquetes [omarchy-personal], Toolchain Global, Fuentes y Android
# ==============================================================================
echo ""
log_info "=== [Capa 03] Paquetes [omarchy-personal], Toolchain Global y Entorno Android ==="

PERSONAL_PKGS=(
  herdr
  ravn-trio
  ravn-webapps
  ravn-omarchy-overlay
  ravn-sessionizer
  ravn-git-bare-clone
  ravn-home-common
  ravn-home-niri
)

OFFICIAL_PKGS=(
  base-devel clang cmake ninja rust go pnpm
  jdk21-openjdk jdk17-openjdk android-tools android-udev kotlin gradle
  python-evdev python-pyudev python-gobject python-cairo
  inotify-tools age rclone fuse3 git-delta sassc
  brave-origin-bin zen-browser-bin
  ghostty kitty alacritty zsh fish yazi atuin fastfetch zed mission-center thunderbird
  quickshell qt6-base qt6-declarative qt6-svg qt6-wayland qt6-5compat
  qt6-lottie qt6-location qt6-positioning qt6-tools maplibre-native-qt qtkeychain-qt6
  vulkan-headers ttf-material-symbols-variable matugen awww brightnessctl ddcutil
  imagemagick xdg-terminal-exec wl-clipboard slurp grim gpu-screen-recorder ffmpeg
  libpulse hyprpicker flatpak waybar fuzzel mako swaybg swaylock xwayland-satellite
  xdg-desktop-portal-gnome polkit-gnome playerctl cliphist libqalculate wlsunset
  gtk-layer-shell cava ttf-ibm-plex ttf-ibmplex-mono-nerd
)

MISSING_PKGS=()
for pkg in "${PERSONAL_PKGS[@]}" "${OFFICIAL_PKGS[@]}"; do
  if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      MISSING_PKGS+=("$pkg")
    fi
  fi
done

# Verificar si herdr tiene upgrade disponible en [omarchy-personal]
if pacman -Qu herdr >/dev/null 2>&1; then
  MISSING_PKGS+=("herdr")
fi

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
  log_change "[CAMBIO] Instalando ${#MISSING_PKGS[@]} paquetes faltantes vía pacman (${MISSING_PKGS[*]})..."
  CHANGES=$((CHANGES + 1))
  run pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
else
  log_ok "[✓] ya todos los paquetes de [omarchy-personal] y el Toolchain oficial están instalados."
fi

# Garantizar Java 21 como runtime por defecto del sistema
if command -v archlinux-java >/dev/null 2>&1; then
  cur_java="$(archlinux-java get 2>/dev/null || echo "")"
  if [[ "$cur_java" != "java-21-openjdk" && -d "/usr/lib/jvm/java-21-openjdk" ]]; then
    log_change "[CAMBIO] Configurando Java 21 como entorno JVM por defecto del sistema..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false ]]; then
      archlinux-java set java-21-openjdk 2>/dev/null || true
    fi
  fi
fi

# Paquetes de AUR requeridos por Clavis / Nyxuri / Dotfiles y Ecosistema Google/Android
AUR_PKGS=(
  qt6-m3shapes-git libcava ttf-lxgw-wenkai-screen mpvpaper-git dotbare
  android-studio-canary google-chrome google-cloud-cli firebase-tools-bin
)
MISSING_AUR=()
for apkg in "${AUR_PKGS[@]}"; do
  if ! pacman -Qi "$apkg" >/dev/null 2>&1; then
    MISSING_AUR+=("$apkg")
  fi
done

if [[ ${#MISSING_AUR[@]} -gt 0 ]] && command -v yay >/dev/null 2>&1; then
  log_change "[CAMBIO] Instalando paquetes AUR faltantes (${MISSING_AUR[*]}) como '$INVOKING_USER'..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == true ]]; then
    run sudo -u "$INVOKING_USER" yay -S --needed --noconfirm "${MISSING_AUR[@]}"
  else
    sudo -u "$INVOKING_USER" yay -S --needed --noconfirm "${MISSING_AUR[@]}" || true
  fi
else
  log_ok "[✓] ya los paquetes AUR requeridos están instalados."
fi

# Configuración global de Android SDK y fork-docs
install_sys_file "/etc/environment.d/10-android.conf" "0644" "root:root"
install_sys_file "/etc/profile.d/android.sh" "0755" "root:root"
install_sys_file "/etc/fish/conf.d/android.fish" "0644" "root:root"
install_sys_file "/usr/local/bin/fork-docs" "0755" "root:root"
install_sys_file "/usr/local/bin/google-chrome" "0755" "root:root"

# ==============================================================================
# CAPA 04: Entornos de Escritorio (niri-edge, key-cli, Clavis, Nyxuri)
# ==============================================================================
echo ""
log_info "=== [Capa 04] Entornos de Escritorio: Niri Edge, key-cli, Clavis y Nyxuri ==="

if [[ ! -d "$BUILD_DIR" ]]; then
  log_change "[CAMBIO] Creando directorio de compilación $BUILD_DIR..."
  CHANGES=$((CHANGES + 1))
  run install -d -o "$INVOKING_USER" -g wheel -m 2775 "$BUILD_DIR"
fi
if ! git -C / config --system --get-all safe.directory 2>/dev/null | grep -qxF "${BUILD_DIR}/*"; then
  run git -C / config --system --add safe.directory "${BUILD_DIR}/*"
fi

clone_or_update_fork() {
  local dir_name="$1"
  local fork_url="$2"
  local branch="$3"
  local upstream_url="$4"
  local target_dir="${BUILD_DIR}/${dir_name}"

  if [[ ! -d "${target_dir}/.git" ]]; then
    log_change "[CAMBIO] Clonando ${dir_name} (${branch}) en ${target_dir}..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false ]]; then
      sudo -u "$INVOKING_USER" git clone -b "$branch" "$fork_url" "$target_dir"
      if [[ -n "$upstream_url" ]]; then
        sudo -u "$INVOKING_USER" git -C "$target_dir" remote add upstream "$upstream_url" || true
        sudo -u "$INVOKING_USER" git -C "$target_dir" remote set-url --push upstream DISABLE || true
      fi
      chmod -R g+rwX "$target_dir"
    fi
    return 0
  fi
  return 1
}

if [[ "$SKIP_BUILDS" == false ]]; then
  # 4.1 niri-edge
  clone_or_update_fork "niri-edge" "https://github.com/robert-flo/PJ-NIRI-fo-niri-edge.git" "personal" "https://github.com/StatIndet/niri-edge.git" || true
  if [[ ! -x /usr/local/bin/niri ]]; then
    log_change "[CAMBIO] Compilando e instalando niri-edge desde $BUILD_DIR/niri-edge..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false && -d "$BUILD_DIR/niri-edge" ]]; then
      (
        cd "$BUILD_DIR/niri-edge"
        sudo -u "$INVOKING_USER" env CARGO_NET_GIT_FETCH_WITH_CLI=true cargo build --release
        install -Dm755 target/release/niri /usr/local/bin/niri
        ln -sf /usr/local/bin/niri /usr/bin/niri
        install -Dm755 resources/niri-session /usr/local/bin/niri-session
        ln -sf /usr/local/bin/niri-session /usr/bin/niri-session
        install -Dm644 resources/niri.desktop /usr/share/wayland-sessions/niri.desktop
        install -Dm644 resources/niri.desktop /usr/local/share/wayland-sessions/niri.desktop
        install -Dm644 resources/niri-portals.conf /usr/share/xdg-desktop-portal/niri-portals.conf
        install -Dm644 resources/niri.service /usr/lib/systemd/user/niri.service
        install -Dm644 resources/niri-shutdown.target /usr/lib/systemd/user/niri-shutdown.target
      )
    fi
  else
    log_ok "[✓] ya /usr/local/bin/niri está compilado e instalado."
  fi

  # 4.2 key-cli
  clone_or_update_fork "key-cli" "https://github.com/robert-flo/PJ-NIRI-fo-key-cli.git" "personal" "https://github.com/StatIndet/key-cli.git" || true
  if ! command -v key >/dev/null 2>&1 && [[ ! -x /usr/local/bin/key ]]; then
    log_change "[CAMBIO] Instalando key-cli desde $BUILD_DIR/key-cli..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false && -d "$BUILD_DIR/key-cli" ]]; then
      (
        cd "$BUILD_DIR/key-cli"
        sudo -u "$INVOKING_USER" /usr/bin/python3 scripts/installer.py || true
        sudo -u "$INVOKING_USER" /usr/bin/python3 scripts/installer.py --keyboard enable --acknowledge-keyboard-access --apply || true
        if [[ -f /usr/local/libexec/key-cli/key-cpu-power ]]; then
          setcap 'cap_dac_read_search=ep' /usr/local/libexec/key-cli/key-cpu-power || true
        fi
        if [[ -f completions/key.fish ]]; then
          install -Dm644 completions/key.fish /usr/share/fish/vendor_completions.d/key.fish
        fi
      )
    fi
  else
    log_ok "[✓] ya key-cli está instalado."
  fi

  # 4.3 Clavis Shell (robert-flo/quickshell)
  clone_or_update_fork "quickshell" "https://github.com/robert-flo/quickshell.git" "personal" "https://github.com/StatIndet/quickshell.git" || true
  if [[ ! -d /etc/xdg/quickshell/clavis ]]; then
    log_change "[CAMBIO] Compilando e instalando Clavis Shell desde $BUILD_DIR/quickshell..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false && -d "$BUILD_DIR/quickshell" ]]; then
      (
        cd "$BUILD_DIR/quickshell"
        sudo -u "$INVOKING_USER" /usr/bin/python3 scripts/release.py bundle-resources --cache /tmp/clavis-cache || true
        sudo -u "$INVOKING_USER" cmake -S . -B build -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_INSTALL_LIBDIR=lib \
          -DCLAVIS_CONFIG_INSTALL_DIR=/etc/xdg/quickshell/clavis \
          -DPython3_EXECUTABLE=/usr/bin/python3
        sudo -u "$INVOKING_USER" cmake --build build
        cmake --install build
      )
    fi
  else
    log_ok "[✓] ya Clavis Shell (/etc/xdg/quickshell/clavis) está instalado."
  fi
fi

# 4.4 Tema MacTahoe (iconos, cursores y temas GTK)
if [[ ! -d /usr/share/icons/MacTahoe-dark ]]; then
  log_change "[CAMBIO] Instalando iconos y cursores MacTahoe en /usr/share/icons..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == false ]]; then
    tmp_mt="$(mktemp -d)"
    if git clone --depth 1 https://github.com/vinceliuice/MacTahoe-icon-theme.git "$tmp_mt/MacTahoe" 2>/dev/null; then
      (cd "$tmp_mt/MacTahoe" && ./install.sh -d /usr/share/icons) || true
      (cd "$tmp_mt/MacTahoe/cursors" && ./install.sh) || true
    fi
    rm -rf "$tmp_mt"
  fi
else
  log_ok "[✓] ya el tema MacTahoe está instalado en /usr/share/icons."
fi

if [[ ! -d /usr/share/themes/MacTahoe-Dark ]]; then
  log_change "[CAMBIO] Instalando tema MacTahoe GTK en /usr/share/themes..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == false ]]; then
    tmp_mgt="$(mktemp -d)"
    if git clone --depth 1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$tmp_mgt/MacTahoe" 2>/dev/null; then
      (cd "$tmp_mgt/MacTahoe" && ./install.sh -d /usr/share/themes) || true
    fi
    rm -rf "$tmp_mgt"
  fi
else
  log_ok "[✓] ya el tema MacTahoe GTK está instalado en /usr/share/themes."
fi

# Componentes de Shell Clavis: clavis-fish-theme y my_zsh_prompt
clone_or_update_fork "clavis-fish-theme" "https://github.com/robert-flo/PJ-NIRI-fo-clavis-fish-theme.git" "personal" "https://github.com/StatIndet/clavis-fish-theme.git" || true
if [[ ! -x /usr/local/bin/clavis-fish-theme ]]; then
  log_change "[CAMBIO] Compilando e instalando clavis-fish-theme desde $BUILD_DIR/clavis-fish-theme..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == false && -d "$BUILD_DIR/clavis-fish-theme" ]]; then
    (
      cd "$BUILD_DIR/clavis-fish-theme"
      sudo -u "$INVOKING_USER" env CARGO_NET_GIT_FETCH_WITH_CLI=true cargo build --release
      install -Dm755 target/release/clavis-fish-theme /usr/local/bin/clavis-fish-theme
    )
  fi
else
  log_ok "[✓] ya clavis-fish-theme está compilado e instalado en /usr/local/bin/clavis-fish-theme."
fi

clone_or_update_fork "my_zsh_prompt" "https://github.com/robert-flo/PJ-NIRI-fo-my_zsh_prompt.git" "personal" "https://github.com/StatIndet/my_zsh_prompt.git" || true
if [[ ! -x /usr/local/bin/prompt ]]; then
  log_change "[CAMBIO] Compilando e instalando prompt desde $BUILD_DIR/my_zsh_prompt..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == false && -d "$BUILD_DIR/my_zsh_prompt" ]]; then
    (
      cd "$BUILD_DIR/my_zsh_prompt"
      sudo -u "$INVOKING_USER" g++ -O3 -std=c++17 prompt.cpp -o prompt
      install -Dm755 prompt /usr/local/bin/prompt
    )
  fi
else
  log_ok "[✓] ya prompt está compilado e instalado en /usr/local/bin/prompt."
fi

# 4.5 Nyxuri Engine (Edge + Stable) y scripts de actualización
clone_or_update_fork "nyxuri" "https://github.com/robert-flo/PJ-NIRI-fo-nyxuri.git" "personal" "https://github.com/ech678/Nyxuri.git" || true
if [[ ! -d "$BUILD_DIR/nyxuri-stable/.git" ]]; then
  log_change "[CAMBIO] Clonando nyxuri-stable (v3.1.0) en $BUILD_DIR/nyxuri-stable..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == false ]]; then
    sudo -u "$INVOKING_USER" git clone --branch v3.1.0 --depth 1 https://github.com/ech678/Nyxuri.git "$BUILD_DIR/nyxuri-stable" || true
  fi
fi

if [[ -d "$BUILD_DIR/nyxuri" && "$DRY_RUN" == false ]]; then
  chmod +x "$BUILD_DIR/nyxuri/nyxuri/launcher.sh" "$BUILD_DIR/nyxuri/shell/nyxuri-shell" 2>/dev/null || true
  ln -sfn "$BUILD_DIR/nyxuri/nyxuri/launcher.sh" /usr/local/bin/nyxuri
  ln -sfn "$BUILD_DIR/nyxuri/shell/nyxuri-shell" /usr/local/bin/nyxuri-shell
fi

install_sys_file "/usr/local/bin/update-niri-desktop.sh" "0755" "root:root"
install_sys_file "/usr/local/bin/update-nyxuri-desktop.sh" "0755" "root:root"
install_sys_file "/etc/systemd/system/niri-update.service" "0644" "root:root"
install_sys_file "/etc/systemd/system/niri-update.timer" "0644" "root:root"
install_sys_file "/etc/greetd/config.toml" "0644" "root:root"
install_sys_file "/etc/polkit-1/rules.d/50-noctalia-greeter.rules" "0644" "root:root"
install_sys_file "/usr/share/applications/top.imsyy.splayer_next.desktop" "0644" "root:root"

# Registrar sesión Wayland omarchy en el display manager si existe en /usr/local
if [[ -f /usr/local/share/wayland-sessions/omarchy.desktop && ! -e /usr/share/wayland-sessions/omarchy.desktop ]]; then
  log_change "[CAMBIO] Registrando sesión Wayland omarchy en /usr/share/wayland-sessions..."
  CHANGES=$((CHANGES + 1))
  run ln -sfn /usr/local/share/wayland-sessions/omarchy.desktop /usr/share/wayland-sessions/omarchy.desktop
fi

# Configurar Greetd + Noctalia Greeter como Display Manager por defecto
if ! systemctl is-enabled greetd.service >/dev/null 2>&1; then
  log_change "[CAMBIO] Habilitando Greetd (Noctalia Greeter) como Display Manager por defecto..."
  CHANGES=$((CHANGES + 1))
  run systemctl disable sddm.service || true
  run systemctl enable greetd.service || true
else
  log_ok "[✓] ya Greetd (Noctalia Greeter) está habilitado como Display Manager por defecto."
fi

# 4.6 Inicialización e Idempotencia de Dotfiles de Clavis (niri y niri-test)
for clavis_u in niri niri-test; do
  if id "$clavis_u" >/dev/null 2>&1; then
    u_home="$(getent passwd "$clavis_u" | cut -d: -f6)"
    u_uid="$(id -u "$clavis_u")"

    if [[ ! -d "$u_home/.cfg" && ! -f "$u_home/.config/niri/config.kdl" ]]; then
      log_change "[CAMBIO] Inicializando dotfiles de Clavis (robert-flo/niri-dotfiles) en '$clavis_u'..."
      CHANGES=$((CHANGES + 1))
      if [[ "$DRY_RUN" == false ]]; then
        sudo -u "$clavis_u" env HOME="$u_home" bash -c '
          git clone --bare https://github.com/robert-flo/niri-dotfiles.git "$HOME/.cfg"
          git --git-dir="$HOME/.cfg" --work-tree="$HOME" config status.showUntrackedFiles no
          git --git-dir="$HOME/.cfg" --work-tree="$HOME" checkout -f
        ' || true
      fi
    else
      log_ok "[✓] ya el usuario '$clavis_u' cuenta con su árbol de dotfiles de Clavis."
    fi

    # Adaptación de rutas absolutas para usuarios distintos de /home/niri (ej. niri-test)
    if [[ "$u_home" != "/home/niri" && -f "$u_home/.config/clavis/config.json" ]]; then
      if grep -q '/home/niri/' "$u_home/.config/clavis/config.json"; then
        log_change "[CAMBIO] Adaptando rutas absolutas a $u_home en configs de '$clavis_u'..."
        CHANGES=$((CHANGES + 1))
        if [[ "$DRY_RUN" == false ]]; then
          for f_adj in "$u_home/.config/clavis/config.json" "$u_home/.config/obsidian/obsidian.json" "$u_home/.config/environment.d/clavis-mpvpaper.conf"; do
            [[ -f "$f_adj" ]] && sed -i "s|/home/niri/|$u_home/|g" "$f_adj"
          done
        fi
      fi
    fi

    # Garantizar activación de servicios systemd user para Clavis en Niri
    if [[ ! -e "$u_home/.config/systemd/user/niri.service.wants/clavis-shell.service" || ! -e "$u_home/.config/systemd/user/niri.service.wants/clavis-clipboard.service" ]]; then
      log_change "[CAMBIO] Habilitando servicios systemd user (clavis-shell y clavis-clipboard) para '$clavis_u'..."
      CHANGES=$((CHANGES + 1))
      if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$u_home/.config/systemd/user/niri.service.wants"
        ln -sfn /usr/lib/systemd/user/clavis-shell.service "$u_home/.config/systemd/user/niri.service.wants/clavis-shell.service"
        ln -sfn /usr/local/lib/systemd/user/clavis-clipboard.service "$u_home/.config/systemd/user/niri.service.wants/clavis-clipboard.service"
        chown -R "$clavis_u:$clavis_u" "$u_home/.config/systemd"
      fi
    else
      log_ok "[✓] ya los servicios systemd de Clavis están activos para '$clavis_u'."
    fi

    # Garantizar paleta Matugen (colors.json) según el modo ("light") y fondo configurado
    if [[ ! -f "$u_home/.local/share/clavis/profiles/default/generated/clavis/colors.json" && -f "$u_home/.config/clavis/config.json" && -x /etc/xdg/quickshell/clavis/scripts/theme/generate_matugen_colors.sh ]]; then
      log_change "[CAMBIO] Generando paleta de tema Matugen (colors.json) para '$clavis_u'..."
      CHANGES=$((CHANGES + 1))
      if [[ "$DRY_RUN" == false ]]; then
        wp_path="$(grep -oP '"path":\s*"\K[^"]+' "$u_home/.config/clavis/config.json" | head -n1 || echo "")"
        wp_mode="$(grep -oP '"mode":\s*"\K[^"]+' "$u_home/.config/clavis/config.json" | head -n1 || echo "light")"
        if [[ -f "$wp_path" ]]; then
          sudo -u "$clavis_u" env HOME="$u_home" /etc/xdg/quickshell/clavis/scripts/theme/generate_matugen_colors.sh \
            --image "$wp_path" --mode "$wp_mode" \
            --templates fcitx5_theme,fcitx5_panel,fcitx5_highlight,fcitx5_radio,fcitx5_arrow,clavis_fish,niri_focus_ring,btop,cava,kitty,yazi >/dev/null 2>&1 || true
        fi
      fi
    else
      log_ok "[✓] ya la paleta Matugen (colors.json) está generada para '$clavis_u'."
    fi

    # Generación dinámica de outputs.kdl si no existe (evita avisos en niri validate)
    if [[ ! -f "$u_home/.config/niri/outputs.kdl" ]]; then
      active_conn="$(for p in /sys/class/drm/card*-*/status; do if [[ "$(cat "$p" 2>/dev/null)" == "connected" ]]; then basename "$(dirname "$p")" | sed 's/^card[0-9]*-//'; break; fi; done)"
      if [[ -n "$active_conn" ]]; then
        log_change "[CAMBIO] Generando outputs.kdl ($active_conn) para '$clavis_u'..."
        CHANGES=$((CHANGES + 1))
        if [[ "$DRY_RUN" == false ]]; then
          cat << EOF > "$u_home/.config/niri/outputs.kdl"
output "$active_conn" {
    mode "1920x1080@60.000"
    scale 1.0
}
EOF
          chown "$clavis_u:$clavis_u" "$u_home/.config/niri/outputs.kdl"
        fi
      fi
    fi

    # Aplicar gsettings (color-scheme, tema GTK y cursor) si el bus D-Bus de usuario está disponible
    if [[ -S "/run/user/$u_uid/bus" && "$DRY_RUN" == false ]]; then
      sudo -u "$clavis_u" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$u_uid/bus" gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
      sudo -u "$clavis_u" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$u_uid/bus" gsettings set org.gnome.desktop.interface gtk-theme 'MacTahoe-Dark' 2>/dev/null || true
      sudo -u "$clavis_u" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$u_uid/bus" gsettings set org.gnome.desktop.interface icon-theme 'MacTahoe-dark' 2>/dev/null || true
      sudo -u "$clavis_u" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$u_uid/bus" gsettings set org.gnome.desktop.interface cursor-theme 'MacTahoe-dark' 2>/dev/null || true
    fi
  fi
done

for nyx_u in nyxuri nyxuri-test; do
  if id "$nyx_u" >/dev/null 2>&1; then
    u_home="$(getent passwd "$nyx_u" | cut -d: -f6)"
    if [[ ! -f "$u_home/.config/niri/config.kdl" && -x /usr/local/bin/nyxuri ]]; then
      log_change "[CAMBIO] Inicializando unidades de Nyxuri Edge en '$nyx_u'..."
      CHANGES=$((CHANGES + 1))
      if [[ "$DRY_RUN" == false ]]; then
        sudo -u "$nyx_u" -H bash -c '
          mkdir -p "$HOME/.config/noctalia"
          ln -sfn /z/wallpaper-collection "$HOME/.config/noctalia/wallpapers"
          for unit in niri noctalia kitty fastfetch fish starship theme wallpapers xdg-desktop-portal zed \
                      shell.bar shell.desktopcards shell.dock shell.keystone shell.launcher shell.lock \
                      shell.notifications shell.regionselector shell.session shell.settings shell.sidebars shell.wallpaper; do
            /usr/local/bin/nyxuri on "$unit" || true
          done
          /usr/local/bin/nyxuri shell set nyxuri-shell /usr/local/bin/nyxuri-shell || true
        ' || true
      fi
    else
      log_ok "[✓] ya el usuario '$nyx_u' cuenta con su configuración de Nyxuri."
    fi

    # Garantizar symlink de wallpapers compartidos si el directorio noctalia existe
    if [[ -d "$u_home/.config/noctalia" && ! -e "$u_home/.config/noctalia/wallpapers" ]]; then
      log_change "[CAMBIO] Vinculando /z/wallpaper-collection en noctalia para '$nyx_u'..."
      CHANGES=$((CHANGES + 1))
      run ln -sfn /z/wallpaper-collection "$u_home/.config/noctalia/wallpapers"
      run chown -h "$nyx_u:$nyx_u" "$u_home/.config/noctalia/wallpapers"
    fi
  fi
done

if id nyxuri-legacy >/dev/null 2>&1; then
  leg_home="$(getent passwd nyxuri-legacy | cut -d: -f6)"
  if [[ ! -f "$leg_home/.config/niri/config.kdl" && -d "$BUILD_DIR/nyxuri-stable" ]]; then
    log_change "[CAMBIO] Inicializando Nyxuri v3.1.0 Stable en 'nyxuri-legacy'..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false ]]; then
      sudo -u nyxuri-legacy env HOME="$leg_home" python3 -c "
import sys
sys.path.insert(0, '$BUILD_DIR/nyxuri-stable')
sys.argv = ['nyxuri', 'install', 'config']
from nyxuri.cli import main
main()
" </dev/null || true
    fi
  else
    log_ok "[✓] ya el usuario 'nyxuri-legacy' cuenta con su configuración estable."
  fi
fi

if id omarchy-test >/dev/null 2>&1; then
  ot_home="$(getent passwd omarchy-test | cut -d: -f6)"
  if [[ ! -f "$ot_home/.config/hypr/hyprland.lua" && ! -f "$ot_home/.config/hypr/hyprland.conf" ]]; then
    log_change "[CAMBIO] Sembrando entorno default Omarchy Hyprland en 'omarchy-test'..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == false ]]; then
      mkdir -p "$ot_home/.config"
      omarchy_src="${OMARCHY_PATH:-/z/fo-omarchy}"
      if [[ -d "$omarchy_src/config/hypr" ]]; then
        cp -r "$omarchy_src/config/hypr" "$ot_home/.config/"
      elif [[ -d "/home/$INVOKING_USER/.config/hypr" ]]; then
        cp -r "/home/$INVOKING_USER/.config/hypr" "$ot_home/.config/"
      fi
      chown -R omarchy-test:omarchy-test "$ot_home"
    fi
  else
    log_ok "[✓] ya el usuario 'omarchy-test' cuenta con su configuración de Hyprland."
  fi
fi

# ==============================================================================
# CAPA 05 y CAPA 07: Suite Neovim Dual (/z/nvims) y forkhub
# ==============================================================================
echo ""
log_info "=== [Capas 05 y 07] Suite Neovim Dual (/z/nvims) y Automatización forkhub ==="

for nv_bin in nvim rvim cvim 2kvim; do
  install_sys_file "/usr/local/bin/${nv_bin}" "0755" "root:root"
done
install_sys_file "/usr/local/bin/craftvim"

install_sys_file "/usr/local/bin/forkhub" "0755" "root:root"
install_sys_file "/etc/systemd/system/forkhub.service" "0644" "root:root"
install_sys_file "/etc/systemd/system/forkhub.timer" "0644" "root:root"

for fk_conf in "$REPO_ROOT"/scripts/forkhub/repos.d/*.conf; do
  [[ -f "$fk_conf" ]] || continue
  install_sys_file "/etc/forkhub/repos.d/$(basename "$fk_conf")" "0664" "root:wheel"
done

# CLI global para onboarding y convergencia
if [[ ! -e /usr/local/bin/omarchy-onboard ]]; then
  log_change "[CAMBIO] Vinculando CLI global omarchy-onboard -> $REPO_ROOT/scripts/omarchy-onboarding/onboard-machine.sh..."
  CHANGES=$((CHANGES + 1))
  run ln -sfn "$REPO_ROOT/scripts/omarchy-onboarding/onboard-machine.sh" /usr/local/bin/omarchy-onboard
fi

if [[ "$DRY_RUN" == false ]]; then
  systemctl daemon-reload
  for unit_en in forkhub.timer niri-update.timer z-perms.service z-perms.timer z-drive-perms.timer \
                 android-sdk-perms.timer android-projects-perms.timer sandbox-btrfs-boot-reset.service \
                 rclone-gdrive-mount.service sync-tries-watcher.service \
                 sync-tries.timer sync-idalia.timer sync-uploads-gracie.timer; do
    if ! systemctl is-enabled --quiet "$unit_en" 2>/dev/null; then
      log_change "[CAMBIO] Habilitando unidad systemd $unit_en..."
      CHANGES=$((CHANGES + 1))
      systemctl enable --now "$unit_en" 2>/dev/null || systemctl enable "$unit_en" 2>/dev/null || true
    fi
  done
  if [[ -f /etc/rclone/rclone.conf ]] && ! systemctl is-active --quiet rclone-gdrive-mount.service 2>/dev/null; then
    log_change "[CAMBIO] Iniciando rclone-gdrive-mount.service para FUSE Cloud..."
    CHANGES=$((CHANGES + 1))
    systemctl start rclone-gdrive-mount.service 2>/dev/null || true
  fi
  udevadm control --reload-rules 2>/dev/null || true
fi

echo ""
echo "=========================================================================="
if [[ "$DRY_RUN" == true ]]; then
  echo "Cambios previstos en capas 01-07: $CHANGES"
  log_ok "[✓] Simulación de convergencia de capas completada exitosamente."
else
  echo "Cambios aplicados en capas 01-07: $CHANGES"
  log_ok "[✓] Convergencia integral de la estación de trabajo completada exitosamente."
fi
echo "=========================================================================="

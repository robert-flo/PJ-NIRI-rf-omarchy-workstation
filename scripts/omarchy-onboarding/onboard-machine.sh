#!/usr/bin/env bash
# ==============================================================================
# onboard-machine.sh — Incorporación de máquinas al Fork Personal Omarchy
# ==============================================================================
# Procedimiento canónico multi-usuario para configurar máquinas de la flota
# conforme a: https://robert-flo.github.io/fork-docs/guide/02-onboarding-maquinas/
#
# Soporta:
#   - Modo PADRE (Estación de Desarrollo / Modo DEV / gracie)
#   - Modo HIJA (Máquinas Cliente / Producción)
#
# Principio innegociable:
#   Los repositorios compartidos de desarrollo se alojan exclusivamente en /z/
#   (nunca en $HOME) con permisos 2775 (setgid wheel) y ACLs para herencia.
# ==============================================================================

set -euo pipefail

KEY_ID="76AFFCC217DB9FC4"
FINGERPRINT="CD92AB07B1D24DC9A74EB60E76AFFCC217DB9FC4"
KEY_URL="https://robert-flo.github.io/omarchy-personal-repo/keys/omarchy-personal-repo.pub.asc"
LOCAL_KEY="/z/fork-docs/keys/omarchy-personal-repo.pub.asc"
REPO_URL_PAGES="https://robert-flo.github.io/omarchy-personal-repo/stable/\$arch"
REPO_URL_RELEASES="https://github.com/robert-flo/omarchy-personal-repo/releases/download/pkg-stable"
PACMAN_CONF="/etc/pacman.conf"
OMARCHY_REPO_URL="https://github.com/robert-flo/omarchy.git"
DEV_DIR="/z/fo-omarchy"

ROLE=""
DRY_RUN=false
EXTRA_USERS=()

# Identificar usuario invocador (no-root)
if [[ -n "${SUDO_USER:-}" ]]; then
  INVOKING_USER="$SUDO_USER"
else
  INVOKING_USER="$(id -un)"
fi

# ------------------------------------------------------------------------------
# Funciones auxiliares de log y visuales
# ------------------------------------------------------------------------------
log_info() { echo -e "\e[34m[INFO]\e[0m $*"; }
log_ok()   { echo -e "\e[32m[✓]\e[0m $*"; }
log_warn() { echo -e "\e[33m[AVISO]\e[0m $*"; }
log_err()  { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

show_help() {
  cat << 'EOF'
omarchy-onboard — Onboarding de máquinas en el Fork Personal de Omarchy

Uso:
  sudo omarchy-onboard [OPCIONES]

Opciones de Rol:
  --padre, --dev        Configura la máquina como Estación de Desarrollo (Modo DEV)
                        - Blinda pacman con IgnorePkg = omarchy-dev omarchy-settings-dev
                        - Despliega /z/fo-omarchy (rama personal) y ejecuta dev link
                        - Omite 'omarchy update' desatendido y provision forzado
  --hija, --client      Configura la máquina como Cliente de Producción (Modo Hija)
                        - Ejecuta ciclo de 7 pasos canónicos
                        - Actualiza paquetes sombreados (pkgrel=99+) con 'omarchy update'
                        - Materializa configs en $HOME con 'omarchy provision user --force'
                        - Reconcilia paquetes base del sistema con 'omarchy reinstall pkgs'

Opciones Adicionales:
  --users "<u1 u2...>"  Lista adicional de usuarios a aprovisionar en Modo Hija
  -n, --dry-run         Simulación: audita y muestra acciones sin modificar el sistema
  -h, --help            Muestra esta ayuda

Si no se especifica --padre o --hija, el asistente solicitará el rol de forma interactiva.
EOF
}

# ------------------------------------------------------------------------------
# Parseo de argumentos
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --padre|--dev)
      ROLE="padre"
      shift
      ;;
    --hija|--client|--hijas)
      ROLE="hija"
      shift
      ;;
    --users)
      IFS=' ' read -r -a EXTRA_USERS <<< "$2"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      log_err "Opción desconocida: $1"
      show_help
      exit 1
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Pregunta interactiva obligatoria si no se pasó flag
# ------------------------------------------------------------------------------
if [[ -z "$ROLE" ]]; then
  echo "=========================================================================="
  echo "         ONBOARDING DE MÁQUINA — ECOSISTEMA OMARCHY PERSONAL FORK         "
  echo "=========================================================================="
  echo "Cualquier computadora puede asumir rol PADRE o HIJA independientemente del"
  echo "nombre de usuario configurado en ella."
  echo ""
  echo "Selecciona el rol que tendrá este equipo en la flota:"
  echo ""
  echo "  1) PADRE (Estación de Desarrollo / Modo DEV)"
  echo "     - No corre 'omarchy update' ciego (protege código local)"
  echo "     - Blinda pacman con IgnorePkg = omarchy-dev omarchy-settings-dev"
  echo "     - Aloja fo-omarchy en /z/fo-omarchy (2775 wheel) y corre 'dev link'"
  echo "     - Habilita repositorio [omarchy-personal] firmado"
  echo ""
  echo "  2) HIJA (Máquina Cliente / Producción)"
  echo "     - Ejecuta los 7 pasos canónicos completos de fork-docs"
  echo "     - Actualiza a paquetes sombreados (pkgrel=99+) con 'omarchy update'"
  echo "     - Materializa launchers y stubs con 'omarchy provision user --force'"
  echo "     - Reconcilia paquetes base ('omarchy reinstall pkgs') y espacios Herdr"
  echo ""
  echo "=========================================================================="

  while true; do
    read -rp "Ingresa tu opción [1 para Padre, 2 para Hija]: " choice
    case "$choice" in
      1)
        ROLE="padre"
        break
        ;;
      2)
        ROLE="hija"
        break
        ;;
      *)
        echo "Opción no válida. Por favor ingresa 1 o 2."
        ;;
    esac
  done
fi

echo ""
log_info "Iniciando Onboarding en Modo: \e[1;35m${ROLE^^}\e[0m (Dry-run: $DRY_RUN)"

# ------------------------------------------------------------------------------
# Validaciones de permisos
# ------------------------------------------------------------------------------
if [[ "$DRY_RUN" == false && $EUID -ne 0 ]]; then
  log_err "Este script requiere privilegios administrativos (ejecutar con sudo)."
  exit 1
fi

# ------------------------------------------------------------------------------
# ETAPA 1: Pasos Comunes (GPG, Repositorio Pacman y Sincronización)
# ------------------------------------------------------------------------------
echo ""
log_info "=== [Etapa 1/3] Configuración Criptográfica y Pacman ==="

# 1.1 Llavero GPG
if pacman-key --list-keys "$KEY_ID" &>/dev/null; then
  log_ok "Clave GPG personal ($KEY_ID) ya confiada en el sistema."
else
  log_info "Importando clave pública GPG ($KEY_ID)..."
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] pacman-key --add (clave GPG) y pacman-key --lsign-key $KEY_ID"
  else
    if [[ -f "$LOCAL_KEY" ]]; then
      pacman-key --add "$LOCAL_KEY"
    else
      TMP_KEY="$(mktemp /tmp/omarchy-key.XXXXXX.asc)"
      curl -fsSL "$KEY_URL" -o "$TMP_KEY"
      pacman-key --add "$TMP_KEY"
      rm -f "$TMP_KEY"
    fi
    pacman-key --lsign-key "$KEY_ID"
    log_ok "Clave GPG $KEY_ID firmada y confiada localmente."
  fi
fi

# 1.2 Sección [omarchy-personal] en /etc/pacman.conf
if grep -q "\[omarchy-personal\]" "$PACMAN_CONF"; then
  log_ok "Sección [omarchy-personal] ya configurada en $PACMAN_CONF."
  # Asegurar fallback de Releases si falta
  if ! grep -q "releases/download/pkg-stable" "$PACMAN_CONF"; then
    log_info "Añadiendo fallback a GitHub Releases para paquetes > 100MB..."
    if [[ "$DRY_RUN" == false ]]; then
      sed -i "/https:\/\/robert-flo.github.io\/omarchy-personal-repo\/stable\/\$arch/a Server = $REPO_URL_RELEASES" "$PACMAN_CONF"
      log_ok "Fallback pkg-stable añadido."
    fi
  fi
else
  log_info "Inyectando [omarchy-personal] en $PACMAN_CONF antes de [omarchy]..."
  REPO_BLOCK="[omarchy-personal]\nSigLevel = Required DatabaseOptional\nServer = ${REPO_URL_PAGES}\nServer = ${REPO_URL_RELEASES}\n"
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Insertar bloque [omarchy-personal] con doble Server antes de [omarchy]"
  else
    if grep -q '^\[omarchy\]' "$PACMAN_CONF"; then
      sed -i "/^\[omarchy\]/i ${REPO_BLOCK}" "$PACMAN_CONF"
    else
      sed -i "/^\[core\]/i ${REPO_BLOCK}" "$PACMAN_CONF"
    fi
    log_ok "[omarchy-personal] inyectado exitosamente."
  fi
fi

# 1.3 Sincronización de bases de datos
log_info "Sincronizando bases de datos de pacman (pacman -Sy)..."
if [[ "$DRY_RUN" == true ]]; then
  log_info "[DRY-RUN] pacman -Sy"
else
  pacman -Sy
  log_ok "Bases de datos sincronizadas con éxito."
fi

# ------------------------------------------------------------------------------
# ETAPA 2: Bifurcación según el Rol (PADRE DEV vs HIJA CLIENTE)
# ------------------------------------------------------------------------------
if [[ "$ROLE" == "padre" ]]; then
  echo ""
  log_info "=== [Etapa 2/3] Configuración de Estación de Desarrollo (Modo PADRE) ==="

  # 2.1 Blindaje contra actualizaciones oficiales (IgnorePkg)
  if grep -q "IgnorePkg.*omarchy-dev" "$PACMAN_CONF"; then
    log_ok "Blindaje IgnorePkg ya presente en $PACMAN_CONF."
  else
    log_info "Inyectando IgnorePkg = omarchy-dev omarchy-settings-dev en $PACMAN_CONF..."
    if [[ "$DRY_RUN" == false ]]; then
      if grep -q "^HoldPkg =" "$PACMAN_CONF"; then
        sed -i '/^HoldPkg =/a IgnorePkg = omarchy-dev omarchy-settings-dev' "$PACMAN_CONF"
      else
        sed -i '/^\[options\]/a IgnorePkg = omarchy-dev omarchy-settings-dev' "$PACMAN_CONF"
      fi
      log_ok "Blindaje de desarrollo aplicado."
    fi
  fi

  # 2.2 Despliegue del código fuente en /z/fo-omarchy (NUNCA en $HOME)
  echo ""
  log_info "Verificando repositorio fuente compartido en $DEV_DIR..."
  if [[ -d "$DEV_DIR/.git" ]]; then
    log_ok "Repositorio fuente $DEV_DIR ya existe."
  else
    log_info "Clonando repositorio fuente en $DEV_DIR (rama personal)..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY-RUN] git clone -b personal $OMARCHY_REPO_URL $DEV_DIR con permisos 2775 wheel"
    else
      mkdir -p /z
      git clone -b personal "$OMARCHY_REPO_URL" "$DEV_DIR"
      chown -R "$INVOKING_USER:wheel" "$DEV_DIR"
      chmod -R 2775 "$DEV_DIR"
      find "$DEV_DIR" -type d -exec chmod g+s {} +
      setfacl -R -m g:wheel:rwx "$DEV_DIR"
      setfacl -R -d -m g:wheel:rwx "$DEV_DIR"
      git -C "$DEV_DIR" config core.fileMode false
      git config --system --add safe.directory "$DEV_DIR"
      log_ok "Repositorio clonado y asegurado con permisos multi-usuario en $DEV_DIR."
    fi
  fi

  # 2.3 Activar Modo Live con omarchy dev link
  log_info "Activando Modo Live de desarrollo apuntando a $DEV_DIR..."
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] omarchy dev link $DEV_DIR"
  else
    if command -v omarchy >/dev/null 2>&1; then
      # dev link debe ejecutarse como el usuario normal, no como root directo
      if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        sudo -u "$SUDO_USER" omarchy dev link "$DEV_DIR" || true
      else
        omarchy dev link "$DEV_DIR" || true
      fi
      log_ok "Modo Live configurado hacia $DEV_DIR."
    else
      log_warn "Comando 'omarchy' no encontrado aún en PATH. Ejecuta 'omarchy dev link $DEV_DIR' tras instalarlo."
    fi
  fi

  # 2.4 Advertencia de protección
  log_ok "PROTECCIÓN DEV ACTIVA: Se omite 'omarchy update' desatendido y provision forzado."
  log_info "Para probar cambios en vivo: edita en $DEV_DIR y ejecuta 'omarchy refresh <componente>'."
  log_info "Para compilar paquetes locales de prueba: 'omarchy dev pkg-test'."

else
  echo ""
  log_info "=== [Etapa 2/3] Configuración de Máquina Cliente (Modo HIJA) ==="

  # 2.1 Actualización con omarchy update
  log_info "Ejecutando actualización de distribución (omarchy update)..."
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] omarchy update"
  else
    if command -v omarchy >/dev/null 2>&1; then
      omarchy update
      log_ok "omarchy update completado."
    else
      log_info "Instalando paquetes sombreados iniciales con pacman..."
      pacman -S --needed --noconfirm omarchy omarchy-settings
      log_ok "Paquetes base instalados."
    fi
  fi

  # 2.2 Materializar configuraciones y launchers en $HOME de los usuarios
  ALL_TARGET_USERS=("$INVOKING_USER")
  for u in "${EXTRA_USERS[@]}"; do
    if id "$u" &>/dev/null; then
      ALL_TARGET_USERS+=("$u")
    else
      log_warn "Usuario especificado '$u' no existe en el sistema. Omitiendo."
    fi
  done

  # Eliminar duplicados
  UNIQUE_USERS=($(printf "%s\n" "${ALL_TARGET_USERS[@]}" | sort -u))

  for target_u in "${UNIQUE_USERS[@]}"; do
    log_info "Aprovisionando entorno para usuario '$target_u' (omarchy provision user --force)..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY-RUN] sudo -u $target_u omarchy provision user --force"
    else
      if command -v omarchy >/dev/null 2>&1; then
        sudo -u "$target_u" omarchy provision user --force || log_warn "Aviso al provisionar $target_u."
        log_ok "Entorno materializado para $target_u."
      fi
    fi
  done

  # 2.3 Reconciliación de paquetes y espacios Herdr
  log_info "Reconciliando paquetes base declarados (omarchy reinstall pkgs)..."
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] omarchy reinstall pkgs && sudo -u $INVOKING_USER omarchy refresh herdr"
  else
    if command -v omarchy >/dev/null 2>&1; then
      omarchy reinstall pkgs || true
      sudo -u "$INVOKING_USER" omarchy refresh herdr 2>/dev/null || true
      log_ok "Paquetes y espacios sincronizados."
    fi
  fi
fi

# ------------------------------------------------------------------------------
# ETAPA 3: Verificación Final del Sistema
# ------------------------------------------------------------------------------
echo ""
log_info "=== [Etapa 3/3] Verificación del Estado del Sistema ==="
if [[ "$DRY_RUN" == false ]]; then
  echo "--- Versión de Paquetes Omarchy ---"
  pacman -Q omarchy omarchy-settings 2>/dev/null || true

  echo ""
  echo "--- Repositorio [omarchy-personal] ---"
  pacman -Sl omarchy-personal 2>/dev/null || true

  if [[ "$ROLE" == "padre" ]]; then
    echo ""
    echo "--- Estado de Desarrollo (omarchy dev status) ---"
    omarchy dev status 2>/dev/null || echo "omarchy dev status no disponible aún"
  fi
fi

echo ""
echo "=========================================================================="
log_ok "Onboarding completado exitosamente en Modo: ${ROLE^^}."
echo "=========================================================================="
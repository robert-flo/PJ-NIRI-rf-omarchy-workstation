#!/usr/bin/env bash
# ==============================================================================
# onboard-machine.sh — Incorporación de máquinas al Fork Personal Omarchy
# ==============================================================================
# Fuente única de verdad de la lógica de onboarding de máquinas en la flota.
# El empaquetado formal del comando se aborda en los tickets #18-#20.
#
# No lo enlaces a mano en /usr/local/bin: el comando global llegará como
# paquete ravn- (tickets #18-#20). Mientras tanto, ejecútalo desde el repo.
# (Ver documentación en scripts/omarchy-onboarding/README.md)
#
# Procedimiento canónico multi-usuario para configurar máquinas de la flota
# conforme a: https://robert-flo.github.io/fork-docs/guide/02-onboarding-maquinas/
#
# Soporta:
#   - Modo PADRE (Estación de Desarrollo / Modo DEV / omarchy)
#   - Modo HIJA (Máquinas Cliente / Producción)
#
# Principio innegociable:
#   Los repositorios compartidos de desarrollo se alojan exclusivamente en /z/
#   con permisos 2775 (setgid wheel) y ACLs para herencia multiusuario.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuración y Variables Globales (con soporte para testing / contenedores)
# ------------------------------------------------------------------------------
# Clave de firma del repo pacman personal (ADR 0002 de omarchy-personal-repo,
# ADR-012 de fork-docs). NO es la clave oficial de Omarchy.
KEY_ID="E954119B629B58F6"
FINGERPRINT="14EDEAC8B295BB30CA6249A9E954119B629B58F6"
# Clave retirada (ADR-012): se elimina del llavero si sigue presente.
OLD_KEY_ID="76AFFCC217DB9FC4"
OLD_FINGERPRINT="CD92AB07B1D24DC9A74EB60E76AFFCC217DB9FC4"
KEY_URL="https://robert-flo.github.io/omarchy-personal-repo/keys/omarchy-personal-repo.pub.asc"
ONBOARD_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
VENDORED_KEY="${ONBOARD_SCRIPT_DIR}/../../assets/keys/omarchy-personal-repo.pub.asc"
META_REPO_URL="https://github.com/robert-flo/pj-omarchy.git"

ZROOT="${ZROOT:-/z}"
WORKSPACE_DIR="${OMARCHY_WORKSPACE_DIR:-${ZROOT}/pj-omarchy}"
DEV_DIR="${DEV_DIR:-${ZROOT}/fo-omarchy}"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"
PACMAN_D="${PACMAN_D:-/etc/pacman.d}"

ROLE=""
DRY_RUN=false
CHANGES=0
PACMAN_CONFIG_CHANGED=false
EXTRA_USERS=()
CLEANUP_FILES=()

# Identificar usuario invocador (no-root) y su $HOME
if [[ $EUID -ne 0 ]]; then
  INVOKING_USER="$(id -un)"
elif [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  INVOKING_USER="$SUDO_USER"
else
  INVOKING_USER="$(id -un)"
fi

USER_HOME="$(getent passwd "$INVOKING_USER" 2>/dev/null | cut -d: -f6 || true)"
if [[ -z "$USER_HOME" ]]; then
  USER_HOME="${HOME:-/home/$INVOKING_USER}"
fi

# ------------------------------------------------------------------------------
# Limpieza de temporales al salir
# ------------------------------------------------------------------------------
cleanup() {
  for item in "${CLEANUP_FILES[@]}"; do
    rm -rf "$item" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# Funciones auxiliares de log y ejecución controlada
# ------------------------------------------------------------------------------
log_info() {
  if [[ -t 1 ]]; then
    echo -e "\e[34m[INFO]\e[0m $*"
  else
    echo "[INFO] $*"
  fi
}

log_ok() {
  local msg="$*"
  if [[ "$msg" =~ ^\[✓\][[:space:]]* ]]; then
    msg="${msg#\[✓\] }"
  fi
  if [[ -t 1 ]]; then
    echo -e "\e[32m[✓]\e[0m $msg"
  else
    echo "[✓] $msg"
  fi
}

log_change() {
  local msg="$*"
  if [[ "$msg" =~ ^\[CAMBIO\][[:space:]]* ]]; then
    msg="${msg#\[CAMBIO\] }"
  fi
  if [[ -t 1 ]]; then
    echo -e "\e[33m[CAMBIO]\e[0m $msg"
  else
    echo "[CAMBIO] $msg"
  fi
}

log_err() {
  if [[ -t 2 ]]; then
    echo -e "\e[31m[ERROR]\e[0m $*" >&2
  else
    echo "[ERROR] $*" >&2
  fi
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

show_help() {
  cat << 'EOF'
omarchy-onboard — Onboarding de máquinas en el Fork Personal de Omarchy

Uso:
  sudo omarchy-onboard [OPCIONES]

Opciones de Rol:
  --padre, --dev        Configura la máquina como Estación de Desarrollo (Modo PADRE / DEV)
                        - Blinda pacman con IgnorePkg = omarchy-dev omarchy-settings-dev
                        - Despliega /z/pj-omarchy y activa Modo Live con 'omarchy dev link /z/fo-omarchy'
                        - PADRE no corre 'omarchy update': el par -dev viene de /z/fo-omarchy vía
                          'omarchy dev link' y un update desatendido pisaría el código en vivo;
                          actualizá a mano con 'omarchy update' cuando el árbol esté limpio.
  --hija, --client,     Configura la máquina como Cliente de Producción (Modo HIJA)
  --hijas               - Ejecuta ciclo canónico de actualización e instalación
                        - Actualiza paquetes sombreados (pkgrel=99+) con 'omarchy update'
                        - Materializa configs en $HOME con 'omarchy provision user --force'
                        - Reconcilia paquetes base del sistema con 'omarchy reinstall pkgs'

Opciones Adicionales:
  --users "<u1 u2...>"  Lista adicional de usuarios a verificar/aprovisionar
                        - En PADRE: verifica existencia y pertenencia al grupo wheel
                        - En HIJA: aprovisiona el entorno de cada usuario con omarchy provision
  -n, --dry-run         Simulación: audita y muestra acciones sin modificar el sistema
  -h, --help            Muestra esta ayuda

Variables de Entorno Opcionales:
  ZROOT                 Directorio raíz compartido (default: /z)
  OMARCHY_WORKSPACE_DIR Directorio del meta-workspace (default: $ZROOT/pj-omarchy)
  PACMAN_CONF           Ruta a pacman.conf (default: /etc/pacman.conf)
  PACMAN_D              Ruta a pacman.d (default: /etc/pacman.d)

Si no se especifica --padre o --hija, el asistente solicitará el rol de forma interactiva.
EOF
}

# ------------------------------------------------------------------------------
# Generador del contenido del hook pre-refresh de pacman
# ------------------------------------------------------------------------------
generate_hook_content() {
  cat << 'EOF'
#!/usr/bin/env bash
# TEMPORAL hasta robert-flo/omarchy#82; dueño de pacman.conf: omarchy refresh pacman
set -euo pipefail

PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"
PACMAN_D="${PACMAN_D:-/etc/pacman.d}"
DEV_FLAG="${PACMAN_D}/omarchy-personal-dev.flag"
DROPIN_PATH="${PACMAN_D}/omarchy-personal.conf"

if [[ ! -f "$PACMAN_CONF" ]]; then
  echo "Error: no se encontró $PACMAN_CONF" >&2
  exit 1
fi

TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/pacman.conf.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

cp "$PACMAN_CONF" "$TMP_FILE"

# (1) Si tiene una sección inline [omarchy-personal] (legada, no Include), eliminarla:
if grep -qE '^[[:space:]]*\[omarchy-personal\]' "$TMP_FILE"; then
  awk '
    BEGIN { skipping = 0 }
    /^[[:space:]]*\[omarchy-personal\]/ { skipping = 1; next }
    skipping && /^[[:space:]]*\[/ { skipping = 0 }
    skipping && /^[[:space:]]*$/ { skipping = 0; next }
    !skipping { print }
  ' "$TMP_FILE" > "${TMP_FILE}.migrated"
  mv "${TMP_FILE}.migrated" "$TMP_FILE"
fi

# (2) Asegurar "Include = /etc/pacman.d/omarchy-personal.conf" justo antes de ^\[omarchy\] o ^\[core\]
INCLUDE_LINE="Include = ${DROPIN_PATH}"
if ! grep -qF "$INCLUDE_LINE" "$TMP_FILE"; then
  if grep -q '^[[:space:]]*\[omarchy\]' "$TMP_FILE"; then
    awk -v inc="$INCLUDE_LINE" '
      !inserted && /^[[:space:]]*\[omarchy\]/ { print inc; inserted = 1 }
      { print }
    ' "$TMP_FILE" > "${TMP_FILE}.inc"
    mv "${TMP_FILE}.inc" "$TMP_FILE"
  elif grep -q '^[[:space:]]*\[core\]' "$TMP_FILE"; then
    awk -v inc="$INCLUDE_LINE" '
      !inserted && /^[[:space:]]*\[core\]/ { print inc; inserted = 1 }
      { print }
    ' "$TMP_FILE" > "${TMP_FILE}.inc"
    mv "${TMP_FILE}.inc" "$TMP_FILE"
  else
    echo "$INCLUDE_LINE" >> "$TMP_FILE"
  fi
fi

# (3) Si existe el flag de dev (PADRE), asegurar IgnorePkg = omarchy-dev omarchy-settings-dev tras ^\[options\]
if [[ -f "$DEV_FLAG" ]]; then
  if ! grep -qE '^[[:space:]]*IgnorePkg.*omarchy-dev' "$TMP_FILE"; then
    awk '
      { print }
      !inserted && /^[[:space:]]*\[options\]/ {
        print "IgnorePkg = omarchy-dev omarchy-settings-dev"
        inserted = 1
      }
    ' "$TMP_FILE" > "${TMP_FILE}.ign"
    mv "${TMP_FILE}.ign" "$TMP_FILE"
  fi
fi

if ! cmp -s "$TMP_FILE" "$PACMAN_CONF"; then
  if [[ $EUID -ne 0 && ! -w "$PACMAN_CONF" ]]; then
    sudo install -m 644 "$TMP_FILE" "$PACMAN_CONF"
  else
    install -m 644 "$TMP_FILE" "$PACMAN_CONF"
  fi
fi
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
      if [[ $# -lt 2 || -z "${2:-}" || "$2" == -* ]]; then
        log_err "La opción --users requiere una lista no vacía de usuarios (ej. --users \"u1 u2\")."
        exit 2
      fi
      read -r -a EXTRA_USERS <<< "$2"
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
# Pregunta interactiva obligatoria si no se pasó flag de rol
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
  echo "     - PADRE no corre 'omarchy update': el par -dev viene de /z/fo-omarchy"
  echo "       vía 'omarchy dev link' y un update desatendido pisaría el código en vivo;"
  echo "       actualizá a mano con 'omarchy update' cuando el árbol esté limpio."
  echo "     - Blinda pacman con IgnorePkg = omarchy-dev omarchy-settings-dev"
  echo "     - Aloja workspace unificado en /z/pj-omarchy (2775 wheel) y corre 'dev link'"
  echo "     - Habilita repositorio [omarchy-personal] firmado"
  echo ""
  echo "  2) HIJA (Máquina Cliente / Producción)"
  echo "     - Ejecuta los pasos canónicos completos de fork-docs"
  echo "     - Actualiza a paquetes sombreados (pkgrel=99+) con 'omarchy update'"
  echo "     - Materializa launchers y configs con 'omarchy provision user --force'"
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
# Deduplicación y validación de usuarios
# ------------------------------------------------------------------------------
ALL=("$INVOKING_USER" "${EXTRA_USERS[@]}")
mapfile -t UNIQUE_USERS < <(printf '%s\n' "${ALL[@]}" | sort -u)

for u in "${UNIQUE_USERS[@]}"; do
  if ! id "$u" >/dev/null 2>&1; then
    log_err "El usuario '$u' no existe en el sistema."
    exit 1
  fi
  if [[ "$ROLE" == "padre" ]]; then
    if ! id -nG "$u" | tr ' ' '\n' | grep -qxF "wheel"; then
      log_err "En modo PADRE, el usuario '$u' debe pertenecer al grupo 'wheel'."
      exit 1
    fi
    log_ok "[✓] ya el usuario '$u' existe y pertenece al grupo wheel."
  fi
done

# ------------------------------------------------------------------------------
# Validaciones de permisos
# ------------------------------------------------------------------------------
if [[ "$DRY_RUN" == false && $EUID -ne 0 ]]; then
  log_err "Este script requiere privilegios administrativos (ejecutar con sudo)."
  exit 1
fi

# ------------------------------------------------------------------------------
# ETAPA 1: Pasos Comunes (Paquetes base, /z, GPG, Drop-in pacman y Hook)
# ------------------------------------------------------------------------------
echo ""
log_info "=== [Etapa 1/3] Configuración Criptográfica, Almacenamiento y Pacman ==="

# 1.1 Asegurar paquetes base del sistema (acl y git)
if pacman -Q acl git >/dev/null 2>&1; then
  log_ok "[✓] ya los paquetes base acl y git están instalados."
else
  log_change "[CAMBIO] Instalando paquetes requeridos: acl git..."
  CHANGES=$((CHANGES + 1))
  run pacman -S --needed --noconfirm acl git
fi

# 1.2 Asegurar directorio raíz compartido ($ZROOT)
if [[ ! -d "$ZROOT" ]]; then
  log_change "[CAMBIO] Creando directorio raíz compartido $ZROOT..."
  CHANGES=$((CHANGES + 1))
  run mkdir -p "$ZROOT"
  run chown root:wheel "$ZROOT"
  run chmod 2775 "$ZROOT"
  run setfacl -m g:wheel:rwx "$ZROOT"
  run setfacl -d -m g:wheel:rwx "$ZROOT"
else
  z_owner="$(stat -c '%U:%G' "$ZROOT" 2>/dev/null || true)"
  if [[ "$z_owner" != "root:wheel" ]]; then
    log_change "[CAMBIO] Asignando propietario root:wheel a $ZROOT (actual: $z_owner)..."
    CHANGES=$((CHANGES + 1))
    run chown root:wheel "$ZROOT"
  else
    log_ok "[✓] ya el propietario de $ZROOT es root:wheel."
  fi

  z_mode="$(stat -c '%a' "$ZROOT" 2>/dev/null || true)"
  if [[ "$z_mode" == "2770" || "$z_mode" == "2775" ]]; then
    log_ok "[✓] ya los permisos de $ZROOT son válidos ($z_mode)."
  else
    log_change "[CAMBIO] Ajustando permisos de $ZROOT a 2775 (actual: $z_mode)..."
    CHANGES=$((CHANGES + 1))
    run chmod 2775 "$ZROOT"
  fi

  z_acls="$(getfacl -p "$ZROOT" 2>/dev/null || true)"
  need_z_acl=false
  if ! echo "$z_acls" | grep -q '^group:wheel:rwx'; then
    need_z_acl=true
  fi
  if ! echo "$z_acls" | grep -q '^default:group:wheel:rwx'; then
    need_z_acl=true
  fi

  if [[ "$need_z_acl" == true ]]; then
    log_change "[CAMBIO] Configurando ACLs requeridas (group:wheel:rwx y default) en $ZROOT..."
    CHANGES=$((CHANGES + 1))
    run setfacl -m g:wheel:rwx "$ZROOT"
    run setfacl -d -m g:wheel:rwx "$ZROOT"
  else
    log_ok "[✓] ya las ACLs de $ZROOT están configuradas correctamente."
  fi
fi

# 1.3 Llavero GPG
# Huella de un fichero .asc (vacío si no es legible).
key_file_fpr() {
  gpg --show-keys --with-colons --with-fingerprint "$1" 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}'
}

if pacman-key --list-keys "$KEY_ID" >/dev/null 2>&1; then
  existing_fpr="$(pacman-key --finger "$KEY_ID" 2>/dev/null | tr -d '[:space:]')"
  if [[ "$existing_fpr" != *"$FINGERPRINT"* ]]; then
    log_err "La clave GPG $KEY_ID en el llavero no coincide con la huella esperada $FINGERPRINT."
    exit 1
  fi
  log_ok "[✓] ya la clave GPG personal ($KEY_ID) está confiada con huella correcta."
else
  key_source=""
  # Candidatos locales en orden; se descartan los que no tengan la huella vigente
  # (p. ej. copias viejas con la clave retirada).
  for cand in "$VENDORED_KEY" \
              "$WORKSPACE_DIR/rf-fork-docs/keys/omarchy-personal-repo.pub.asc" \
              "${ZROOT}/fork-docs/keys/omarchy-personal-repo.pub.asc"; do
    if [[ -f "$cand" && "$(key_file_fpr "$cand")" == "$FINGERPRINT" ]]; then
      key_source="$cand"
      break
    fi
  done

  if [[ -z "$key_source" && "$DRY_RUN" == false ]]; then
    key_source="$(mktemp "${TMPDIR:-/tmp}/omarchy-key.XXXXXX.asc")"
    CLEANUP_FILES+=("$key_source")
    curl -fsSL "$KEY_URL" -o "$key_source"
  fi

  if [[ -n "$key_source" ]]; then
    extracted_fpr="$(key_file_fpr "$key_source")"
    if [[ "$extracted_fpr" != "$FINGERPRINT" ]]; then
      log_err "Huella de clave GPG inválida en $key_source: $extracted_fpr (esperada: $FINGERPRINT)."
      exit 1
    fi
    log_change "[CAMBIO] Añadiendo y firmando clave GPG personal ($KEY_ID)..."
    CHANGES=$((CHANGES + 1))
    run pacman-key --add "$key_source"
    run pacman-key --lsign-key "$FINGERPRINT"
  else
    # Simulación en caso de clave no presente en disco
    log_change "[CAMBIO] Se obtendría la clave GPG desde $KEY_URL y se firmaría con pacman-key --lsign-key $FINGERPRINT"
    CHANGES=$((CHANGES + 1))
    run pacman-key --add "$KEY_URL"
    run pacman-key --lsign-key "$FINGERPRINT"
  fi
fi

# 1.3b Retirar la clave vieja (ADR-012) si sigue en el llavero
if pacman-key --list-keys "$OLD_FINGERPRINT" >/dev/null 2>&1; then
  log_change "[CAMBIO] Eliminando del llavero la clave retirada ($OLD_KEY_ID)..."
  CHANGES=$((CHANGES + 1))
  run pacman-key --delete "$OLD_FINGERPRINT"
else
  log_ok "[✓] ya la clave retirada ($OLD_KEY_ID) no está en el llavero."
fi

# 1.4 Drop-in /etc/pacman.d/omarchy-personal.conf
DROPIN_TARGET="${PACMAN_D}/omarchy-personal.conf"
TMP_DROPIN="$(mktemp "${TMPDIR:-/tmp}/omarchy-personal.conf.XXXXXX")"
CLEANUP_FILES+=("$TMP_DROPIN")

cat << 'EOF' > "$TMP_DROPIN"
[omarchy-personal]
SigLevel = Required DatabaseOptional
Server = https://robert-flo.github.io/omarchy-personal-repo/stable/$arch
Server = https://github.com/robert-flo/omarchy-personal-repo/releases/download/pkg-stable
EOF

if [[ -f "$DROPIN_TARGET" ]] && cmp -s "$TMP_DROPIN" "$DROPIN_TARGET"; then
  log_ok "[✓] ya el drop-in $DROPIN_TARGET está actualizado."
else
  log_change "[CAMBIO] Instalando drop-in de pacman en $DROPIN_TARGET..."
  CHANGES=$((CHANGES + 1))
  PACMAN_CONFIG_CHANGED=true
  if [[ "$DRY_RUN" == true ]]; then
    run install -m 644 "$TMP_DROPIN" "$DROPIN_TARGET"
  else
    mkdir -p "$PACMAN_D"
    install -m 644 "$TMP_DROPIN" "$DROPIN_TARGET"
  fi
fi

# 1.5 Flag file de desarrollo /etc/pacman.d/omarchy-personal-dev.flag
DEV_FLAG="${PACMAN_D}/omarchy-personal-dev.flag"
if [[ "$ROLE" == "padre" ]]; then
  if [[ -f "$DEV_FLAG" ]]; then
    log_ok "[✓] ya el flag de desarrollo $DEV_FLAG está presente."
  else
    log_change "[CAMBIO] Creando flag de desarrollo $DEV_FLAG..."
    CHANGES=$((CHANGES + 1))
    PACMAN_CONFIG_CHANGED=true
    if [[ "$DRY_RUN" == true ]]; then
      run touch "$DEV_FLAG"
    else
      mkdir -p "$PACMAN_D"
      touch "$DEV_FLAG"
    fi
  fi
else
  if [[ -f "$DEV_FLAG" ]]; then
    log_change "[CAMBIO] Eliminando flag de desarrollo $DEV_FLAG (Modo HIJA)..."
    CHANGES=$((CHANGES + 1))
    PACMAN_CONFIG_CHANGED=true
    run rm -f "$DEV_FLAG"
  else
    log_ok "[✓] ya el flag de desarrollo $DEV_FLAG no está presente."
  fi
fi

# 1.6 Hook de pacman en ~INVOKING_USER/.config/omarchy/hooks/pre-refresh-pacman.d/10-omarchy-personal
HOOK_DIR="$USER_HOME/.config/omarchy/hooks/pre-refresh-pacman.d"
HOOK_FILE="$HOOK_DIR/10-omarchy-personal"
TMP_HOOK_CONTENT="$(mktemp "${TMPDIR:-/tmp}/10-omarchy-personal.XXXXXX")"
CLEANUP_FILES+=("$TMP_HOOK_CONTENT")

generate_hook_content > "$TMP_HOOK_CONTENT"
chmod +x "$TMP_HOOK_CONTENT"

if [[ -f "$HOOK_FILE" ]] && cmp -s "$TMP_HOOK_CONTENT" "$HOOK_FILE"; then
  log_ok "[✓] ya el hook pre-refresh $HOOK_FILE está actualizado."
else
  log_change "[CAMBIO] Instalando hook pre-refresh en $HOOK_FILE..."
  CHANGES=$((CHANGES + 1))
  if [[ "$DRY_RUN" == true ]]; then
    run install -m 0755 -o "$INVOKING_USER" "$TMP_HOOK_CONTENT" "$HOOK_FILE"
  else
    mkdir -p "$HOOK_DIR"
    chown "$INVOKING_USER:$(id -gn "$INVOKING_USER")" "$HOOK_DIR"
    install -m 0755 -o "$INVOKING_USER" -g "$(id -gn "$INVOKING_USER")" "$TMP_HOOK_CONTENT" "$HOOK_FILE"
  fi
fi

# 1.7 Converger pacman.conf ejecutando el hook
log_info "Convergencia de $PACMAN_CONF mediante hook pre-refresh..."
if [[ "$DRY_RUN" == true ]]; then
  TMP_PC="$(mktemp "${TMPDIR:-/tmp}/pacman.conf.dryrun.XXXXXX")"
  TMP_PD="$(mktemp -d "${TMPDIR:-/tmp}/pacman.d.dryrun.XXXXXX")"
  TMP_H="$(mktemp "${TMPDIR:-/tmp}/hook.dryrun.XXXXXX")"
  CLEANUP_FILES+=("$TMP_PC" "$TMP_PD" "$TMP_H")

  cp "$PACMAN_CONF" "$TMP_PC"
  cp "$TMP_DROPIN" "$TMP_PD/omarchy-personal.conf"
  if [[ "$ROLE" == "padre" ]]; then
    touch "$TMP_PD/omarchy-personal-dev.flag"
  fi

  generate_hook_content > "$TMP_H"
  chmod +x "$TMP_H"

  PACMAN_CONF="$TMP_PC" PACMAN_D="$TMP_PD" bash "$TMP_H"

  if ! cmp -s "$PACMAN_CONF" "$TMP_PC"; then
    log_change "[CAMBIO] pacman.conf se modificaría según el hook pre-refresh:"
    diff -u --label "$PACMAN_CONF" --label "$TMP_PC" "$PACMAN_CONF" "$TMP_PC" || true
    CHANGES=$((CHANGES + 1))
    PACMAN_CONFIG_CHANGED=true
  else
    log_ok "[✓] ya pacman.conf está convergido con el hook pre-refresh."
  fi
else
  TMP_BEFORE_CONF="$(mktemp "${TMPDIR:-/tmp}/pacman.conf.before.XXXXXX")"
  CLEANUP_FILES+=("$TMP_BEFORE_CONF")
  cp "$PACMAN_CONF" "$TMP_BEFORE_CONF"

  bash "$HOOK_FILE"

  if ! cmp -s "$TMP_BEFORE_CONF" "$PACMAN_CONF"; then
    log_change "[CAMBIO] pacman.conf convergido exitosamente por el hook pre-refresh."
    CHANGES=$((CHANGES + 1))
    PACMAN_CONFIG_CHANGED=true
  else
    log_ok "[✓] ya pacman.conf estaba convergido."
  fi
fi

# 1.8 Sincronización de bases de datos de pacman
SYNC_DB="/var/lib/pacman/sync/omarchy-personal.db"
if [[ "$PACMAN_CONFIG_CHANGED" == true || ! -f "$SYNC_DB" ]]; then
  log_change "[CAMBIO] Sincronizando base de datos [omarchy-personal] con pacman -Sy..."
  CHANGES=$((CHANGES + 1))
  run pacman -Sy
else
  log_ok "[✓] ya el repositorio omarchy-personal y la base de datos de pacman están sincronizados."
fi

# ------------------------------------------------------------------------------
# ETAPA 2: Bifurcación según el Rol (PADRE DEV vs HIJA CLIENTE)
# ------------------------------------------------------------------------------
if [[ "$ROLE" == "padre" ]]; then
  echo ""
  log_info "=== [Etapa 2/3] Configuración de Estación de Desarrollo (Modo PADRE) ==="

  # 2.1 Justificación canónica de omarchy update
  log_info "PADRE no corre 'omarchy update': el par -dev viene de $DEV_DIR vía 'omarchy dev link' y un update desatendido pisaría el código en vivo; actualizá a mano con 'omarchy update' cuando el árbol esté limpio."

  # 2.2 Despliegue del meta-workspace en $WORKSPACE_DIR (NUNCA en $HOME)
  log_info "Verificando meta-workspace de la flota en $WORKSPACE_DIR..."
  is_fresh_clone=false
  if [[ ! -d "$WORKSPACE_DIR/.git" ]]; then
    is_fresh_clone=true
    log_change "[CAMBIO] Clonando meta-repositorio pj-omarchy en $WORKSPACE_DIR..."
    CHANGES=$((CHANGES + 1))
    if [[ ! -d "$ZROOT" ]]; then
      run mkdir -p "$ZROOT"
    fi
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
      run sudo -u "$SUDO_USER" git clone "$META_REPO_URL" "$WORKSPACE_DIR"
    else
      run git clone "$META_REPO_URL" "$WORKSPACE_DIR"
    fi
  else
    log_ok "[✓] ya el meta-workspace $WORKSPACE_DIR existe (se conserva sin pull para proteger cambios locales)."
  fi

  # 2.3 Alineación e inicialización de repositorios hijos
  log_info "Alineando repositorios hijos en $WORKSPACE_DIR..."
  if [[ "$is_fresh_clone" == true && ("$DRY_RUN" == true || -x "$WORKSPACE_DIR/pj") ]]; then
    log_change "[CAMBIO] Inicializando ecosistema pj en clon nuevo mediante './pj listo'..."
    CHANGES=$((CHANGES + 1))
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
      run sudo -u "$SUDO_USER" bash -c "cd '$WORKSPACE_DIR' && ./pj listo"
    else
      run bash -c "cd '$WORKSPACE_DIR' && ./pj listo"
    fi
  else
    # Fallback converge: parsear proyecto.yml con awk/sed sin dependencia de yq
    REPO_DIRS=()
    REPO_URLS=()
    REPO_RAMAS=()

    parse_proyecto_yml() {
      awk '
        BEGIN { in_repos = 0; dir = ""; repo = ""; rama = "" }
        /^[[:space:]]*repos:[[:space:]]*$/ { in_repos = 1; next }
        in_repos && /^[[:alnum:]_]+:/ { in_repos = 0 }
        in_repos {
          if (match($0, /^[[:space:]]*-[[:space:]]*dir:[[:space:]]*["'\'']?([^"'\'']+)["'\'']?/, m)) {
            if (dir != "") { print dir "\t" repo "\t" rama }
            dir = m[1]; repo = ""; rama = ""
          } else if (match($0, /^[[:space:]]*repo:[[:space:]]*["'\'']?([^"'\'']+)["'\'']?/, m)) {
            repo = m[1]
          } else if (match($0, /^[[:space:]]*rama:[[:space:]]*["'\'']?([^"'\'']+)["'\'']?/, m)) {
            rama = m[1]
          }
        }
        END {
          if (dir != "") { print dir "\t" repo "\t" rama }
        }
      '
    }

    if [[ -f "$WORKSPACE_DIR/proyecto.yml" ]]; then
      while IFS=$'\t' read -r d r b; do
        [[ -n "$d" ]] || continue
        REPO_DIRS+=("$d")
        REPO_URLS+=("$r")
        REPO_RAMAS+=("$b")
      done < <(parse_proyecto_yml < "$WORKSPACE_DIR/proyecto.yml")
    elif [[ -d "$WORKSPACE_DIR/.git" ]] && git -C "$WORKSPACE_DIR" rev-parse --verify origin/HEAD >/dev/null 2>&1; then
      while IFS=$'\t' read -r d r b; do
        [[ -n "$d" ]] || continue
        REPO_DIRS+=("$d")
        REPO_URLS+=("$r")
        REPO_RAMAS+=("$b")
      done < <(git -C "$WORKSPACE_DIR" show origin/HEAD:proyecto.yml 2>/dev/null | parse_proyecto_yml)
    fi

    if [[ ${#REPO_DIRS[@]} -gt 0 ]]; then
      for i in "${!REPO_DIRS[@]}"; do
        r_dir="${REPO_DIRS[$i]}"
        r_repo="${REPO_URLS[$i]}"
        r_rama="${REPO_RAMAS[$i]}"

        if [[ -d "$WORKSPACE_DIR/$r_dir/.git" ]]; then
          log_ok "[✓] ya el repositorio '$r_dir' ($r_repo) está presente."
        else
          log_change "[CAMBIO] Repositorio faltante: '$r_dir' ($r_repo -> rama $r_rama)..."
          CHANGES=$((CHANGES + 1))
          if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
            run sudo -u "$SUDO_USER" git clone -b "$r_rama" "https://github.com/${r_repo}.git" "$WORKSPACE_DIR/$r_dir"
          else
            run git clone -b "$r_rama" "https://github.com/${r_repo}.git" "$WORKSPACE_DIR/$r_dir"
          fi
        fi
      done
    elif [[ -x "$WORKSPACE_DIR/clone-repos.sh" ]]; then
      log_change "[CAMBIO] Ejecutando clone-repos.sh para alinear repositorios..."
      CHANGES=$((CHANGES + 1))
      if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        run sudo -u "$SUDO_USER" bash -c "cd '$WORKSPACE_DIR' && ./clone-repos.sh"
      else
        run bash -c "cd '$WORKSPACE_DIR' && ./clone-repos.sh"
      fi
    else
      if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Repositorios hijos no disponibles en simulación (no se encontraron ni proyecto.yml ni clone-repos.sh en $WORKSPACE_DIR)."
      else
        log_err "No se encontró ni proyecto.yml ni clone-repos.sh en $WORKSPACE_DIR."
        exit 1
      fi
    fi
  fi

  # 2.4 El .code-workspace es de pj-omarchy (versionado allí; ADR 0001 §3.3).
  # Workstation no lo crea ni lo modifica: solo verifica que exista.
  if [[ -f "$WORKSPACE_DIR/pj-omarchy.code-workspace" ]]; then
    log_ok "[✓] ya existe $WORKSPACE_DIR/pj-omarchy.code-workspace (dueño: pj-omarchy)."
  elif [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] $WORKSPACE_DIR/pj-omarchy.code-workspace no existe; se esperaría tras ./pj listo."
  else
    log_err "Falta $WORKSPACE_DIR/pj-omarchy.code-workspace. Es de pj-omarchy: actualizá ese repo (git pull). Workstation no lo crea; se continúa."
  fi

  # 2.5 Permisos y ACLs en $WORKSPACE_DIR (sólo si hay drift detectado)
  if [[ -d "$WORKSPACE_DIR" ]]; then
    drift_reason=""
    top_group="$(stat -c '%G' "$WORKSPACE_DIR" 2>/dev/null || true)"
    if [[ "$top_group" != "wheel" ]]; then
      drift_reason="grupo raíz no es wheel ($top_group)"
    elif ! [[ -g "$WORKSPACE_DIR" ]]; then
      drift_reason="setgid ausente en directorio raíz"
    elif ! getfacl -p "$WORKSPACE_DIR" 2>/dev/null | grep -q '^default:group:wheel:rwx'; then
      drift_reason="ACL default:group:wheel:rwx ausente en directorio raíz"
    else
      drift_file="$(find "$WORKSPACE_DIR" -not -group wheel -print -quit 2>/dev/null)"
      if [[ -n "$drift_file" ]]; then
        drift_reason="archivo o carpeta sin grupo wheel: $drift_file"
      else
        drift_dir="$(find "$WORKSPACE_DIR" -type d -not -perm -2000 -print -quit 2>/dev/null)"
        if [[ -n "$drift_dir" ]]; then
          drift_reason="directorio sin bit setgid: $drift_dir"
        fi
      fi
    fi

    if [[ -n "$drift_reason" ]]; then
      log_change "[CAMBIO] Reconciliando permisos y ACLs en $WORKSPACE_DIR ($drift_reason)..."
      CHANGES=$((CHANGES + 1))
      run chown -R "$INVOKING_USER:wheel" "$WORKSPACE_DIR"
      run find "$WORKSPACE_DIR" -type d -exec chmod g+rwxs {} +
      run find "$WORKSPACE_DIR" -type f -exec chmod g+rw {} +
      run setfacl -R -m g:wheel:rwx "$WORKSPACE_DIR"
      run setfacl -R -d -m g:wheel:rwx "$WORKSPACE_DIR"
    else
      log_ok "[✓] ya los permisos y ACLs en $WORKSPACE_DIR son correctos."
    fi

    # 2.6 core.fileMode false por sub-repositorio
    fm_changed=false
    while IFS= read -r gitdir; do
      [[ -n "$gitdir" ]] || continue
      val="$(git --git-dir="$gitdir" config --get core.fileMode 2>/dev/null || true)"
      if [[ "$val" != "false" ]]; then
        repo_sub="$(basename "$(dirname "$gitdir")")"
        log_change "[CAMBIO] Ajustando core.fileMode false en '$repo_sub'..."
        CHANGES=$((CHANGES + 1))
        fm_changed=true
        run git --git-dir="$gitdir" config core.fileMode false
      fi
    done < <(find "$WORKSPACE_DIR" -maxdepth 2 -name ".git" -type d 2>/dev/null)

    if [[ "$fm_changed" == false ]]; then
      log_ok "[✓] ya core.fileMode está en false en los repositorios del workspace."
    fi
  fi

  # 2.7 safe.directory en git config --system
  mapfile -t CURRENT_SAFE < <(git -C / config --system --get-all safe.directory 2>/dev/null || true)
  has_dups=false
  declare -A seen_safe=()
  for entry in "${CURRENT_SAFE[@]}"; do
    if [[ -n "${seen_safe["$entry"]:-}" ]]; then
      has_dups=true
      break
    fi
    seen_safe["$entry"]=1
  done

  if [[ "$has_dups" == true ]]; then
    log_change "[CAMBIO] Deduplicando entradas en git config --system safe.directory..."
    CHANGES=$((CHANGES + 1))
    run git -C / config --system --unset-all safe.directory
    declare -A seen_rewritten=()
    for entry in "${CURRENT_SAFE[@]}"; do
      if [[ -z "${seen_rewritten["$entry"]:-}" ]]; then
        seen_rewritten["$entry"]=1
        run git -C / config --system --add safe.directory "$entry"
      fi
    done
  else
    log_ok "[✓] ya git config --system safe.directory no contiene duplicados."
  fi

  for req_dir in "$WORKSPACE_DIR" "$WORKSPACE_DIR/*"; do
    if git -C / config --system --get-all safe.directory 2>/dev/null | grep -qxF "$req_dir"; then
      log_ok "[✓] ya git config --system safe.directory contiene '$req_dir'."
    else
      log_change "[CAMBIO] Añadiendo '$req_dir' a git config --system safe.directory..."
      CHANGES=$((CHANGES + 1))
      run git -C / config --system --add safe.directory "$req_dir"
    fi
  done

  # 2.8 Enlaces simbólicos en $ZROOT/
  SYMLINKS=(
    "${ZROOT}/fo-omarchy:$WORKSPACE_DIR/fo-omarchy"
    "${ZROOT}/fork-docs:$WORKSPACE_DIR/rf-fork-docs"
  )

  for pair in "${SYMLINKS[@]}"; do
    link_path="${pair%%:*}"
    target_path="${pair#*:}"

    if [[ ! -e "$target_path" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Destino del symlink '$target_path' no existe actualmente."
      else
        log_err "El destino del enlace simbólico '$target_path' no existe."
        exit 1
      fi
    fi

    if [[ -d "$link_path" && ! -L "$link_path" ]]; then
      log_err "La ruta '$link_path' es un directorio real y no un enlace simbólico. No se sobrescribirá para proteger datos."
      exit 1
    fi

    if [[ -L "$link_path" ]]; then
      cur_target="$(readlink "$link_path")"
      if [[ "$cur_target" == "$target_path" ]]; then
        log_ok "[✓] ya el symlink $link_path apunta correctamente a $target_path."
      else
        log_change "[CAMBIO] Corrigiendo symlink $link_path -> $target_path (apuntaba a $cur_target)..."
        CHANGES=$((CHANGES + 1))
        run ln -sfn "$target_path" "$link_path"
      fi
    else
      log_change "[CAMBIO] Creando symlink $link_path -> $target_path..."
      CHANGES=$((CHANGES + 1))
      run ln -sfn "$target_path" "$link_path"
    fi
  done

  # 2.9 Activar Modo Live con omarchy dev link (fatal si falla)
  # OMARCHY_PATH debe ser una ruta real: omarchy_security_require_source_root
  # exige OMARCHY_PATH == realpath(OMARCHY_PATH). $DEV_DIR suele ser el symlink
  # /z/fo-omarchy, así que se compara /etc/omarchy.conf contra su realpath y,
  # si difiere (p. ej. tras mover el checkout al meta-workspace), se reescribe
  # con 'omarchy dev link', que ya escribe la ruta resuelta.
  DEV_DIR_REAL="$(realpath -e "$DEV_DIR" 2>/dev/null || echo "$DEV_DIR")"
  log_info "Verificando Modo Live hacia $DEV_DIR_REAL..."
  if ! command -v omarchy >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      log_change "[CAMBIO] Activando Modo Live apuntando a $DEV_DIR..."
      CHANGES=$((CHANGES + 1))
      if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        echo "[DRY-RUN] sudo -u $SUDO_USER omarchy dev link $DEV_DIR"
      else
        echo "[DRY-RUN] omarchy dev link $DEV_DIR"
      fi
    else
      log_err "Comando 'omarchy' no encontrado en PATH. En modo PADRE 'omarchy dev link' es obligatorio."
      exit 1
    fi
  elif grep -qxF "export OMARCHY_PATH=\"${DEV_DIR_REAL}\"" /etc/omarchy.conf 2>/dev/null; then
    log_ok "[✓] ya Modo Live de desarrollo apunta a $DEV_DIR_REAL (ruta real)."
  else
    log_change "[CAMBIO] Activando Modo Live apuntando a $DEV_DIR..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == true ]]; then
      if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        echo "[DRY-RUN] sudo -u $SUDO_USER omarchy dev link $DEV_DIR"
      else
        echo "[DRY-RUN] omarchy dev link $DEV_DIR"
      fi
    else
      if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        sudo -u "$SUDO_USER" omarchy dev link "$DEV_DIR_REAL" --no-reboot
      else
        omarchy dev link "$DEV_DIR_REAL" --no-reboot
      fi
      log_ok "[✓] ya Modo Live configurado exitosamente hacia $DEV_DIR_REAL."
      log_info "Abrí una terminal nueva (o 'source ~/.bashrc') para tomar el nuevo OMARCHY_PATH."
    fi
  fi

else
  echo ""
  log_info "=== [Etapa 2/3] Configuración de Máquina Cliente (Modo HIJA) ==="

  # 2.1 Actualización de distribución
  if command -v omarchy >/dev/null 2>&1; then
    log_change "[CAMBIO] Ejecutando omarchy update para sincronizar paquetes sombreados..."
    CHANGES=$((CHANGES + 1))
    run omarchy update
  else
    log_change "[CAMBIO] Instalando paquetes sombreados base (omarchy omarchy-settings)..."
    CHANGES=$((CHANGES + 1))
    run pacman -S --needed --noconfirm omarchy omarchy-settings
  fi

  # 2.2 Materializar configuraciones en $HOME de cada usuario (fatal si falla)
  for target_u in "${UNIQUE_USERS[@]}"; do
    log_change "[CAMBIO] Aprovisionando entorno para usuario '$target_u' (omarchy provision user --force)..."
    CHANGES=$((CHANGES + 1))
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] sudo -u $target_u omarchy provision user --force"
    else
      sudo -u "$target_u" omarchy provision user --force
      log_ok "[✓] ya el entorno de $target_u ha sido materializado."
    fi
  done

  # 2.3 Reconciliación de paquetes base declarados (fatal si falla)
  # Incluye herdr: viene del repo [omarchy] vía omarchy-base.packages (paso previo a 2.4).
  log_change "[CAMBIO] Reconciliando paquetes declarados (omarchy reinstall pkgs)..."
  CHANGES=$((CHANGES + 1))
  run omarchy reinstall pkgs

  # 2.4 Actualización de espacios Herdr
  log_info "Sincronizando espacios de Herdr (omarchy refresh herdr)..."
  # omarchy refresh herdr es opcional: puede fallar de forma no fatal si Herdr no está instalado o no hay sesión gráfica activa.
  if [[ "$DRY_RUN" == true ]]; then
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
      echo "[DRY-RUN] sudo -u $SUDO_USER omarchy refresh herdr"
    else
      echo "[DRY-RUN] omarchy refresh herdr"
    fi
  else
    herdr_rc=0
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
      sudo -u "$SUDO_USER" omarchy refresh herdr || herdr_rc=$?
    else
      omarchy refresh herdr || herdr_rc=$?
    fi
    if [[ $herdr_rc -eq 0 ]]; then
      log_ok "[✓] ya los espacios de Herdr fueron actualizados."
    else
      log_err "omarchy refresh herdr falló (código $herdr_rc); se continúa sin marcarlo como actualizado. Revisá Herdr o la sesión gráfica."
    fi
  fi
fi

# ------------------------------------------------------------------------------
# ETAPA 3: Verificación Final del Sistema
# ------------------------------------------------------------------------------
echo ""
log_info "=== [Etapa 3/3] Verificación del Estado del Sistema ==="
if [[ "$DRY_RUN" == true ]]; then
  log_info "[DRY-RUN] En ejecución real se auditarán: paquetes omarchy, disponibilidad del repositorio [omarchy-personal] y omarchy dev status."
else
  # 1. Paquetes omarchy requeridos
  if [[ "$ROLE" == "padre" ]]; then
    if ! pacman -Q omarchy omarchy-settings >/dev/null 2>&1 && ! pacman -Q omarchy-dev omarchy-settings-dev >/dev/null 2>&1; then
      log_err "Fallo de verificación: En modo PADRE debe estar instalado el par 'omarchy omarchy-settings' o 'omarchy-dev omarchy-settings-dev'."
      exit 1
    fi
  else
    if ! pacman -Q omarchy omarchy-settings >/dev/null 2>&1; then
      log_err "Fallo de verificación: En modo HIJA debe estar instalado el par 'omarchy omarchy-settings'."
      exit 1
    fi
  fi
  log_ok "[✓] ya los paquetes omarchy requeridos están verificados."

  # 2. Repositorio omarchy-personal en pacman
  if ! pacman -Sl omarchy-personal >/dev/null 2>&1; then
    log_err "Fallo de verificación: El repositorio [omarchy-personal] no está disponible en pacman."
    exit 1
  fi
  log_ok "[✓] ya el repositorio [omarchy-personal] está verificado."

  # 3. omarchy dev status en PADRE
  if [[ "$ROLE" == "padre" ]] && command -v omarchy >/dev/null 2>&1; then
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
      if ! sudo -u "$SUDO_USER" omarchy dev status >/dev/null 2>&1; then
        log_err "Fallo de verificación: 'omarchy dev status' falló para el usuario $SUDO_USER."
        exit 1
      fi
    else
      if ! omarchy dev status >/dev/null 2>&1; then
        log_err "Fallo de verificación: 'omarchy dev status' falló."
        exit 1
      fi
    fi
    log_ok "[✓] ya 'omarchy dev status' verificó el enlace de desarrollo."
  fi

  log_ok "[✓] ya todas las comprobaciones del sistema pasaron exitosamente."
fi

echo ""
echo "=========================================================================="
if [[ "$DRY_RUN" == true ]]; then
  echo "Cambios previstos: $CHANGES"
else
  echo "Cambios aplicados: $CHANGES"
fi
log_ok "Onboarding completado exitosamente en Modo: ${ROLE^^}."
echo "=========================================================================="

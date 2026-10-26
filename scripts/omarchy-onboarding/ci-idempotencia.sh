#!/usr/bin/env bash
# ==============================================================================
# ci-idempotencia.sh — Validación de idempotencia e inocuidad del onboarding
# ==============================================================================
# Verifica que onboard-machine.sh en modo --dry-run:
# 1. No requiera privilegios de root para ejecutarse.
# 2. Sea 100% idempotente (salida idéntica en ejecuciones sucesivas tras normalizar
#    colores ANSI y rutas aleatorias de mktemp).
# 3. No modifique en absoluto el estado del sistema ni del sandbox (snapshots de
#    sandbox, /etc/pacman.conf y git config --system --list idénticos antes y después).
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Fase 1: Bootstrap de entorno (si corre como root en contenedor Arch Linux)
# ------------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  echo "==> [Bootstrap] Preparando dependencias del sistema en contenedor..."
  pacman -Sy --noconfirm git acl sudo gnupg diffutils >/dev/null 2>&1

  # Crear usuario no-root 'ci' en grupo 'wheel' si no existe
  if ! id -u ci >/dev/null 2>&1; then
    useradd -m -G wheel ci
  fi

  # Configurar sudoers para wheel sin password
  echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
  chmod 0440 /etc/sudoers.d/wheel

  # Asegurar que RUNNER_TEMP (si existe) tenga permisos adecuados para el usuario ci
  if [[ -n "${RUNNER_TEMP:-}" ]]; then
    mkdir -p "$RUNNER_TEMP"
    chmod 1777 "$RUNNER_TEMP"
  fi

  # Permitir acceso seguro a directorios en git global
  git -C / config --system --add safe.directory "*" || true

  # Re-ejecutar este script como el usuario no-root 'ci'
  echo "==> [Bootstrap] Transfiriendo ejecución a usuario no-root 'ci'..."
  exec sudo -u ci env -u SUDO_USER RUNNER_TEMP="${RUNNER_TEMP:-}" bash "$0" "$@"
fi

# ------------------------------------------------------------------------------
# Fase 2: Ejecución de pruebas de idempotencia e inocuidad como usuario 'ci'
# ------------------------------------------------------------------------------
echo "==> Iniciando suite de validación de idempotencia (Usuario: $(id -un), EUID: $EUID)..."

# Localizar script bajo prueba
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONBOARD_SCRIPT="${SCRIPT_DIR}/onboard-machine.sh"

if [[ ! -f "$ONBOARD_SCRIPT" ]]; then
  echo "ERROR: No se encontró onboard-machine.sh en $ONBOARD_SCRIPT" >&2
  exit 1
fi

# Directorio temporal de trabajo y sandbox
TEMP_WORK="$(mktemp -d "${TMPDIR:-/tmp}/ci-idempotencia.XXXXXX")"
cleanup() {
  rm -rf "$TEMP_WORK"
}
trap cleanup EXIT INT TERM

SANDBOX_DIR="${RUNNER_TEMP:-$TEMP_WORK}/sandbox"
rm -rf "$SANDBOX_DIR"
mkdir -p "$SANDBOX_DIR"

export ZROOT="${SANDBOX_DIR}/z"
export OMARCHY_WORKSPACE_DIR="${ZROOT}/pj-omarchy"

# Función de normalización: remueve códigos de color ANSI y normaliza rutas mktemp (/tmp/...)
normalize_output() {
  sed -E \
    -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
    -e 's/\\e\[[0-9;]*[a-zA-Z]//g' \
    -e 's#/tmp/[^ ]*#/tmp/X#g'
}

# ------------------------------------------------------------------------------
# Snapshots Iniciales (Antes de cualquier ejecución de dry-run)
# ------------------------------------------------------------------------------
echo "==> Capturando snapshots previos del sistema..."
find "$SANDBOX_DIR" -printf '%p %m %u %g\n' | sort > "$TEMP_WORK/sandbox_before.txt"
cat /etc/pacman.conf > "$TEMP_WORK/pacman_before.txt"
(git -C / config --system --list 2>/dev/null || true) | sort > "$TEMP_WORK/git_before.txt"

# ------------------------------------------------------------------------------
# Prueba 1: Idempotencia en Modo PADRE
# ------------------------------------------------------------------------------
echo "==> Ejecutando Modo PADRE (--dry-run --padre) carrera 1..."
bash "$ONBOARD_SCRIPT" --dry-run --padre 2>&1 | normalize_output > "$TEMP_WORK/padre_run1.txt"

echo "==> Ejecutando Modo PADRE (--dry-run --padre) carrera 2..."
bash "$ONBOARD_SCRIPT" --dry-run --padre 2>&1 | normalize_output > "$TEMP_WORK/padre_run2.txt"

echo "==> Verificando idempotencia en Modo PADRE (diff -u carrera 1 vs carrera 2)..."
if ! diff -u "$TEMP_WORK/padre_run1.txt" "$TEMP_WORK/padre_run2.txt"; then
  echo "ERROR: Falló la idempotencia en Modo PADRE: la salida difiere entre ejecuciones." >&2
  exit 1
fi
echo "[OK] Modo PADRE es 100% idempotente."

# ------------------------------------------------------------------------------
# Prueba 2: Idempotencia en Modo HIJA
# ------------------------------------------------------------------------------
echo "==> Ejecutando Modo HIJA (--dry-run --hija) carrera 1..."
bash "$ONBOARD_SCRIPT" --dry-run --hija 2>&1 | normalize_output > "$TEMP_WORK/hija_run1.txt"

echo "==> Ejecutando Modo HIJA (--dry-run --hija) carrera 2..."
bash "$ONBOARD_SCRIPT" --dry-run --hija 2>&1 | normalize_output > "$TEMP_WORK/hija_run2.txt"

echo "==> Verificando idempotencia en Modo HIJA (diff -u carrera 1 vs carrera 2)..."
if ! diff -u "$TEMP_WORK/hija_run1.txt" "$TEMP_WORK/hija_run2.txt"; then
  echo "ERROR: Falló la idempotencia en Modo HIJA: la salida difiere entre ejecuciones." >&2
  exit 1
fi
echo "[OK] Modo HIJA es 100% idempotente."

# ------------------------------------------------------------------------------
# Snapshots Posteriores y Verificación de Inocuidad
# ------------------------------------------------------------------------------
echo "==> Capturando snapshots posteriores del sistema..."
find "$SANDBOX_DIR" -printf '%p %m %u %g\n' | sort > "$TEMP_WORK/sandbox_after.txt"
cat /etc/pacman.conf > "$TEMP_WORK/pacman_after.txt"
(git -C / config --system --list 2>/dev/null || true) | sort > "$TEMP_WORK/git_after.txt"

echo "==> Auditando inocuidad en sandbox..."
if ! diff -u "$TEMP_WORK/sandbox_before.txt" "$TEMP_WORK/sandbox_after.txt"; then
  echo "ERROR: El sandbox fue modificado por ejecuciones con --dry-run." >&2
  exit 1
fi
echo "[OK] Sandbox intacto (0 cambios)."

echo "==> Auditando inocuidad en /etc/pacman.conf..."
if ! diff -u "$TEMP_WORK/pacman_before.txt" "$TEMP_WORK/pacman_after.txt"; then
  echo "ERROR: /etc/pacman.conf fue modificado por ejecuciones con --dry-run." >&2
  exit 1
fi
echo "[OK] /etc/pacman.conf intacto (0 cambios)."

echo "==> Auditando inocuidad en git config --system..."
if ! diff -u "$TEMP_WORK/git_before.txt" "$TEMP_WORK/git_after.txt"; then
  echo "ERROR: git config --system fue modificado por ejecuciones con --dry-run." >&2
  exit 1
fi
echo "[OK] git config --system intacto (0 cambios)."

echo "==> ✅ Todas las pruebas de idempotencia e inocuidad pasaron exitosamente."

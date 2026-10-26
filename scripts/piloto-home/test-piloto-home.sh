#!/usr/bin/env bash
# scripts/piloto-home/test-piloto-home.sh
# Suite de pruebas automatizadas y dry-run para scripts/piloto-home/piloto-home.sh.
# No realiza cambios en el sistema ni en subvolúmenes reales.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PILOTO_SH="${SCRIPT_DIR}/piloto-home.sh"

PASSED=0
FAILED=0

assert_success() {
    local desc="$1"
    shift
    echo -n "  [TEST] $desc ... "
    if "$@" >/dev/null 2>&1; then
        echo "OK"
        PASSED=$((PASSED + 1))
    else
        echo "FALLÓ (se esperaba éxito)"
        FAILED=$((FAILED + 1))
    fi
}

assert_failure() {
    local desc="$1"
    shift
    echo -n "  [TEST] $desc ... "
    if "$@" >/dev/null 2>&1; then
        echo "FALLÓ (se esperaba fallo)"
        FAILED=$((FAILED + 1))
    else
        echo "OK"
        PASSED=$((PASSED + 1))
    fi
}

echo "=================================================="
echo " Ejecutando Suite de Pruebas: piloto-home"
echo "=================================================="

# 1. Verificación de ShellCheck
echo "==> 1. Verificación Estática (ShellCheck)"
if command -v shellcheck >/dev/null 2>&1; then
    assert_success "Shellcheck en piloto-home.sh y plugins" \
        shellcheck "$PILOTO_SH" "${SCRIPT_DIR}/plugins"/*.sh
else
    echo "  [SKIP] shellcheck no encontrado en PATH."
fi

# 2. Seguridad Dura: Validación de Usuarios
echo "==> 2. Requisito Duro: Rechazo de Usuarios No *-test"
assert_failure "Rechazar usuario 'omarchy' en wipe" \
    "$PILOTO_SH" wipe --user omarchy --dry-run

assert_failure "Rechazar usuario 'root' en wipe" \
    "$PILOTO_SH" wipe --user root --dry-run

assert_failure "Rechazar usuario 'niri' (producción) en wipe" \
    "$PILOTO_SH" wipe --user niri --dry-run

assert_failure "Rechazar usuario 'test' sin sufijo -test" \
    "$PILOTO_SH" wipe --user test --dry-run

assert_failure "Rechazar usuario 'niri-test-produccion'" \
    "$PILOTO_SH" wipe --user niri-test-produccion --dry-run

# 3. Validación de Dry-Run en Subcomandos
echo "==> 3. Ejecución Segura en Modo --dry-run"
assert_success "Subcomando wipe --dry-run con niri-test" \
    "$PILOTO_SH" wipe --user niri-test --dry-run

assert_success "Subcomando deploy niri-actual --dry-run" \
    "$PILOTO_SH" deploy niri-actual --user niri-test --dry-run

assert_success "Subcomando deploy niri-nuevo --dry-run" \
    "$PILOTO_SH" deploy niri-nuevo --user niri-test --dry-run

assert_success "Subcomando deploy hyprland-actual --dry-run" \
    "$PILOTO_SH" deploy hyprland-actual --user niri-test --dry-run

assert_success "Subcomando deploy hyprland-nuevo --dry-run" \
    "$PILOTO_SH" deploy hyprland-nuevo --user niri-test --dry-run

assert_success "Subcomando snapshot --dry-run" \
    "$PILOTO_SH" snapshot snap-test --user niri-test --dry-run

assert_success "Subcomando checklist --dry-run" \
    "$PILOTO_SH" checklist --user niri-test --dry-run

assert_success "Subcomando run --dry-run encadenado" \
    "$PILOTO_SH" run --user niri-test --metodo niri-actual --etiqueta snap-test --dry-run

# 4. Prueba Funcional de Diff y Exclusiones (sin tocar el sistema)
echo "==> 4. Prueba Unitaria de Diff con Exclusiones"
TEST_STATE_DIR="${HOME}/.local/state/piloto-home/test-suite"
mkdir -p "${TEST_STATE_DIR}/dirA" "${TEST_STATE_DIR}/dirB"

# Preparar fixtures
echo "contenido comun" > "${TEST_STATE_DIR}/dirA/comun.txt"
echo "contenido comun" > "${TEST_STATE_DIR}/dirB/comun.txt"

echo "version A" > "${TEST_STATE_DIR}/dirA/modificado.txt"
echo "version B" > "${TEST_STATE_DIR}/dirB/modificado.txt"

echo "solo A" > "${TEST_STATE_DIR}/dirA/exclusivo_a.txt"
echo "solo B" > "${TEST_STATE_DIR}/dirB/exclusivo_b.txt"

# Volátiles que deben ser ignorados por el diff
mkdir -p "${TEST_STATE_DIR}/dirA/.cache" "${TEST_STATE_DIR}/dirB/.cache"
echo "cache" > "${TEST_STATE_DIR}/dirA/.cache/archivo.cache"

mkdir -p "${TEST_STATE_DIR}/dirA/.local/state" "${TEST_STATE_DIR}/dirB/.local/state"
echo "estado" > "${TEST_STATE_DIR}/dirA/.local/state/archivo.state"

echo "log" > "${TEST_STATE_DIR}/dirA/app.log"
echo "socket" > "${TEST_STATE_DIR}/dirA/app.sock"
echo "lock" > "${TEST_STATE_DIR}/dirA/app.lock"

# Ejecutar diff
"$PILOTO_SH" diff "${TEST_STATE_DIR}/dirA" "${TEST_STATE_DIR}/dirB" --state-dir "${TEST_STATE_DIR}" >/dev/null

# Validar que los volátiles NO aparezcan en el reporte generado
REPORT_FILE=$(find "${TEST_STATE_DIR}" -name "diff-dirA-vs-dirB-*.md" | head -n 1)

assert_success "Reporte diff generado en .local/state" test -f "$REPORT_FILE"

assert_failure "El reporte NO debe incluir .cache" grep -q "archivo.cache" "$REPORT_FILE"
assert_failure "El reporte NO debe incluir .local/state" grep -q "archivo.state" "$REPORT_FILE"
assert_failure "El reporte NO debe incluir *.log" grep -q "app.log" "$REPORT_FILE"
assert_failure "El reporte NO debe incluir *.sock" grep -q "app.sock" "$REPORT_FILE"
assert_failure "El reporte NO debe incluir *.lock" grep -q "app.lock" "$REPORT_FILE"

assert_success "El reporte detecta archivo exclusivo A" grep -q "exclusivo_a.txt" "$REPORT_FILE"
assert_success "El reporte detecta archivo exclusivo B" grep -q "exclusivo_b.txt" "$REPORT_FILE"
assert_success "El reporte detecta archivo modificado" grep -q "modificado.txt" "$REPORT_FILE"

# Limpieza de test
rm -rf "${TEST_STATE_DIR}"

echo "=================================================="
echo " Resumen: ${PASSED} superadas, ${FAILED} fallidas."
echo "=================================================="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

echo "¡Todas las pruebas pasaron exitosamente!"

#!/usr/bin/env bash
#
# recifrar-interactivo.sh: Asistente interactivo para cifrar los secretos con tu contraseña maestra
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_SRC="${1:-/tmp/staging-secrets}"
OUTPUT_FILE="${2:-${SCRIPT_DIR}/secrets.tar.gz.age}"

clear || true
echo "=================================================================="
echo "      🔐 CIFRADO INTERACTIVO DE SECRETOS CON AGE                  "
echo "=================================================================="
echo "• Directorio de origen: $SECRETS_SRC"
echo "• Archivo de salida:    $OUTPUT_FILE"
echo ""

if [[ ! -d "$SECRETS_SRC" ]]; then
    echo "ERROR: No se encontró el directorio de secretos en '$SECRETS_SRC'."
    echo "Si deseas extraer los secretos actuales para modificarlos primero, ejecuta:"
    echo "  ${SCRIPT_DIR}/desbloquear-secretos.sh --export-staging /tmp/staging-secrets"
    exit 1
fi

echo "Secretos detectados en el staging:"
find "$SECRETS_SRC" -maxdepth 2 -not -path "$SECRETS_SRC" | sed 's|'"$SECRETS_SRC"'/|  - |'
echo ""

# Contraseña (nunca autogenerada, verificada contra el paquete actual),
# salvaguarda de pérdida de entradas, verificación y reemplazo atómico:
# todo en lib-frase.sh (issues #78, #80).
# shellcheck source=lib-frase.sh
source "$SCRIPT_DIR/lib-frase.sh"
set +e
cifrar_paquete_seguro "$SECRETS_SRC" "$OUTPUT_FILE"
RC=$?
set -e
[[ $RC -eq 0 ]] || exit "$RC"

chmod 600 "$OUTPUT_FILE"

echo ""
echo "=================================================================="
echo " [✓] Archivo cifrado exitosamente:"
echo "     $OUTPUT_FILE ($(du -sh "$OUTPUT_FILE" | cut -f1))"
echo "=================================================================="
echo ""

if [[ -t 0 ]]; then
    read -rp "¿Deseas eliminar el directorio temporal '$SECRETS_SRC' ahora por seguridad? [S/n]: " RESP
    RESP="${RESP:-s}"
else
    RESP="${RECIFRAR_BORRAR_STAGING:-n}"
fi
if [[ "$RESP" =~ ^[sSyY]$ ]]; then
    rm -rf "$SECRETS_SRC"
    echo " [✓] Directorio temporal '$SECRETS_SRC' eliminado de forma segura."
else
    echo " [!] Directorio temporal conservado en '$SECRETS_SRC'."
fi

echo ""
echo "Listo. El archivo 'secrets.tar.gz.age' ya está cifrado con tu contraseña personal."

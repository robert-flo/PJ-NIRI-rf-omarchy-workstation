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

echo "------------------------------------------------------------------"
echo "A continuación, 'age' te solicitará tu contraseña maestra."
echo "Escribe tu contraseña y presiona ENTER (luego confírmala)."
echo "------------------------------------------------------------------"
echo ""

TMP_TAR="$(mktemp --tmpdir=/dev/shm secrets-bundle-XXXXXX.tar.gz)"
trap 'rm -f "$TMP_TAR"' EXIT

tar -czf "$TMP_TAR" -C "$SECRETS_SRC" .

# Ejecución interactiva directa
age -p -o "$OUTPUT_FILE" "$TMP_TAR"

chmod 600 "$OUTPUT_FILE"

echo ""
echo "=================================================================="
echo " [✓] Archivo cifrado exitosamente:"
echo "     $OUTPUT_FILE ($(du -sh "$OUTPUT_FILE" | cut -f1))"
echo "=================================================================="
echo ""

read -rp "¿Deseas eliminar el directorio temporal '$SECRETS_SRC' ahora por seguridad? [S/n]: " RESP
RESP="${RESP:-s}"
if [[ "$RESP" =~ ^[sSyY]$ ]]; then
    rm -rf "$SECRETS_SRC"
    echo " [✓] Directorio temporal '$SECRETS_SRC' eliminado de forma segura."
else
    echo " [!] Directorio temporal conservado en '$SECRETS_SRC'."
fi

echo ""
echo "Listo. El archivo 'secrets.tar.gz.age' ya está cifrado con tu contraseña personal."

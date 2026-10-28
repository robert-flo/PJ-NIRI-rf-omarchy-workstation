#!/usr/bin/env bash
#
# cifrar-secretos.sh: Empaqueta y cifra los secretos del sistema con 'age'
#
# Uso:
#   ./cifrar-secretos.sh [DIRECTORIO_SECRETOS] [SALIDA_AGE]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_SRC="${1:-/tmp/staging-secrets}"
OUTPUT_FILE="${2:-${SCRIPT_DIR}/secrets.tar.gz.age}"

if ! command -v age >/dev/null 2>&1; then
    echo "[!] 'age' no está instalado. Instalándolo con pacman..."
    sudo pacman -S --needed --noconfirm age
fi

if [[ ! -d "$SECRETS_SRC" ]]; then
    echo "ERROR: Directorio de secretos no encontrado: $SECRETS_SRC"
    exit 1
fi

echo "=================================================================="
echo "          CIFRADO DE SECRETOS DEL SISTEMA CON AGE                 "
echo "=================================================================="
echo "Origen: $SECRETS_SRC"
echo "Destino: $OUTPUT_FILE"
echo ""

TMP_TAR="$(mktemp --tmpdir=/dev/shm secrets-bundle-XXXXXX.tar.gz)"
trap 'rm -f "$TMP_TAR" "$TMP_TAR.age"' EXIT

echo "[1/3] Creando paquete temporal en memoria (/dev/shm)..."
tar -czf "$TMP_TAR" -C "$SECRETS_SRC" .

echo "[2/3] Cifrando con age..."
# La contraseña la leemos nosotros: nunca el prompt de age, que ofrece
# autogenerar una si se deja vacía (issue #80). Si el destino ya existe,
# debe abrirlo salvo RECIFRAR_NUEVA_CLAVE=1.
# shellcheck source=lib-frase.sh
source "$SCRIPT_DIR/lib-frase.sh"
if ! obtener_frase_para_recifrar "$OUTPUT_FILE"; then
    echo "Abortado. '$OUTPUT_FILE' no se modificó."
    exit 3
fi
age_cifrar "$FRASE" "$TMP_TAR.age" "$TMP_TAR"
unset FRASE FRASE_ACTUAL
mv -f "$TMP_TAR.age" "$OUTPUT_FILE"

echo "[3/3] Protegiendo permisos de salida..."
chmod 600 "$OUTPUT_FILE"

echo ""
echo "[✓] Secretos cifrados exitosamente en: $OUTPUT_FILE"
echo "    Tamaño: $(du -sh "$OUTPUT_FILE" | cut -f1)"

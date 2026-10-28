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

echo "[1/3] Empaquetando, verificando contraseña y cifrando..."
# Mismo flujo seguro que recifrar-interactivo.sh (lib-frase.sh): contraseña
# nunca autogenerada y verificada, salvaguarda de pérdida de entradas,
# verificación del paquete nuevo y reemplazo atómico con respaldo.
# shellcheck source=lib-frase.sh
source "$SCRIPT_DIR/lib-frase.sh"
set +e
cifrar_paquete_seguro "$SECRETS_SRC" "$OUTPUT_FILE"
RC=$?
set -e
[[ $RC -eq 0 ]] || exit "$RC"
echo "[2/3] Paquete verificado y reemplazado."

echo "[3/3] Protegiendo permisos de salida..."
chmod 600 "$OUTPUT_FILE"

echo ""
echo "[✓] Secretos cifrados exitosamente en: $OUTPUT_FILE"
echo "    Tamaño: $(du -sh "$OUTPUT_FILE" | cut -f1)"

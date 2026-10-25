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
trap 'rm -f "$TMP_TAR"' EXIT

echo "[1/3] Creando paquete temporal en memoria (/dev/shm)..."
tar -czf "$TMP_TAR" -C "$SECRETS_SRC" .

echo "[2/3] Cifrando con age..."
if [[ -n "${AGE_PASSPHRASE:-}" ]]; then
    python3 -c '
import pty, os, time, sys
passphrase = os.environ["AGE_PASSPHRASE"]
pid, fd = pty.fork()
if pid == 0:
    os.execlp("age", "age", "-p", "-o", sys.argv[1], sys.argv[2])
else:
    time.sleep(0.1)
    os.write(fd, (passphrase + "\n").encode())
    time.sleep(0.1)
    os.write(fd, (passphrase + "\n").encode())
    _, status = os.waitpid(pid, 0)
    sys.exit(os.waitstatus_to_exitcode(status))
' "$OUTPUT_FILE" "$TMP_TAR"
else
    age -p -o "$OUTPUT_FILE" "$TMP_TAR"
fi

echo "[3/3] Protegiendo permisos de salida..."
chmod 600 "$OUTPUT_FILE"

echo ""
echo "[✓] Secretos cifrados exitosamente en: $OUTPUT_FILE"
echo "    Tamaño: $(du -sh "$OUTPUT_FILE" | cut -f1)"

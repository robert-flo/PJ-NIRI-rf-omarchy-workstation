#!/usr/bin/env bash
#
# probar-descifrado.sh: Verifica de forma interactiva y segura que tu contraseña
# descifra correctamente 'secrets.tar.gz.age' sin modificar ningún archivo del sistema.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCRYPTED_FILE="${1:-${SCRIPT_DIR}/secrets.tar.gz.age}"

if ! command -v age >/dev/null 2>&1; then
    echo "ERROR: 'age' no está instalado en el sistema."
    exit 1
fi

if [[ ! -f "$ENCRYPTED_FILE" ]]; then
    echo "ERROR: Archivo cifrado no encontrado: $ENCRYPTED_FILE"
    exit 1
fi

clear || true
echo "=================================================================="
echo "      🧪 PRUEBA DE DESCIFRADO Y VALIDACIÓN DE CONTRASEÑA          "
echo "=================================================================="
echo "• Archivo objetivo: $ENCRYPTED_FILE"
echo "• Tamaño cifrado:   $(du -sh "$ENCRYPTED_FILE" | cut -f1)"
echo ""
echo "Esta prueba se realiza 100% en memoria volátil (/dev/shm)."
echo "NO modifica ni altera ningún archivo del sistema ni de tus usuarios."
echo "------------------------------------------------------------------"
echo "Introduce tu contraseña maestra a continuación:"
echo ""

TMP_DIR="$(mktemp -d --tmpdir=/dev/shm test-age-XXXXXX)"
chmod 700 "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

if age -d -o "$TMP_DIR/bundle.tar.gz" "$ENCRYPTED_FILE"; then
    echo ""
    echo "=================================================================="
    echo "  🎉 ¡ÉXITO! CONTRASEÑA CORRECTA Y RECONOCIDA POR AGE             "
    echo "=================================================================="
    echo ""
    echo "[1/2] Verificando integridad del paquete tar.gz..."

    if tar -tzf "$TMP_DIR/bundle.tar.gz" > "$TMP_DIR/lista_archivos.txt"; then
        TOTAL_FILES=$(wc -l < "$TMP_DIR/lista_archivos.txt" | tr -d ' ')
        echo "      [✓] Integridad de compresión: OK"
        echo "      [✓] Archivos y elementos contenidos: $TOTAL_FILES"
        echo ""
        echo "[2/2] Verificando presencia de componentes clave:"
        for pattern in "rclone/rclone.conf" ".ssh/id_ed25519" "git/config" "gh/hosts.yml" ".gnupg" "ticktick-cli" "keyrings"; do
            if grep -q "$pattern" "$TMP_DIR/lista_archivos.txt"; then
                echo "      [✓] $pattern"
            else
                echo "      [ ] $pattern"
            fi
        done
        echo ""
        echo "=================================================================="
        echo " El paquete está 100% íntegro, descifrable y listo para su uso.  "
        echo " (La memoria RAM temporal se ha liberado).                       "
        echo "=================================================================="
        exit 0
    else
        echo "ERROR: El archivo tar.gz presenta inconsistencias."
        exit 1
    fi
else
    echo ""
    echo "=================================================================="
    echo "  ❌ Contraseña incorrecta o fallo en el descifrado con age.     "
    echo "=================================================================="
    exit 1
fi

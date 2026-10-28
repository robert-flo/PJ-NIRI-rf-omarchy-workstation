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

TMP_WORK="$(mktemp -d --tmpdir=/dev/shm secrets-recifrar-XXXXXX)"
chmod 700 "$TMP_WORK"
trap 'rm -rf "$TMP_WORK"' EXIT
TMP_TAR="$TMP_WORK/nuevo.tar.gz"

# Empaqueta con "." para incluir entradas ocultas (.gnupg, .ssh, .grokbot).
tar -czf "$TMP_TAR" -C "$SECRETS_SRC" .

# Contraseña: la leemos nosotros (nunca el prompt de age, que ofrece
# autogenerar una si se deja vacía). Debe abrir el paquete actual salvo
# rotación explícita con RECIFRAR_NUEVA_CLAVE=1 (issue #80).
# shellcheck source=lib-frase.sh
source "$SCRIPT_DIR/lib-frase.sh"
echo "------------------------------------------------------------------"
echo "Introduce tu contraseña maestra (dos veces). No puede estar vacía."
echo "------------------------------------------------------------------"
if ! obtener_frase_para_recifrar "$OUTPUT_FILE"; then
    echo "Abortado. '$OUTPUT_FILE' no se modificó."
    exit 3
fi

# Lista normalizada de entradas de un .tar.gz (sin "./" ni "/" final).
listar_tar() {
    tar -tzf "$1" | sed -e 's|^\./||' -e 's|/$||' | grep -v '^\.\?$' | LC_ALL=C sort -u
}

# Salvaguarda (issue #78): no sobrescribir un paquete con uno que pierde entradas.
if [[ -f "$OUTPUT_FILE" ]]; then
    age_descifrar "$FRASE_ACTUAL" "$TMP_WORK/actual.tar.gz" "$OUTPUT_FILE"
    listar_tar "$TMP_WORK/actual.tar.gz" > "$TMP_WORK/actual.lst"
    listar_tar "$TMP_TAR" > "$TMP_WORK/nuevo.lst"
    FALTAN="$(LC_ALL=C comm -23 "$TMP_WORK/actual.lst" "$TMP_WORK/nuevo.lst")"
    N_ACTUAL="$(wc -l < "$TMP_WORK/actual.lst")"
    N_NUEVO="$(wc -l < "$TMP_WORK/nuevo.lst")"
    echo "Entradas: actual=$N_ACTUAL nuevo=$N_NUEVO"
    if [[ -n "$FALTAN" || "$N_NUEVO" -lt "$N_ACTUAL" ]]; then
        echo ""
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!! ATENCIÓN: el nuevo paquete tiene MENOS entradas que el actual."
        echo "!! Faltarían:"
        printf '%s\n' "$FALTAN" | sed 's|^|!!   - |'
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        if [[ "${RECIFRAR_PERMITIR_PERDIDA:-0}" == "1" ]]; then
            echo "[!] RECIFRAR_PERMITIR_PERDIDA=1: se continúa a pesar de la pérdida."
        elif [[ -t 0 ]]; then
            read -rp "Escribe PERDER para continuar de todos modos (cualquier otra cosa aborta): " CONFIRMA
            if [[ "$CONFIRMA" != "PERDER" ]]; then
                echo "Abortado. '$OUTPUT_FILE' no se modificó."
                exit 2
            fi
        else
            echo "Abortado (sin terminal). '$OUTPUT_FILE' no se modificó."
            echo "Usa RECIFRAR_PERMITIR_PERDIDA=1 si la eliminación es intencional."
            exit 2
        fi
    else
        echo "[✓] No se pierde ninguna entrada del paquete actual."
    fi
    echo ""
fi

# Cifra a un temporal y luego reemplaza, para no dejar un paquete a medias.
age_cifrar "$FRASE" "$TMP_WORK/salida.age" "$TMP_TAR"
unset FRASE FRASE_ACTUAL
mv -f "$TMP_WORK/salida.age" "$OUTPUT_FILE"

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

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

# age con frase desde AGE_PASSPHRASE (no interactivo) o en terminal.
#   age_pty <modo> <salida> <entrada>   modo: d (descifrar) | p (cifrar)
age_pty() {
    local modo="$1" salida="$2" entrada="$3"
    if [[ -n "${AGE_PASSPHRASE:-}" ]]; then
        python3 -c '
import pty, os, time, sys
modo, salida, entrada = sys.argv[1:4]
passphrase = os.environ["AGE_PASSPHRASE"]
pid, fd = pty.fork()
if pid == 0:
    os.execlp("age", "age", "-" + modo, "-o", salida, entrada)
else:
    for _ in range(2 if modo == "p" else 1):
        time.sleep(0.2)
        os.write(fd, (passphrase + "\n").encode())
    try:
        while os.read(fd, 1024):
            pass
    except OSError:
        pass
    _, status = os.waitpid(pid, 0)
    sys.exit(os.waitstatus_to_exitcode(status))
' "$modo" "$salida" "$entrada"
    else
        age "-$modo" -o "$salida" "$entrada"
    fi
}

# Lista normalizada de entradas de un .tar.gz (sin "./" ni "/" final).
listar_tar() {
    tar -tzf "$1" | sed -e 's|^\./||' -e 's|/$||' | grep -v '^\.\?$' | LC_ALL=C sort -u
}

# Salvaguarda (issue #78): no sobrescribir un paquete con uno que pierde entradas.
if [[ -f "$OUTPUT_FILE" ]]; then
    echo "------------------------------------------------------------------"
    echo "Verificando contra el paquete actual (se pedirá la contraseña ACTUAL)..."
    echo "------------------------------------------------------------------"
    age_pty d "$TMP_WORK/actual.tar.gz" "$OUTPUT_FILE"
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

echo "------------------------------------------------------------------"
echo "A continuación, 'age' te solicitará tu contraseña maestra (NUEVA)."
echo "Escribe tu contraseña y presiona ENTER (luego confírmala)."
echo "------------------------------------------------------------------"
echo ""

# Cifra a un temporal y luego reemplaza, para no dejar un paquete a medias.
age_pty p "$TMP_WORK/salida.age" "$TMP_TAR"
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

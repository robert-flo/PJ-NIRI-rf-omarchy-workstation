#!/usr/bin/env bash
#
# lib-frase.sh: manejo de la contraseña maestra de age para los scripts de
# secretos (issue #80). Se carga con `source`.
#
# Reglas:
#   - Ningún script deja que `age -p` muestre su prompt: ese prompt ofrece
#     autogenerar una frase si se deja vacía. La frase la leemos nosotros
#     (read -rs, dos veces), rechazando vacío o no coincidencia.
#   - La frase nunca se escribe a disco: se pasa a age por un pipe
#     (AGE_PASSPHRASE_FD de age-plugin-batchpass, age >= 1.3) o, si el
#     plugin no está, por una pseudo-terminal (python3 pty).
#   - AGE_PASSPHRASE (entorno) permite uso no interactivo; vacía = error.

# Lee una frase nueva (dos veces) en la variable global FRASE.
# Sin terminal usa AGE_PASSPHRASE. Devuelve 1 si no hay forma de obtenerla.
leer_frase_nueva() {
    local etiqueta="${1:-maestra}" f1 f2
    if [[ -n "${AGE_PASSPHRASE+x}" ]]; then
        if [[ -z "$AGE_PASSPHRASE" ]]; then
            echo "ERROR: AGE_PASSPHRASE está vacía; no se permite una contraseña vacía." >&2
            return 1
        fi
        FRASE="$AGE_PASSPHRASE"
        return 0
    fi
    if [[ ! -t 0 ]]; then
        echo "ERROR: sin terminal y sin AGE_PASSPHRASE; no hay forma de pedir la contraseña." >&2
        return 1
    fi
    while true; do
        read -rsp "Contraseña $etiqueta: " f1; echo >&2
        if [[ -z "$f1" ]]; then
            echo "[!] La contraseña no puede estar vacía. Intenta de nuevo." >&2
            continue
        fi
        read -rsp "Confirma la contraseña $etiqueta: " f2; echo >&2
        if [[ "$f1" != "$f2" ]]; then
            echo "[!] Las contraseñas no coinciden. Intenta de nuevo." >&2
            continue
        fi
        FRASE="$f1"
        return 0
    done
}

# Lee una frase existente (una vez) en FRASE. Vacía = re-pregunta.
leer_frase_actual() {
    local etiqueta="${1:-actual}" f1
    if [[ -n "${AGE_PASSPHRASE_ACTUAL:-}" ]]; then FRASE="$AGE_PASSPHRASE_ACTUAL"; return 0; fi
    if [[ ! -t 0 ]]; then
        echo "ERROR: sin terminal y sin AGE_PASSPHRASE_ACTUAL." >&2
        return 1
    fi
    while true; do
        read -rsp "Contraseña $etiqueta: " f1; echo >&2
        [[ -n "$f1" ]] && { FRASE="$f1"; return 0; }
        echo "[!] La contraseña no puede estar vacía." >&2
    done
}

_age_con_frase() { # <frase> <args de age...>
    local frase="$1"; shift
    if [[ -z "$frase" ]]; then
        echo "ERROR: contraseña vacía rechazada (nunca se autogenera)." >&2
        return 1
    fi
    if command -v age-plugin-batchpass >/dev/null 2>&1; then
        # Pipe anónimo: la frase no toca el disco ni el entorno de age.
        env -u AGE_PASSPHRASE AGE_PASSPHRASE_FD=3 age -j batchpass "$@" 3< <(printf '%s' "$frase")
    else
        # Respaldo: age lee la frase de una pseudo-terminal que controlamos.
        FRASE_PTY="$frase" python3 -c '
import pty, os, sys, time
frase = os.environ.pop("FRASE_PTY")
modo = sys.argv[1]
pid, fd = pty.fork()
if pid == 0:
    os.execvp("age", ["age"] + sys.argv[1:])
veces = 2 if modo in ("-e", "-p") else 1
buf = b""
try:
    while veces:
        d = os.read(fd, 1024)
        if not d: break
        buf += d
        if b"passphrase" in buf.lower() or b"contrase" in buf.lower():
            time.sleep(0.05)
            os.write(fd, (frase + "\n").encode())
            veces -= 1; buf = b""
    while os.read(fd, 1024): pass
except OSError:
    pass
_, st = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(st))
' "$@"
    fi
}

# age_cifrar <frase> <salida> <entrada>
age_cifrar() {
    if command -v age-plugin-batchpass >/dev/null 2>&1; then
        _age_con_frase "$1" -e -o "$2" "$3"
    else
        _age_con_frase "$1" -p -o "$2" "$3"
    fi
}

# age_descifrar <frase> <salida> <entrada>
age_descifrar() { _age_con_frase "$1" -d -o "$2" "$3" 2>/dev/null; }

# frase_abre <frase> <archivo.age>: 0 si la frase descifra el archivo.
frase_abre() {
    local t; t="$(mktemp --tmpdir=/dev/shm frase-check-XXXXXX)"
    if age_descifrar "$1" "$t" "$2"; then rm -f "$t"; return 0; fi
    rm -f "$t"; return 1
}

# obtener_frase_para_recifrar <archivo.age actual>
# Deja en FRASE la frase nueva. Si el archivo existe y no se pidió rotación
# (RECIFRAR_NUEVA_CLAVE=1), exige que la frase descifre el archivo actual;
# si no, re-pregunta (o falla sin terminal). Con rotación deja además la
# frase actual en FRASE_ACTUAL (verificada).
obtener_frase_para_recifrar() {
    local actual="$1"
    FRASE_ACTUAL=""
    if [[ -f "$actual" && "${RECIFRAR_NUEVA_CLAVE:-0}" == "1" ]]; then
        echo "[i] RECIFRAR_NUEVA_CLAVE=1: rotación de contraseña." >&2
        while true; do
            leer_frase_actual "ACTUAL (para verificar el paquete existente)" || return 1
            if frase_abre "$FRASE" "$actual"; then FRASE_ACTUAL="$FRASE"; break; fi
            echo "[✗] Esa contraseña no abre '$actual'." >&2
            [[ -t 0 ]] || return 1
        done
        leer_frase_nueva "NUEVA" || return 1
        return 0
    fi
    while true; do
        leer_frase_nueva "maestra" || return 1
        if [[ ! -f "$actual" ]]; then return 0; fi
        if frase_abre "$FRASE" "$actual"; then
            FRASE_ACTUAL="$FRASE"
            echo "[✓] La contraseña abre el paquete actual." >&2
            return 0
        fi
        echo "[✗] Esa contraseña NO abre el paquete actual '$actual'." >&2
        echo "    Para cambiar de contraseña a propósito usa RECIFRAR_NUEVA_CLAVE=1." >&2
        if [[ -n "${AGE_PASSPHRASE+x}" || ! -t 0 ]]; then return 1; fi
    done
}

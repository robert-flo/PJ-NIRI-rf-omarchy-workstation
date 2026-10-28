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

# Limpieza de temporales en cualquier salida (EXIT, Ctrl-C, TERM).
# Los scripts que cargan esta librería NO deben redefinir el trap EXIT;
# registran sus temporales con lf_registrar.
_LF_LIMPIAR=()
# LF_SIN_BATCHPASS=1 fuerza el respaldo pty (lo usa el test/CI).
_lf_batchpass() {
    [[ "${LF_SIN_BATCHPASS:-0}" != "1" ]] && command -v age-plugin-batchpass >/dev/null 2>&1
}
lf_registrar() { _LF_LIMPIAR+=("$@"); }
_lf_limpiar() {
    local p
    for p in "${_LF_LIMPIAR[@]}"; do [[ -n "$p" ]] && rm -rf -- "$p"; done
}
trap _lf_limpiar EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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
    if _lf_batchpass; then
        # Pipe anónimo: la frase no toca el disco ni el entorno de age.
        env -u AGE_PASSPHRASE AGE_PASSPHRASE_FD=3 age -j batchpass "$@" 3< <(printf '%s' "$frase")
    else
        # Respaldo: age lee la frase de una pseudo-terminal que controlamos.
        # La frase llega a python por un pipe (fd 3), no por el entorno, y
        # ni python ni age heredan AGE_PASSPHRASE*.
        env -u AGE_PASSPHRASE -u AGE_PASSPHRASE_ACTUAL -u AGE_PASSPHRASE_FD python3 -c '
import pty, os, sys, time
with os.fdopen(3, "rb") as f:
    frase = f.read().rstrip(b"\n")
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
            os.write(fd, frase + b"\n")
            veces -= 1; buf = b""
    frase = None
    while os.read(fd, 1024): pass
except OSError:
    pass
_, st = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(st))
' "$@" 3< <(printf '%s' "$frase")
    fi
}

# age_cifrar <frase> <salida> <entrada>
age_cifrar() {
    if _lf_batchpass; then
        _age_con_frase "$1" -e -o "$2" "$3"
    else
        _age_con_frase "$1" -p -o "$2" "$3"
    fi
}

# age_descifrar <frase> <salida> <entrada>
age_descifrar() { _age_con_frase "$1" -d -o "$2" "$3" 2>/dev/null; }

# frase_abre <frase> <archivo.age>: 0 si la frase descifra el archivo.
frase_abre() {
    # Descifra a /dev/null: no queda ningún tar en claro que limpiar.
    age_descifrar "$1" /dev/null "$2"
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

# Lista normalizada de entradas de un .tar.gz (sin "./" ni "/" final).
listar_tar() {
    tar -tzf "$1" | sed -e 's|^\./||' -e 's|/$||' | grep -v '^\.\?$' | LC_ALL=C sort -u
}

# cifrar_paquete_seguro <staging> <salida.age>
# Flujo común de recifrar-interactivo.sh y cifrar-secretos.sh:
#   1. empaqueta el staging (con ocultos) en /dev/shm;
#   2. obtiene y verifica la frase (obtener_frase_para_recifrar);
#   3. salvaguarda #78: si faltan entradas del paquete actual, aborta salvo
#      PERDER (terminal) o RECIFRAR_PERMITIR_PERDIDA=1;
#   4. cifra a un temporal en el MISMO directorio que la salida;
#   5. descifra ese temporal y compara su lista con la del staging;
#   6. respalda el paquete viejo en ${XDG_CACHE_HOME:-~/.cache}/ravn-piloto/secrets-backups;
#   7. mv atómico (rename en el mismo filesystem).
# Códigos: 2 = pérdida de entradas, 3 = contraseña, 4 = verificación fallida.
cifrar_paquete_seguro() {
    local src="$1" out="$2" dir base work tmp_age faltan n_act n_new confirma bakdir bak
    dir="$(cd "$(dirname "$out")" && pwd)"; base="$(basename "$out")"; out="$dir/$base"

    work="$(mktemp -d --tmpdir=/dev/shm secrets-cifrar-XXXXXX)"
    chmod 700 "$work"; lf_registrar "$work"
    tar -czf "$work/nuevo.tar.gz" -C "$src" . || return 4
    listar_tar "$work/nuevo.tar.gz" > "$work/nuevo.lst"

    echo "------------------------------------------------------------------"
    echo "Introduce tu contraseña maestra (dos veces). No puede estar vacía."
    echo "------------------------------------------------------------------"
    if ! obtener_frase_para_recifrar "$out"; then
        echo "Abortado. '$out' no se modificó."
        return 3
    fi

    if [[ -f "$out" ]]; then
        if ! age_descifrar "$FRASE_ACTUAL" "$work/actual.tar.gz" "$out"; then
            echo "ERROR: no se pudo descifrar el paquete actual."; return 3
        fi
        listar_tar "$work/actual.tar.gz" > "$work/actual.lst"
        rm -f "$work/actual.tar.gz"
        faltan="$(LC_ALL=C comm -23 "$work/actual.lst" "$work/nuevo.lst")"
        n_act="$(wc -l < "$work/actual.lst")"; n_new="$(wc -l < "$work/nuevo.lst")"
        echo "Entradas: actual=$n_act nuevo=$n_new"
        if [[ -n "$faltan" || "$n_new" -lt "$n_act" ]]; then
            echo ""
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            echo "!! ATENCIÓN: el nuevo paquete tiene MENOS entradas que el actual."
            echo "!! Faltarían:"
            printf '%s\n' "$faltan" | sed 's|^|!!   - |'
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            if [[ "${RECIFRAR_PERMITIR_PERDIDA:-0}" == "1" ]]; then
                echo "[!] RECIFRAR_PERMITIR_PERDIDA=1: se continúa a pesar de la pérdida."
            elif [[ -t 0 ]]; then
                read -rp "Escribe PERDER para continuar de todos modos (cualquier otra cosa aborta): " confirma
                if [[ "$confirma" != "PERDER" ]]; then
                    echo "Abortado. '$out' no se modificó."; return 2
                fi
            else
                echo "Abortado (sin terminal). '$out' no se modificó."
                echo "Usa RECIFRAR_PERMITIR_PERDIDA=1 si la eliminación es intencional."
                return 2
            fi
        else
            echo "[✓] No se pierde ninguna entrada del paquete actual."
        fi
    fi

    # Temporal junto al destino (solo ciphertext) para que el mv sea atómico.
    tmp_age="$(mktemp "$dir/.$base.tmp.XXXXXX")"
    lf_registrar "$tmp_age"
    if ! age_cifrar "$FRASE" "$tmp_age" "$work/nuevo.tar.gz"; then
        echo "ERROR: age no pudo cifrar."; return 4
    fi
    rm -f "$work/nuevo.tar.gz"
    if ! age_descifrar "$FRASE" "$work/verif.tar.gz" "$tmp_age"; then
        echo "ERROR: el paquete nuevo no se descifra con la contraseña. '$out' no se modificó."; return 4
    fi
    unset FRASE FRASE_ACTUAL
    listar_tar "$work/verif.tar.gz" > "$work/verif.lst"
    rm -f "$work/verif.tar.gz"
    if ! cmp -s "$work/verif.lst" "$work/nuevo.lst"; then
        echo "ERROR: el paquete nuevo no contiene lo mismo que el staging. '$out' no se modificó."; return 4
    fi
    echo "[✓] Paquete nuevo verificado (descifra y coincide con el staging)."

    chmod 600 "$tmp_age"
    if [[ -f "$out" ]]; then
        bakdir="${XDG_CACHE_HOME:-$HOME/.cache}/ravn-piloto/secrets-backups"
        mkdir -p "$bakdir"; chmod 700 "$bakdir"
        bak="$bakdir/$base.bak-$(date +%Y%m%d-%H%M%S)"
        cp -p "$out" "$bak"
        echo "[i] Respaldo del paquete anterior: $bak"
    fi
    mv -f "$tmp_age" "$out"
    return 0
}

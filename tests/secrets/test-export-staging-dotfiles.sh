#!/usr/bin/env bash
#
# test-export-staging-dotfiles.sh: ida y vuelta cifrar → exportar staging →
# recifrar con un paquete falso y frase de prueba. También cubre el manejo
# de la contraseña (issue #80): vacía, no coincidente e incorrecta se rechazan. Verifica que los
# directorios ocultos (.gnupg, .ssh, .grokbot) sobreviven (issue #78) y que
# recifrar-interactivo.sh se niega a perder entradas.
#
# Requiere: age, python3, tar. No toca secretos reales ni $HOME.
#   bash tests/secrets/test-export-staging-dotfiles.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$REPO/scripts/secrets"
export AGE_PASSPHRASE="frase-de-prueba-no-real"

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
FALLOS=0
ok()   { echo "  [OK]   $*"; }
fallo(){ echo "  [FALLO] $*"; FALLOS=$((FALLOS+1)); }

# 1. Staging falso con entradas ocultas y normales
SRC="$W/src"
mkdir -p "$SRC"/{.gnupg/private-keys-v1.d,.ssh,.grokbot,rclone,gh}
echo k > "$SRC/.gnupg/private-keys-v1.d/a.key"
echo id > "$SRC/.ssh/id_ed25519"
echo cfg > "$SRC/.ssh/.oculto-dentro"
echo t > "$SRC/.grokbot/token"
echo r > "$SRC/rclone/rclone.conf"
echo h > "$SRC/gh/hosts.yml"
AGEF="$W/secrets.tar.gz.age"

echo "[1] cifrar-secretos.sh"
bash "$S/cifrar-secretos.sh" "$SRC" "$AGEF" >/dev/null

echo "[2] desbloquear-secretos.sh --export-staging"
STG="$W/staging"
bash "$S/desbloquear-secretos.sh" --export-staging "$STG" "$AGEF" >/dev/null
for p in .gnupg/private-keys-v1.d/a.key .ssh/id_ed25519 .ssh/.oculto-dentro .grokbot/token rclone/rclone.conf gh/hosts.yml; do
    [[ -f "$STG/$p" ]] && ok "exportado $p" || fallo "falta $p en el staging"
done

echo "[3] recifrar sin cambios (debe pasar la salvaguarda)"
cp "$STG/.grokbot/token" "$W/token.bak"
if bash "$S/recifrar-interactivo.sh" "$STG" "$AGEF" </dev/null >"$W/r1.log" 2>&1; then
    ok "recifrado aceptado"
else
    fallo "recifrado sin pérdidas fue rechazado"; cat "$W/r1.log"
fi
STG2="$W/staging2"
bash "$S/desbloquear-secretos.sh" --export-staging "$STG2" "$AGEF" >/dev/null
for p in .gnupg/private-keys-v1.d/a.key .ssh/id_ed25519 .grokbot/token; do
    [[ -f "$STG2/$p" ]] && ok "ida y vuelta conserva $p" || fallo "ida y vuelta perdió $p"
done

echo "[4] recifrar perdiendo .ssh (debe negarse sin terminal)"
rm -rf "$STG2/.ssh"
SUM="$(sha256sum "$AGEF")"
set +e
bash "$S/recifrar-interactivo.sh" "$STG2" "$AGEF" </dev/null >"$W/r2.log" 2>&1
RC=$?
set -e
[[ $RC -eq 2 ]] && ok "rechazado (exit 2)" || { fallo "exit $RC, se esperaba 2"; cat "$W/r2.log"; }
[[ "$(sha256sum "$AGEF")" == "$SUM" ]] && ok "paquete intacto" || fallo "el paquete cambió"
grep -q '\.ssh' "$W/r2.log" && ok "aviso lista .ssh" || fallo "el aviso no menciona .ssh"

echo "[5] RECIFRAR_PERMITIR_PERDIDA=1 permite la eliminación intencional"
if RECIFRAR_PERMITIR_PERDIDA=1 bash "$S/recifrar-interactivo.sh" "$STG2" "$AGEF" </dev/null >/dev/null 2>&1; then
    ok "eliminación intencional aceptada"
else
    fallo "RECIFRAR_PERMITIR_PERDIDA=1 no funcionó"
fi

echo "[6] contraseña vacía rechazada (issue #80)"
SUM="$(sha256sum "$AGEF")"
set +e
AGE_PASSPHRASE="" bash "$S/recifrar-interactivo.sh" "$STG2" "$AGEF" </dev/null >"$W/r3.log" 2>&1; RC=$?
set -e
[[ $RC -eq 3 ]] && ok "vacía rechazada (exit 3)" || { fallo "vacía: exit $RC"; cat "$W/r3.log"; }
[[ "$(sha256sum "$AGEF")" == "$SUM" ]] && ok "paquete intacto" || fallo "el paquete cambió con frase vacía"

echo "[7] contraseña incorrecta rechazada (no abre el paquete actual)"
set +e
AGE_PASSPHRASE="otra-frase" bash "$S/recifrar-interactivo.sh" "$STG2" "$AGEF" </dev/null >"$W/r4.log" 2>&1; RC=$?
AGE_PASSPHRASE="otra-frase" bash "$S/cifrar-secretos.sh" "$STG2" "$AGEF" </dev/null >"$W/r4b.log" 2>&1; RC2=$?
set -e
[[ $RC -eq 3 ]] && ok "recifrar: incorrecta rechazada (exit 3)" || { fallo "recifrar incorrecta: exit $RC"; cat "$W/r4.log"; }
[[ $RC2 -eq 3 ]] && ok "cifrar-secretos: incorrecta rechazada (exit 3)" || { fallo "cifrar incorrecta: exit $RC2"; cat "$W/r4b.log"; }
[[ "$(sha256sum "$AGEF")" == "$SUM" ]] && ok "paquete intacto" || fallo "el paquete cambió con frase incorrecta"

echo "[8] interactivo: vacía, no coincide e incorrecta se re-preguntan; la correcta pasa"
cp "$AGEF" "$W/antes.age"
if env -u AGE_PASSPHRASE python3 - "$S/recifrar-interactivo.sh" "$STG" "$AGEF" "$AGE_PASSPHRASE" >"$W/r5.log" 2>&1 <<'PY'
import pty, os, sys, time
script, stg, agef, buena = sys.argv[1:5]
respuestas = ["", "a1", "a2", "mala", "mala", buena, buena]
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", script, stg, agef])
out = b""; i = 0; t0 = time.time()
try:
    while time.time() - t0 < 60:
        d = os.read(fd, 1024)
        if not d: break
        out += d; sys.stdout.write(d.decode(errors="replace")); sys.stdout.flush()
        while i < len(respuestas) and out.count(b"Contrase") + out.count(b"Confirma") > i:
            time.sleep(0.05); os.write(fd, (respuestas[i] + "\n").encode()); i += 1
        if b"eliminar el directorio" in out[-200:]:
            os.write(fd, b"n\n")
except OSError:
    pass
_, st = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(st))
PY
then ok "interactivo terminó bien"; else fallo "interactivo falló"; cat "$W/r5.log"; fi
grep -q "no puede estar vacía" "$W/r5.log" && ok "avisó de vacía" || fallo "no avisó de vacía"
grep -q "no coinciden" "$W/r5.log" && ok "avisó de no coincidencia" || fallo "no avisó de no coincidencia"
grep -q "NO abre el paquete actual" "$W/r5.log" && ok "avisó de incorrecta" || fallo "no avisó de incorrecta"
grep -qi "autogenerate\|leave empty" "$W"/r*.log 2>/dev/null && fallo "apareció el prompt de autogenerar de age" || ok "sin prompt de autogenerar"

echo "[9] rotación explícita con RECIFRAR_NUEVA_CLAVE=1"
if RECIFRAR_NUEVA_CLAVE=1 AGE_PASSPHRASE_ACTUAL="$AGE_PASSPHRASE" AGE_PASSPHRASE="frase-nueva" \
    bash "$S/recifrar-interactivo.sh" "$STG" "$AGEF" </dev/null >"$W/r6.log" 2>&1; then
    ok "rotación aceptada"
else
    fallo "rotación falló"; cat "$W/r6.log"
fi
AGE_PASSPHRASE="frase-nueva" bash "$S/desbloquear-secretos.sh" --export-staging "$W/stg3" "$AGEF" >/dev/null 2>&1 \
    && ok "la frase nueva abre el paquete" || fallo "la frase nueva no abre el paquete"

echo ""
if [[ $FALLOS -eq 0 ]]; then echo "RESULTADO: OK"; else echo "RESULTADO: $FALLOS fallo(s)"; exit 1; fi

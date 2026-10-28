#!/usr/bin/env bash
#
# test-export-staging-dotfiles.sh: ida y vuelta cifrar → exportar staging →
# recifrar con un paquete falso y frase de prueba. Verifica que los
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

echo ""
if [[ $FALLOS -eq 0 ]]; then echo "RESULTADO: OK"; else echo "RESULTADO: $FALLOS fallo(s)"; exit 1; fi

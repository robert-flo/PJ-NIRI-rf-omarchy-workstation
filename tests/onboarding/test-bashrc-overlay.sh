#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # las comprobaciones se evalúan con eval a propósito
# Test de scripts/omarchy-onboarding/bashrc-overlay.sh (paso 2.10 del onboarding).
# Casos: bashrc viejo recibe ambas líneas; re-ejecución no cambia nada;
# archivo ausente se crea desde el stub; sin anclas; symlink; dry-run.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIX="$RAIZ/tests/onboarding/fixtures"
# shellcheck source=scripts/omarchy-onboarding/bashrc-overlay.sh
source "$RAIZ/scripts/omarchy-onboarding/bashrc-overlay.sh"
STUB="$FIX/dot.bashrc"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FALLOS=0
ok()   { echo "  ok   $1"; }
mal()  { echo "  FALLA $1"; FALLOS=$((FALLOS + 1)); }
chk()  { if eval "$2"; then ok "$1"; else mal "$1"; fi; }
nbak() { find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").bak-*" | wc -l; }

echo "1) bashrc viejo recibe ambas líneas tras su ancla"
B="$TMP/c1/.bashrc"; mkdir -p "$TMP/c1"; cp "$FIX/bashrc-viejo" "$B"
asegurar_bashrc_overlay "$B" "$STUB"
chk "reporta 1 cambio" '[[ $BASHRC_CAMBIOS -eq 1 ]]'
chk "línea env justo tras env-bootstrap" '[[ "$(grep -A1 -xF "$BASHRC_ANCLA_ENV" "$B" | tail -1)" == "$BASHRC_LINEA_ENV" ]]'
chk "línea rc justo tras el rc de Omarchy" '[[ "$(grep -A1 -xF "$BASHRC_ANCLA_RC" "$B" | tail -1)" == "$BASHRC_LINEA_RC" ]]'
chk "contenido del usuario intacto" 'grep -qxF "alias gs='"'"'git status'"'"'" "$B" && grep -qxF "export EDITOR=nvim" "$B"'
chk "solo se agregaron 2 líneas" '[[ $(wc -l < "$B") -eq $(( $(wc -l < "$FIX/bashrc-viejo") + 2 )) ]]'
chk "respaldo creado e igual al original" '[[ $(nbak "$B") -eq 1 ]] && cmp -s "$FIX/bashrc-viejo" "$(ls "$B".bak-*)"'
chk "orden igual al stub canónico" 'diff <(grep -F -e ravn -e env-bootstrap -e default/bash/rc "$B") <(grep -F -e ravn -e env-bootstrap -e default/bash/rc "$STUB") >/dev/null'

echo "2) re-ejecución no cambia nada"
cp "$B" "$TMP/antes"
asegurar_bashrc_overlay "$B" "$STUB"
chk "reporta 0 cambios" '[[ $BASHRC_CAMBIOS -eq 0 ]]'
chk "archivo idéntico" 'cmp -s "$TMP/antes" "$B"'
chk "sin respaldo nuevo" '[[ $(nbak "$B") -eq 1 ]]'
cp "$STUB" "$TMP/stub-copia"; asegurar_bashrc_overlay "$TMP/stub-copia" "$STUB"
chk "el stub actual ya está completo" '[[ $BASHRC_CAMBIOS -eq 0 ]] && cmp -s "$STUB" "$TMP/stub-copia"'

echo "3) archivo ausente se crea desde el stub"
B="$TMP/c3/.bashrc"; mkdir -p "$TMP/c3"
asegurar_bashrc_overlay "$B" "$STUB"
chk "reporta 1 cambio" '[[ $BASHRC_CAMBIOS -eq 1 ]]'
chk "igual al stub" 'cmp -s "$STUB" "$B"'
chk "sin respaldo" '[[ $(nbak "$B") -eq 0 ]]'
asegurar_bashrc_overlay "$TMP/c3/otro" "$TMP/no-existe"; rc=$?
chk "sin stub: falla sin crear nada" '[[ $rc -ne 0 && ! -e "$TMP/c3/otro" ]]'

echo "4) sin anclas: env antes del corte interactivo, rc al final"
B="$TMP/c4"; cp "$FIX/bashrc-sin-anclas" "$B"
asegurar_bashrc_overlay "$B" "$STUB"
chk "env antes del corte" '[[ "$(grep -B1 -xF "$BASHRC_CORTE_INTERACTIVO" "$B" | head -1)" == "$BASHRC_LINEA_ENV" ]]'
chk "rc al final" '[[ "$(tail -1 "$B")" == "$BASHRC_LINEA_RC" ]]'
asegurar_bashrc_overlay "$B" "$STUB"
chk "idempotente" '[[ $BASHRC_CAMBIOS -eq 0 ]]'

echo "5) symlink: se edita el destino y el enlace se conserva"
mkdir -p "$TMP/c5/dots"; cp "$FIX/bashrc-viejo" "$TMP/c5/dots/bashrc"; ln -s dots/bashrc "$TMP/c5/.bashrc"
asegurar_bashrc_overlay "$TMP/c5/.bashrc" "$STUB"
chk "sigue siendo symlink" '[[ -L "$TMP/c5/.bashrc" ]]'
chk "destino actualizado" 'grep -qxF "$BASHRC_LINEA_RC" "$TMP/c5/dots/bashrc"'

echo "6) DRY_RUN=true no escribe"
B="$TMP/c6"; cp "$FIX/bashrc-viejo" "$B"
DRY_RUN=true asegurar_bashrc_overlay "$B" "$STUB"
chk "reporta 1 cambio previsto" '[[ $BASHRC_CAMBIOS -eq 1 ]]'
chk "archivo sin tocar y sin respaldo ni temporales" 'cmp -s "$FIX/bashrc-viejo" "$B" && [[ $(ls "$TMP" | grep -c "^c6") -eq 1 ]]'
DRY_RUN=true asegurar_bashrc_overlay "$TMP/c6-nuevo" "$STUB"
chk "ausente: no se crea" '[[ $BASHRC_CAMBIOS -eq 1 && ! -e "$TMP/c6-nuevo" ]]'

echo
if [[ $FALLOS -eq 0 ]]; then echo "OK: todos los casos pasaron"; else echo "FALLARON $FALLOS comprobaciones"; exit 1; fi

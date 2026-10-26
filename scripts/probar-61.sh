#!/usr/bin/env bash
# probar-61.sh — prueba en vivo de #61 (reintento + aviso) con el trío de pj-domina, ticket 20.
# Uso: bash probar-61.sh [ticket]   (default 20)
set -euo pipefail
ticket="${1:-20}"
base="$HOME/.cache/ravn-piloto"
ws="$base/workstation-61"
pj="$base/pj-domina"
repo="robert-flo/PJ-NIRI-rf-omarchy-workstation"
rama="feat/61-reintento-aviso"

command -v herdr >/dev/null || { echo "falta herdr" >&2; exit 1; }
command -v gh >/dev/null || { echo "falta gh" >&2; exit 1; }
[[ -d "$pj/.git" ]] || { echo "no encuentro $pj" >&2; exit 1; }
command -v notify-send >/dev/null || echo "aviso: no hay notify-send, solo se escribirá status.json" >&2

mkdir -p "$base"
if [[ -d "$ws/.git" ]]; then
    git -C "$ws" fetch -q origin "$rama"
    git -C "$ws" checkout -q "$rama"
    git -C "$ws" pull -q --rebase --autostash origin "$rama"
else
    gh repo clone "$repo" "$ws" -- -q -b "$rama"
fi
git -C "$pj" pull -q --rebase --autostash || true

export TRIO_GIT_NAME="${TRIO_GIT_NAME:-$(git config --global user.name || true)}"
export TRIO_GIT_EMAIL="${TRIO_GIT_EMAIL:-$(git config --global user.email || true)}"

echo "workstation en $ws @ $(git -C "$ws" rev-parse --short HEAD)"
"$ws/scripts/pj-trio" --dry-run pj-domina "$ticket" --repo rf-tools >/dev/null
"$ws/scripts/pj-trio" pj-domina "$ticket" --repo rf-tools

cat <<MSG

listo. ahora:
  1. abrí herdr y esperá a que el wk esté trabajando
  2. cerrá la pestaña wk una vez -> el pm debería reintentar (relanzá con: $ws/scripts/pj-trio --no-kickoff pj-domina $ticket --repo rf-tools)
  3. cerrala otra vez -> notificación + estado needs-roberto
  ver estado: cat $pj/.trio/$ticket/status.json
MSG

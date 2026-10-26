#!/usr/bin/env bash
# Prueba sin herdr: --dry-run y --print-kickoff de pj-trio sobre repos temporales.
set -euo pipefail

aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git init -q "$tmp/pj-demo"
git init -q "$tmp/miembro"
export PJ_TRIO_CONFIG="$aqui/trio.conf.example"
export PATH="/usr/bin:/bin"

fallo() { echo "FALLO: $*" >&2; exit 1; }

out="$("$aqui/pj-trio" --dry-run "$tmp/pj-demo" 42 --repo "$tmp/miembro" 2>&1)"
grep -q 'herdr agent start "pm-pj-demo"' <<<"$out" || fallo "nombre de agente por proyecto"
grep -q 'herdr agent prompt "pm-pj-demo"' <<<"$out" || fallo "envío del arranque"
grep -q "config user.email \"25asab015@ujmd.edu.sv\"" <<<"$out" || fallo "identidad git"
[[ ! -e "$tmp/pj-demo/.trio" ]] || fallo "--dry-run escribió .trio"
[[ -z "$(git -C "$tmp/pj-demo" config --local user.email || true)" ]] || fallo "--dry-run tocó git config"

k="$("$aqui/pj-trio" --print-kickoff "$tmp/pj-demo" 42 --repo "$tmp/miembro")"
grep -q '{{' <<<"$k" && fallo "quedan placeholders"
grep -q "$tmp/pj-demo/.trio/42" <<<"$k" || fallo "carpeta de handoff"
grep -q 'herdr agent prompt wk-pj-demo' <<<"$k" || fallo "PM no pinguea a WK"
grep -q -- '--match-head-commit' <<<"$k" || fallo "merge sin match-head-commit"
grep -qi 'worktree add' <<<"$k" || fallo "worktree nuevo"

# Idempotencia del arranque: con status.json presente no se reenvía.
mkdir -p "$tmp/pj-demo/.trio/42" && echo '{}' > "$tmp/pj-demo/.trio/42/status.json"
out="$("$aqui/pj-trio" --dry-run "$tmp/pj-demo" 42 2>&1)"
grep -q 'no se reenvía' <<<"$out" || fallo "reenvío del arranque"

echo "OK"

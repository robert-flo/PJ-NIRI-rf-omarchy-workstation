#!/usr/bin/env bash
# scripts/piloto-home/plugins/hyprland-nuevo.sh
# Stub enchufable para despliegue de Hyprland nuevo (ravn-home-hyprland) en omarchy-test (#48).

set -euo pipefail

TARGET_USER="${TARGET_USER:-}"
TARGET_HOME="${TARGET_HOME:-/home/${TARGET_USER}}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -z "$TARGET_USER" ]]; then
    echo "ERROR [hyprland-nuevo]: TARGET_USER no está definido." >&2
    exit 1
fi

if [[ ! "$TARGET_USER" =~ ^[a-zA-Z0-9._-]+-test$ ]]; then
    echo "ERROR [hyprland-nuevo]: TARGET_USER '${TARGET_USER}' no termina en -test." >&2
    exit 1
fi

echo "==> [hyprland-nuevo] [STUB] Preparando entorno Hyprland nuevo para ${TARGET_USER}..."

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] [hyprland-nuevo] Stub simulado para ${TARGET_HOME} (ravn-home-common + ravn-home-hyprland)."
    exit 0
fi

echo "==> [hyprland-nuevo] AVISO: Plugin stub para omarchy-test activo."
echo "    Pendiente empaquetado de ravn-home-hyprland en pj-omarchy."

#!/usr/bin/env bash
# scripts/piloto-home/plugins/hyprland-actual.sh
# Stub enchufable para despliegue de Hyprland actual en omarchy-test (#48).

set -euo pipefail

TARGET_USER="${TARGET_USER:-}"
TARGET_HOME="${TARGET_HOME:-/home/${TARGET_USER}}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -z "$TARGET_USER" ]]; then
    echo "ERROR [hyprland-actual]: TARGET_USER no está definido." >&2
    exit 1
fi

if [[ ! "$TARGET_USER" =~ ^[a-zA-Z0-9._-]+-test$ ]]; then
    echo "ERROR [hyprland-actual]: TARGET_USER '${TARGET_USER}' no termina en -test." >&2
    exit 1
fi

echo "==> [hyprland-actual] [STUB] Preparando entorno Hyprland actual para ${TARGET_USER}..."

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] [hyprland-actual] Stub simulado para ${TARGET_HOME}."
    exit 0
fi

echo "==> [hyprland-actual] AVISO: Plugin stub para omarchy-test activo."
echo "    La infraestructura de omarchy base opera desde /etc/skel y omarchy upstream."

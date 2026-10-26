#!/usr/bin/env bash
# scripts/piloto-home/plugins/niri-nuevo.sh
# Método de despliegue NUEVO para niri en usuarios *-test (#40, #44).
# Instala ravn-home-common y ravn-home-niri vía pacman,
# clona el repo de perfil niri con dotbare y ejecuta ravn-home-sync.

set -euo pipefail

TARGET_USER="${TARGET_USER:-}"
TARGET_HOME="${TARGET_HOME:-/home/${TARGET_USER}}"
PROFILE_REPO="${PROFILE_REPO:-https://github.com/robert-flo/ravn-home-profile-niri.git}"
PROFILE_BRANCH="${PROFILE_BRANCH:-master}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -z "$TARGET_USER" ]]; then
    echo "ERROR [niri-nuevo]: TARGET_USER no está definido." >&2
    exit 1
fi

if [[ ! "$TARGET_USER" =~ ^[a-zA-Z0-9._-]+-test$ ]]; then
    echo "ERROR [niri-nuevo]: TARGET_USER '${TARGET_USER}' no termina en -test." >&2
    exit 1
fi

echo "==> [niri-nuevo] Desplegando método nuevo en ${TARGET_HOME} para ${TARGET_USER}..."
echo "    Paquetes pacman: ravn-home-common, ravn-home-niri"
echo "    Repo de perfil: ${PROFILE_REPO} (rama: ${PROFILE_BRANCH})"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] sudo pacman -S --needed --noconfirm ravn-home-common ravn-home-niri"
    echo "[DRY-RUN] sudo -u '$TARGET_USER' -H bash -c 'cd ~ && dotbare finit -y -u \"$PROFILE_REPO\" </dev/null'"
    echo "[DRY-RUN] sudo -u '$TARGET_USER' ravn-home-sync"
    echo "==> [niri-nuevo] [DRY-RUN] Despliegue simulado exitosamente."
    exit 0
fi

# 1. Instalar paquetes pacman
echo "==> [niri-nuevo] Instalando paquetes del sistema..."
sudo pacman -S --needed --noconfirm ravn-home-common ravn-home-niri

# 2. Clonación bare con dotbare del repo de perfil
echo "==> [niri-nuevo] Clonando repositorio de perfil con dotbare..."
sudo -u "$TARGET_USER" -H bash -c "cd ~ && dotbare finit -y -u '$PROFILE_REPO' </dev/null"

# 3. Configurar git remoto y branch
echo "==> [niri-nuevo] Configurando git remoto..."
sudo -u "$TARGET_USER" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
sudo -u "$TARGET_USER" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" config status.showUntrackedFiles no
sudo -u "$TARGET_USER" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" fetch origin || true
sudo -u "$TARGET_USER" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" branch -u "origin/$PROFILE_BRANCH" "$PROFILE_BRANCH" 2>/dev/null || true

# 4. Sincronización idempotente con ravn-home-sync
if command -v ravn-home-sync >/dev/null 2>&1; then
    echo "==> [niri-nuevo] Ejecutando ravn-home-sync..."
    sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" ravn-home-sync
elif [[ -x "$TARGET_HOME/.local/bin/ravn-home-sync" ]]; then
    echo "==> [niri-nuevo] Ejecutando ~/.local/bin/ravn-home-sync..."
    sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" "$TARGET_HOME/.local/bin/ravn-home-sync"
elif [[ -x "/usr/share/ravn/common/bin/ravn-home-sync" ]]; then
    echo "==> [niri-nuevo] Ejecutando /usr/share/ravn/common/bin/ravn-home-sync..."
    sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" "/usr/share/ravn/common/bin/ravn-home-sync"
else
    echo "==> [niri-nuevo] AVISO: ravn-home-sync no disponible en PATH ni en /usr/share/ravn."
fi

echo "==> [niri-nuevo] Despliegue nuevo completado."

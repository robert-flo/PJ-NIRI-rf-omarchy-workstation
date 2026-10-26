#!/usr/bin/env bash
# scripts/piloto-home/plugins/niri-actual.sh
# Método de despliegue ACTUAL para niri en usuarios *-test.
# Clona robert-flo/niri-dotfiles con dotbare y corre niri-dotfiles-postinstall.

set -euo pipefail

TARGET_USER="${TARGET_USER:-}"
TARGET_HOME="${TARGET_HOME:-/home/${TARGET_USER}}"
TARGET_UID="${TARGET_UID:-$(id -u "$TARGET_USER" 2>/dev/null || echo 1002)}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/robert-flo/niri-dotfiles.git}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-master}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -z "$TARGET_USER" ]]; then
    echo "ERROR [niri-actual]: TARGET_USER no está definido." >&2
    exit 1
fi

if [[ ! "$TARGET_USER" =~ ^[a-zA-Z0-9._-]+-test$ ]]; then
    echo "ERROR [niri-actual]: TARGET_USER '${TARGET_USER}' no termina en -test." >&2
    exit 1
fi

echo "==> [niri-actual] Desplegando método actual en ${TARGET_HOME} para ${TARGET_USER}..."
echo "    Repo: ${DOTFILES_REPO} (rama: ${DOTFILES_BRANCH})"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] sudo -u '$TARGET_USER' -H bash -c 'cd ~ && dotbare finit -y -u \"$DOTFILES_REPO\" </dev/null'"
    echo "[DRY-RUN] Configurar git remote/branch en ~/.cfg"
    echo "[DRY-RUN] sudo -u '$TARGET_USER' ~/.local/bin/niri-dotfiles-postinstall"
    echo "==> [niri-actual] [DRY-RUN] Despliegue simulado exitosamente."
    exit 0
fi

# 1. Clonación bare con dotbare
echo "==> [niri-actual] Ejecutando dotbare finit..."
sudo -u "$TARGET_USER" -H bash -c "cd ~ && dotbare finit -y -u '$DOTFILES_REPO' </dev/null"

# 2. Configurar upstream y fetch
echo "==> [niri-actual] Configurando git remoto y rama..."
sudo -u "$TARGET_USER" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
sudo -u "$TARGET_USER" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" config status.showUntrackedFiles no
sudo -u "$TARGET_USER" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" fetch origin
sudo -u "$TARGET_USER" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" branch -u "origin/$DOTFILES_BRANCH" "$DOTFILES_BRANCH" || true

# 3. Postinstall
if [[ -x "$TARGET_HOME/.local/bin/niri-dotfiles-postinstall" ]]; then
    echo "==> [niri-actual] Ejecutando niri-dotfiles-postinstall..."
    sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" XDG_RUNTIME_DIR="/run/user/$TARGET_UID" bash -c "$TARGET_HOME/.local/bin/niri-dotfiles-postinstall"
else
    echo "==> [niri-actual] AVISO: niri-dotfiles-postinstall no encontrado o no ejecutable en ${TARGET_HOME}/.local/bin"
fi

echo "==> [niri-actual] Despliegue actual completado."

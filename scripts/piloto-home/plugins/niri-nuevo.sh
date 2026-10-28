#!/usr/bin/env bash
# scripts/piloto-home/plugins/niri-nuevo.sh
# Método de despliegue NUEVO para niri en usuarios *-test (#40, #44).
# Instala ravn-home-common y ravn-home-niri vía pacman,
# clona el repo de perfil niri con dotbare y ejecuta ravn-home-sync y ravn-niri-sync.

set -euo pipefail

TARGET_USER="${TARGET_USER:-}"
TARGET_HOME="${TARGET_HOME:-/home/${TARGET_USER}}"
TARGET_UID="${TARGET_UID:-$(id -u "$TARGET_USER" 2>/dev/null || echo 1002)}"
PROFILE_REPO="${PROFILE_REPO:-https://github.com/robert-flo/ravn-home-profile-niri.git}"
PROFILE_BRANCH="${PROFILE_BRANCH:-main}"
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
    echo "[DRY-RUN] Configurar git remote/branch en ~/.cfg"
    echo "[DRY-RUN] sudo -u '$TARGET_USER' ravn-home-sync"
    echo "[DRY-RUN] sudo -u '$TARGET_USER' ravn-niri-sync"
    echo "[DRY-RUN] sudo -u '$TARGET_USER' niri-dotfiles-postinstall"
    echo "==> [niri-nuevo] [DRY-RUN] Despliegue simulado exitosamente."
    exit 0
fi

# Helper temporal de autenticación para repositorios privados de GitHub
ASKPASS=""
cleanup_cred() {
    if [[ -n "$ASKPASS" && -f "$ASKPASS" ]]; then
        rm -f "$ASKPASS"
    fi
}
trap cleanup_cred EXIT

if command -v gh >/dev/null 2>&1; then
    TOKEN="$(gh auth token 2>/dev/null || true)"
    if [[ -n "$TOKEN" ]]; then
        ASKPASS="$(mktemp /tmp/ravn-askpass-XXXXXX.sh)"
        cat << EOF > "$ASKPASS"
#!/bin/sh
case "\$1" in
  *Username*) echo "x-access-token" ;;
  *Password*) echo "${TOKEN}" ;;
  *) echo "${TOKEN}" ;;
esac
EOF
        chmod 755 "$ASKPASS"
    fi
fi

# 1. Instalar paquetes pacman (idempotente gracias a --needed)
echo "==> [niri-nuevo] Instalando paquetes del sistema..."
sudo pacman -S --needed --noconfirm ravn-home-common ravn-home-niri

# 2. Clonación bare con dotbare del repo de perfil (idempotente si ~/.cfg ya existe)
if ! sudo test -d "$TARGET_HOME/.cfg"; then
    echo "==> [niri-nuevo] Clonando repositorio de perfil con dotbare..."
    if [[ -n "$ASKPASS" ]]; then
        (cd /tmp && sudo -u "$TARGET_USER" -H env GIT_ASKPASS="$ASKPASS" bash -c "cd ~ && dotbare finit -y -u '$PROFILE_REPO' </dev/null")
    else
        (cd /tmp && sudo -u "$TARGET_USER" -H bash -c "cd ~ && dotbare finit -y -u '$PROFILE_REPO' </dev/null")
    fi
else
    echo "==> [niri-nuevo] Repositorio bare ~/.cfg ya existe; omitiendo clonación dotbare."
fi

# 3. Configurar git remoto y branch
echo "==> [niri-nuevo] Configurando git remoto y rama..."
(cd /tmp && sudo -u "$TARGET_USER" -H git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*')
(cd /tmp && sudo -u "$TARGET_USER" -H git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" config status.showUntrackedFiles no)
if [[ -n "$ASKPASS" ]]; then
    (cd /tmp && sudo -u "$TARGET_USER" -H env GIT_ASKPASS="$ASKPASS" git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" fetch origin 2>/dev/null || true)
else
    (cd /tmp && sudo -u "$TARGET_USER" -H git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" fetch origin 2>/dev/null || true)
fi
(cd /tmp && sudo -u "$TARGET_USER" -H git --git-dir="$TARGET_HOME/.cfg" --work-tree="$TARGET_HOME" branch -u "origin/$PROFILE_BRANCH" "$PROFILE_BRANCH" 2>/dev/null || true)

# 4. Sincronización idempotente con ravn-home-sync (capa común)
if [[ -x "/usr/share/ravn/common/bin/ravn-home-sync" ]]; then
    echo "==> [niri-nuevo] Ejecutando /usr/share/ravn/common/bin/ravn-home-sync..."
    (cd /tmp && sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" "/usr/share/ravn/common/bin/ravn-home-sync")
elif command -v ravn-home-sync >/dev/null 2>&1; then
    echo "==> [niri-nuevo] Ejecutando ravn-home-sync..."
    (cd /tmp && sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" ravn-home-sync)
elif sudo test -x "$TARGET_HOME/.local/bin/ravn-home-sync"; then
    echo "==> [niri-nuevo] Ejecutando ~/.local/bin/ravn-home-sync..."
    (cd /tmp && sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" "$TARGET_HOME/.local/bin/ravn-home-sync")
else
    echo "==> [niri-nuevo] AVISO: ravn-home-sync no disponible en PATH ni en /usr/share/ravn."
fi

# 5. Sincronización idempotente con ravn-niri-sync (capa niri)
if [[ -x "/usr/share/ravn/niri/bin/ravn-niri-sync" ]]; then
    echo "==> [niri-nuevo] Ejecutando /usr/share/ravn/niri/bin/ravn-niri-sync..."
    (cd /tmp && sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" "/usr/share/ravn/niri/bin/ravn-niri-sync")
elif command -v ravn-niri-sync >/dev/null 2>&1; then
    echo "==> [niri-nuevo] Ejecutando ravn-niri-sync..."
    (cd /tmp && sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" ravn-niri-sync)
elif sudo test -x "$TARGET_HOME/.local/bin/ravn-niri-sync"; then
    echo "==> [niri-nuevo] Ejecutando ~/.local/bin/ravn-niri-sync..."
    (cd /tmp && sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" "$TARGET_HOME/.local/bin/ravn-niri-sync")
else
    echo "==> [niri-nuevo] AVISO: ravn-niri-sync no disponible en PATH ni en /usr/share/ravn."
fi

# 6. Postinstalación de niri (gsettings, matugen, validación)
if [[ -x "/usr/share/ravn/niri/bin/niri-dotfiles-postinstall" ]]; then
    echo "==> [niri-nuevo] Ejecutando postinstalación niri..."
    (cd /tmp && sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" XDG_RUNTIME_DIR="/run/user/$TARGET_UID" "/usr/share/ravn/niri/bin/niri-dotfiles-postinstall")
elif sudo test -x "$TARGET_HOME/.local/bin/niri-dotfiles-postinstall"; then
    echo "==> [niri-nuevo] Ejecutando ~/.local/bin/niri-dotfiles-postinstall..."
    (cd /tmp && sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" XDG_RUNTIME_DIR="/run/user/$TARGET_UID" "$TARGET_HOME/.local/bin/niri-dotfiles-postinstall")
fi

echo "==> [niri-nuevo] Despliegue nuevo completado."

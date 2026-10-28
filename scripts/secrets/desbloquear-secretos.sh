#!/usr/bin/env bash
#
# desbloquear-secretos.sh: Descifra los secretos del sistema con 'age' y los
# aprovisiona en sus ubicaciones canónicas para todos los usuarios gestionados.
#
# Soporta tanto ejecución interactiva en terminal como variable AGE_PASSPHRASE.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_STAGING=""
ENCRYPTED_FILE="${SCRIPT_DIR}/secrets.tar.gz.age"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --export-staging)
            EXPORT_STAGING="${2:-/tmp/staging-secrets}"
            shift 2 || shift 1
            ;;
        -h|--help)
            echo "Uso: $0 [OPCIONES] [ARCHIVO_AGE]"
            echo "  --export-staging [DIR]  Descifra y exporta los secretos a una carpeta para modificarlos/añadir nuevos"
            exit 0
            ;;
        *)
            ENCRYPTED_FILE="$1"
            shift
            ;;
    esac
done

if ! command -v age >/dev/null 2>&1; then
    echo "[!] 'age' no está instalado. Instalándolo con pacman..."
    sudo pacman -S --needed --noconfirm age
fi

if [[ ! -f "$ENCRYPTED_FILE" ]]; then
    echo "ERROR: Archivo cifrado no encontrado: $ENCRYPTED_FILE"
    exit 1
fi

echo "=================================================================="
echo "        DESBLOQUEO Y APROVISIONAMIENTO DE SECRETOS (AGE)          "
echo "=================================================================="
echo "Archivo: $ENCRYPTED_FILE"
echo ""

# 1. Crear directorio temporal seguro en memoria RAM (/dev/shm)
TMP_DIR="$(mktemp -d --tmpdir=/dev/shm secrets-decrypted-XXXXXX)"
chmod 700 "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[1/6] Descifrando secretos en memoria segura (/dev/shm)..."
if [[ -n "${AGE_PASSPHRASE:-}" ]]; then
    python3 -c '
import pty, os, time, sys
passphrase = os.environ["AGE_PASSPHRASE"]
pid, fd = pty.fork()
if pid == 0:
    os.execlp("age", "age", "-d", "-o", sys.argv[2], sys.argv[1])
else:
    time.sleep(0.1)
    os.write(fd, (passphrase + "\n").encode())
    _, status = os.waitpid(pid, 0)
    sys.exit(os.waitstatus_to_exitcode(status))
' "$ENCRYPTED_FILE" "$TMP_DIR/bundle.tar.gz"
else
    age -d -o "$TMP_DIR/bundle.tar.gz" "$ENCRYPTED_FILE"
fi

tar -xzf "$TMP_DIR/bundle.tar.gz" -C "$TMP_DIR"
rm -f "$TMP_DIR/bundle.tar.gz"

echo "[✓] Descifrado completado en memoria."

# Modo Exportación para edición/mantenimiento
if [[ -n "$EXPORT_STAGING" ]]; then
    mkdir -p "$EXPORT_STAGING"
    # "dir/." copia también las entradas ocultas (.gnupg, .ssh, .grokbot);
    # un glob "dir/*" sin dotglob las omitiría (issue #78).
    cp -a "$TMP_DIR"/. "$EXPORT_STAGING"/
    chmod -R 700 "$EXPORT_STAGING"
    echo ""
    echo "=================================================================="
    echo " [✓] Secretos exportados exitosamente para mantenimiento en:"
    echo "     $EXPORT_STAGING"
    echo "=================================================================="
    echo "Puedes añadir, editar o eliminar los archivos que necesites."
    echo "Cuando finalices, vuelve a cifrar el paquete ejecutando:"
    echo "  ${SCRIPT_DIR}/recifrar-interactivo.sh $EXPORT_STAGING"
    echo "=================================================================="
    exit 0
fi

# 2. Desplegar Rclone Global (/etc/rclone/rclone.conf)
echo "[2/6] Configurando Rclone multi-usuario (/etc/rclone/rclone.conf)..."
if [[ -f "$TMP_DIR/rclone/rclone.conf" ]]; then
    sudo mkdir -p /etc/rclone
    sudo cp "$TMP_DIR/rclone/rclone.conf" /etc/rclone/rclone.conf
    sudo chown root:wheel /etc/rclone/rclone.conf
    sudo chmod 0660 /etc/rclone/rclone.conf

    # Variables de entorno globales
    sudo mkdir -p /etc/environment.d /etc/profile.d /etc/fish/conf.d
    sudo bash -c 'echo "RCLONE_CONFIG=/etc/rclone/rclone.conf" > /etc/environment.d/20-rclone.conf'
    sudo bash -c 'echo "export RCLONE_CONFIG=/etc/rclone/rclone.conf" > /etc/profile.d/20-rclone.sh'
    sudo bash -c 'echo "set -gx RCLONE_CONFIG /etc/rclone/rclone.conf" > /etc/fish/conf.d/rclone.fish'
    sudo chmod 644 /etc/environment.d/20-rclone.conf /etc/profile.d/20-rclone.sh /etc/fish/conf.d/rclone.fish
    echo "   [✓] /etc/rclone/rclone.conf desplegado (0660 root:wheel)."
fi

# 3. Desplegar Git Suite, SSH y GitHub CLI a todos los usuarios gestionados y /etc/skel
echo "[3/6] Aprovisionando Git Suite, SSH y GitHub CLI a usuarios y /etc/skel..."

USERS=(/home/* /etc/skel)

for target in "${USERS[@]}"; do
    [[ ! -d "$target" ]] && continue
    user_name="$(basename "$target")"

    # A. Enlace a Rclone
    sudo mkdir -p "$target/.config/rclone"
    sudo ln -sfn /etc/rclone/rclone.conf "$target/.config/rclone/rclone.conf"

    # B. Llaves SSH para commit signing y git push
    if [[ -d "$TMP_DIR/.ssh" ]]; then
        sudo mkdir -p "$target/.ssh"
        sudo cp -a "$TMP_DIR/.ssh/." "$target/.ssh/"
        sudo chmod 700 "$target/.ssh"
        [[ -f "$target/.ssh/id_ed25519" ]] && sudo chmod 600 "$target/.ssh/id_ed25519"
        [[ -f "$target/.ssh/id_ed25519.pub" ]] && sudo chmod 644 "$target/.ssh/id_ed25519.pub"
        [[ -f "$target/.ssh/config" ]] && sudo chmod 600 "$target/.ssh/config"
        [[ -f "$target/.ssh/known_hosts" ]] && sudo chmod 644 "$target/.ssh/known_hosts"
        
        # Configurar allowed_signers para verificación local de firmas SSH
        if [[ -f "$target/.ssh/id_ed25519.pub" ]]; then
            pub_content="$(cat "$target/.ssh/id_ed25519.pub")"
            sudo bash -c "echo '25asab015@ujmd.edu.sv namespaces=\"git\" $pub_content' > '$target/.ssh/allowed_signers'"
            sudo chmod 644 "$target/.ssh/allowed_signers"
        fi
    fi

    # C. GitHub CLI (autenticación instantánea)
    if [[ -d "$TMP_DIR/gh" ]]; then
        sudo mkdir -p "$target/.config/gh"
        sudo cp -a "$TMP_DIR/gh/." "$target/.config/gh/"
        sudo chmod 700 "$target/.config/gh"
        [[ -f "$target/.config/gh/hosts.yml" ]] && sudo chmod 600 "$target/.config/gh/hosts.yml"
        [[ -f "$target/.config/gh/config.yml" ]] && sudo chmod 600 "$target/.config/gh/config.yml"
    fi

    # D. Git Config Suite unificada
    sudo mkdir -p "$target/.config/git"
    if [[ -d "$TMP_DIR/git" ]]; then
        for f in delta.gitconfig gitattributes.global gitconfig_aliases gitignore.global shell_aliases; do
            if [[ -f "$TMP_DIR/git/$f" ]]; then
                sudo cp "$TMP_DIR/git/$f" "$target/.config/git/$f"
                sudo chmod 644 "$target/.config/git/$f"
            fi
        done
    fi

    # Generar ~/.config/git/config limpio y portable
    sudo bash -c "cat > '$target/.config/git/config'" << 'GITCONF_EOF'
[apply]
    whitespace = fix

[color]
    ui = true

[commit]
    verbose = true
    gpgsign = true

[core]
    editor = nvim
    pager = delta
    excludesFile = ~/.config/git/gitignore.global
    attributesFile = ~/.config/git/gitattributes.global
    ignorecase = false
    whitespace = fix,-indent-with-non-tab,trailing-space,cr-at-eol

[credential]
    helper = cache --timeout 3600

[credential "https://github.com"]
    helper =
    helper = !gh auth git-credential

[credential "https://gist.github.com"]
    helper =
    helper = !gh auth git-credential

[diff]
    colorMoved = default
    algorithm = histogram
    mnemonicPrefix = true

[fetch]
    prune = true
    output = compact

[help]
    autocorrect = 1

[init]
    defaultBranch = master

[interactive]
    diffFilter = delta --color-only --highlight-removed

[log]
    decorate = short

[merge]
    conflictstyle = diff3
    log = true
    stat = true

[protocol]
    version = 2

[pull]
    rebase = true
    ff = only

[push]
    autoSetupRemote = true
    default = current

[rebase]
    autoStash = true
    updateRefs = true
    autoSquash = true

[include]
    path = ~/.config/git/delta.gitconfig
    path = ~/.config/git/gitconfig_aliases

[delta]
    features = mantis-shrimp

[rerere]
    enabled = true
    autoupdate = true

[column]
    ui = auto

[branch]
    sort = -committerdate

[tag]
    sort = -version:refname
    gpgsign = true

[safe]
    directory = *

[user]
    name = Roberto Flores
    email = 25asab015@ujmd.edu.sv
    signingkey = ~/.ssh/id_ed25519.pub

[gpg]
    format = ssh

[gpg "ssh"]
    allowedSignersFile = ~/.ssh/allowed_signers
GITCONF_EOF

    sudo chmod 644 "$target/.config/git/config"

    # Ajustar propiedad del usuario
    if [[ "$target" != "/etc/skel" ]]; then
        sudo chown -R "$user_name:$user_name" "$target/.config" "$target/.ssh" 2>/dev/null || true
    fi
    echo "   [✓] Configuración aplicada a: $target"
done

# 4. Restaurar llaves y datos personales de omarchy
echo "[4/6] Restaurando llaves personales avanzadas para omarchy..."
if [[ -d "$TMP_DIR/.gnupg" ]]; then
    cp -a "$TMP_DIR/.gnupg" /home/omarchy/
    chmod 700 /home/omarchy/.gnupg
    find /home/omarchy/.gnupg -type f -exec chmod 600 {} + 2>/dev/null || true
    find /home/omarchy/.gnupg -type d -exec chmod 700 {} + 2>/dev/null || true
    echo "   [✓] GnuPG restaurado."
fi

if [[ -d "$TMP_DIR/keyrings" ]]; then
    mkdir -p /home/omarchy/.local/share/keyrings
    cp -a "$TMP_DIR/keyrings/." /home/omarchy/.local/share/keyrings/
    chmod 700 /home/omarchy/.local/share/keyrings
    chmod 600 /home/omarchy/.local/share/keyrings/* 2>/dev/null || true
    echo "   [✓] Keyrings restaurados."
fi

if [[ -d "$TMP_DIR/ticktick-cli" ]]; then
    mkdir -p /home/omarchy/.config/ticktick-cli
    cp -a "$TMP_DIR/ticktick-cli/." /home/omarchy/.config/ticktick-cli/
    echo "   [✓] TickTick CLI config restaurada."
fi

if [[ -d "$TMP_DIR/.grokbot" ]]; then
    cp -a "$TMP_DIR/.grokbot" /home/omarchy/
    echo "   [✓] GrokBot config restaurada."
fi

# 5. Verificación de salud (Smoke Tests)
echo "[5/6] Ejecutando pruebas de verificación (Smoke Tests)..."
echo "  • Rclone listremotes:"
rclone listremotes

echo "  • GitHub Auth Status:"
gh auth status 2>&1 | grep -E "(Logged in|Token scopes)" || true

echo "  • Git Identity:"
git config --get user.name
git config --get user.email
git config --get user.signingkey

echo "[6/6] Limpiando memoria..."
# trap garantiza la eliminación de TMP_DIR

echo ""
echo "=================================================================="
echo "    [✓] SECRETOS DESBLOQUEADOS Y APLICADOS EXITOSAMENTE           "
echo "=================================================================="

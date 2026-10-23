#!/usr/bin/env bash
set -euo pipefail

# Directorio donde se encuentran los repositorios clonados.
# Cada repo sigue la rama `personal` de su fork (origin); StatIndet es `upstream`, solo lectura.
SRC_DIR="${SRC_DIR:-/opt/src}"

# Compilar como el dueño de las fuentes; root solo instala.
BUILD_USER="${BUILD_USER:-$(stat -c %U "$SRC_DIR")}"
BUILD_HOME="$(getent passwd "$BUILD_USER" | cut -d: -f6)"

as_builder() {
    runuser -u "$BUILD_USER" -- env -i \
        HOME="$BUILD_HOME" USER="$BUILD_USER" LOGNAME="$BUILD_USER" \
        PATH=/usr/local/bin:/usr/bin:/bin \
        CARGO_NET_GIT_FETCH_WITH_CLI=true \
        bash -c "$1"
}

echo "================================================================"
echo "  Actualizando Niri Desktop desde los forks (rama personal)       "
echo "================================================================"

# 1. Actualizar niri-edge
if [ -d "$SRC_DIR/niri-edge" ]; then
    echo ">> [1/7] Actualizando niri-edge..."
    as_builder "cd '$SRC_DIR/niri-edge' && git fetch origin && { git merge --ff-only '@{u}' || echo 'Advertencia: avance rápido no posible; se compila la versión local'; } && cargo build --release"
    install -Dm755 "$SRC_DIR/niri-edge/target/release/niri" /usr/local/bin/niri
fi

# 2. Actualizar key-cli
if [ -d "$SRC_DIR/key-cli" ]; then
    echo ">> [2/7] Actualizando key-cli..."
    as_builder "cd '$SRC_DIR/key-cli' && git fetch origin && { git merge --ff-only '@{u}' || echo 'Advertencia: avance rápido no posible; se compila la versión local'; } && /usr/bin/python3 scripts/installer.py"
    as_builder "cd '$SRC_DIR/key-cli' && /usr/bin/python3 scripts/installer.py --keyboard enable --acknowledge-keyboard-access --apply"
    setcap 'cap_dac_read_search=ep' /usr/local/libexec/key-cli/key-cpu-power
    if [ -f "$SRC_DIR/key-cli/completions/key.fish" ]; then
        install -Dm644 "$SRC_DIR/key-cli/completions/key.fish" /usr/share/fish/vendor_completions.d/key.fish
    fi
fi

# 3. Actualizar quickshell (Clavis Shell)
if [ -d "$SRC_DIR/quickshell" ]; then
    echo ">> [3/7] Actualizando Clavis Shell..."
    as_builder "cd '$SRC_DIR/quickshell' && git fetch origin && { git merge --ff-only '@{u}' || echo 'Advertencia: avance rápido no posible; se compila la versión local'; } \
        && { /usr/bin/python3 scripts/release.py bundle-resources --cache /tmp/clavis-cache || true; } \
        && cmake -S . -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_TESTING=OFF \
            -DCMAKE_INSTALL_PREFIX=/usr \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCLAVIS_CONFIG_INSTALL_DIR=/etc/xdg/quickshell/clavis \
            -DPython3_EXECUTABLE=/usr/bin/python3 \
        && cmake --build build"
    cmake --install "$SRC_DIR/quickshell/build"
fi

# 4. Actualizar clavis-fish-theme
if [ -d "$SRC_DIR/clavis-fish-theme" ]; then
    echo ">> [4/7] Actualizando clavis-fish-theme..."
    as_builder "cd '$SRC_DIR/clavis-fish-theme' && git fetch origin && { git merge --ff-only '@{u}' || echo 'Advertencia: avance rápido no posible; se compila la versión local'; } && cargo build --release --locked"
    install -Dm755 "$SRC_DIR/clavis-fish-theme/target/release/clavis-fish-theme" /usr/local/bin/clavis-fish-theme
fi

# 5. Actualizar my_zsh_prompt (Prompt C++ para Zsh)
if [ -d "$SRC_DIR/my_zsh_prompt" ]; then
    echo ">> [5/7] Actualizando my_zsh_prompt..."
    as_builder "cd '$SRC_DIR/my_zsh_prompt' && git fetch origin && { git merge --ff-only '@{u}' || echo 'Advertencia: avance rápido no posible; se compila la versión local'; } && make clean && make"
    install -Dm755 "$SRC_DIR/my_zsh_prompt/prompt_dev" /usr/local/bin/prompt
fi

# 6. Actualizar SPlayer-Next (reproductor de música)
if [ -d "$SRC_DIR/SPlayer-Next" ]; then
    echo ">> [6/7] Actualizando SPlayer-Next..."
    as_builder "cd '$SRC_DIR/SPlayer-Next' && git fetch origin && { git merge --ff-only '@{u}' || echo 'Advertencia: avance rápido no posible; se compila la versión local'; } \
        && sed -i 's/locale: \"zh-CN\"/locale: \"en-US\"/' src/i18n/index.ts \
        && sed -i 's/ref<LocaleCode>(\"zh-CN\")/ref<LocaleCode>(\"en-US\")/' src/stores/settings.ts \
        && sed -i 's/defaultValue: \"zh-CN\"/defaultValue: \"en-US\"/' src/settings/categories/general.ts \
        && sed -i 's/currentLocale: LocaleCode = \"zh-CN\"/currentLocale: LocaleCode = \"en-US\"/' electron/main/utils/i18n.ts \
        && pnpm build:unpack"
    mkdir -p /opt/SPlayer-Next
    cp -a "$SRC_DIR/SPlayer-Next/dist/linux-unpacked/." /opt/SPlayer-Next/
    chmod 755 /opt/SPlayer-Next/chrome-sandbox
    ln -sf /opt/SPlayer-Next/SPlayer-Next /usr/local/bin/splayer-next
fi

# 7. Actualizar paquetes del sistema
echo ">> [7/7] Verificando paquetes del sistema..."
pacman -Syu --needed --noconfirm

echo "================================================================"
echo "  Actualización completada exitosamente.                        "
echo "================================================================"

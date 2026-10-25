# Guía de Archivos de Usuario ($HOME) y Configuración Multi-Usuario
## Entorno de Desarrollo Google Antigravity, Android Studio y Jetpack Compose en Arch Linux / Omarchy

Este documento detalla qué componentes del stack residen en el espacio de usuario (`$HOME`), cuáles están a nivel global de sistema (`/usr`, `/opt`) y los métodos exactos para hacer que todo el entorno esté disponible para otros usuarios existentes o nuevos en esta misma máquina.

---

## 1. Inventario: Sistema Global vs. Espacio de Usuario ($HOME)

| Componente | Nivel | Ubicación Física | ¿Disponible para otros usuarios hoy? |
| :--- | :---: | :--- | :---: |
| **Google Antigravity 2.0 (GUI)** | Sistema | `/opt/Antigravity/` & `/usr/bin/antigravity` | ✅ Sí (Acceso global) |
| **Google Antigravity IDE** | Sistema | `/opt/antigravity-ide/` & `/usr/bin/antigravity-ide` | ✅ Sí (Acceso global) |
| **Android Studio Canary (Rabbit 2/3)** | Sistema | `/opt/android-studio-canary/` & `/usr/bin/android-studio-canary` | ✅ Sí (Acceso global) |
| **Google Cloud CLI (`gcloud`)** | Sistema | `/opt/google-cloud-cli/` & `/usr/bin/gcloud` | ✅ Sí (`/etc/profile.d/google-cloud-cli.sh`) |
| **Java JDK 21 & JDK 17** | Sistema | `/usr/lib/jvm/java-{21,17}-openjdk/` & `/usr/bin/java` | ✅ Sí (Gestionado con `archlinux-java`) |
| **Kotlin Compiler (`kotlinc`)** | Sistema | `/usr/bin/kotlinc` & `/usr/share/kotlin` | ✅ Sí (Acceso global) |
| **Gradle** | Sistema | `/usr/bin/gradle` & `/usr/share/gradle` | ✅ Sí (`/etc/profile.d/gradle.sh`) |
| **Android Tools (`adb`, `fastboot`)** | Sistema | `/usr/bin/adb`, `/usr/bin/fastboot` | ✅ Sí (Requiere grupo de hardware) |
| **Reglas Udev (`android-udev`)** | Sistema | `/usr/lib/udev/rules.d/51-android.rules` | ✅ Sí (Daemon udev del kernel) |
| **Virtualización KVM** | Kernel | `/dev/kvm` | ✅ Sí (Requiere grupo `kvm`) |
| **Google Chrome** | Sistema / Usuario | Binario en `/usr/bin/google-chrome-stable`<br>Alias/Symlink en `~/.local/bin/google-chrome` | ⚠️ Solo comando `google-chrome-stable` (el alias `google-chrome` está en el HOME de origen) |
| **Antigravity CLI (`agy`)** | Usuario | `~/.local/bin/agy`<br>`~/.local/share/mise/installs/antigravity-cli/` | ❌ No (Vive dentro de `~/.local/`) |
| **Firebase Tools CLI (`firebase`)** | Usuario | `~/.local/bin/firebase`<br>`~/.local/share/mise/` | ❌ No (Vive dentro de `~/.local/`) |
| **Python SDK (`google-antigravity`)** | Usuario | `~/.local/lib/python3.15/site-packages/` | ❌ No (Instalado con `pip --user`) |
| **Variables Android en shell** | Usuario | `~/.bashrc` (`ANDROID_HOME`, `PATH`) | ❌ No (Archivo privado del usuario) |
| **Android SDK (Plataformas y AVDs)** | Usuario | `~/Android/Sdk` y `~/.android` | ❌ No (Descargado por cada usuario) |
| **Sesiones y Tokens OAuth** | Usuario | `~/.config/Antigravity/`<br>`~/.config/Google/` | ❌ No (Privado y específico de cada cuenta) |

---

## 2. Detalle de Archivos y Carpetas en el `$HOME` del Usuario

### A. Scripts y Wrappers de Ejecución (`$HOME/.local/bin/`)
* **`~/.local/bin/agy`**: Wrapper generado por `omarchy-mise-install` que delega la ejecución de Antigravity CLI a través del gestor `mise`.
* **`~/.local/bin/firebase`**: Wrapper generado por `omarchy-mise-install` para invocar Firebase CLI desde Node/Mise.
* **`~/.local/bin/google-chrome`**: Enlace simbólico hacia `/usr/bin/google-chrome-stable` para que scripts y herramientas que buscan `google-chrome` lo encuentren de forma estandarizada.

### B. Herramientas gestionadas en espacio de usuario (`$HOME/.local/share/mise/`)
* Contiene las versiones compiladas o empaquetadas en modo usuario de `antigravity-cli`, plugins de Node y binarios auxiliares.

### C. Módulos de Python (`$HOME/.local/lib/python3.*/site-packages/`)
* Contiene la librería `google-antigravity` y dependencias (`google-genai`, `mcp`, `pydantic`, `uvicorn`, etc.) instaladas con `pip install --user`.

### D. Variables de Entorno del Shell (`$HOME/.bashrc`)
Se insertaron las líneas estándar de desarrollo Android:
```bash
# --- ANDROID & JAVA ENVIRONMENT ---
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_USER_HOME="$HOME/.android"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
# --- FIN ANDROID & JAVA ENVIRONMENT ---
```

### E. SDK de Android y Emuladores (`$HOME/Android/Sdk` y `$HOME/.android/`)
* `Android/Sdk/`: Directorio donde Android Studio descarga `build-tools`, `platform-tools`, `platforms/android-XX` e imágenes del emulador (`system-images/`).
* `.android/`: Almacena la llave de depuración `debug.keystore` y las definiciones de los dispositivos virtuales (AVDs).

---

## 3. ¿Cómo hacer que todo esté disponible para otros usuarios en esta PC?

Existen tres formas complementarias:
1. **Hacer las herramientas globales a nivel de sistema** (Recomendado para binarios y variables comunes).
2. **Plantilla automática para usuarios futuros** (`/etc/skel`).
3. **Script de aprovisionamiento rápido para usuarios existentes**.

---

### Solución A: Hacer que los comandos sean 100% globales a nivel de sistema

Esta solución requiere permisos `sudo` una sola vez y hace que cualquier usuario en la PC tenga acceso inmediato sin tener que duplicar configuraciones.

#### 1. Crear symlink global para Google Chrome
Para que el comando `google-chrome` exista en todo el sistema sin depender del `~/.local/bin` del primer usuario:
```bash
sudo ln -sf /usr/bin/google-chrome-stable /usr/local/bin/google-chrome
```

#### 2. Variables de entorno globales para Android en `/etc/profile.d/`
El archivo [`/etc/profile.d/android.sh`](file:///etc/profile.d/android.sh) centraliza las variables globales del sistema:
```bash
sudo tee /etc/profile.d/android.sh << 'EOF'
# Configuración global Android SDK & Proyectos Compartidos
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_USER_HOME="$HOME/.android"
export ANDROID_PROJECTS_DIR="/z/android-projects"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
EOF

sudo chmod +x /etc/profile.d/android.sh
```
*Cualquier usuario que inicie sesión en Bash, Zsh, Fish o terminal gráfica cargará estas variables automáticamente.*

#### 3. Instalar el SDK de Python de forma global
Para que `import google.antigravity` funcione para cualquier usuario sin tener que hacer `pip install --user`:
```bash
sudo pip install --break-system-packages google-antigravity
```

#### 4. Compartir el Android SDK y el Espacio Colaborativo (/z) con pj-domina-rf-shared_dir
Para evitar descargar 20 a 50 GB por cada usuario y habilitar un espacio de trabajo sin restricciones de permisos:

```bash
# Configuración automática con SGID (2770) + ACLs + demonios inotify en tiempo real
sudo ./pj-domina-rf-shared_dir/shared_dir /z /opt/android-sdk /z/android-projects
```
*Cualquier usuario o agente en el grupo `wheel` puede crear, modificar y eliminar libremente dentro de `/z` y `/z/android-projects`.*

# 4. Modificar /etc/profile.d/android.sh para apuntar al SDK compartido
sudo tee /etc/profile.d/android.sh << 'EOF'
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_USER_HOME="$HOME/.android"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
EOF
```
*En Android Studio, todos los usuarios verán `/opt/android-sdk` como la ruta del SDK.*

---

### Solución B: Configurar la plantilla `/etc/skel` para nuevos usuarios

`/etc/skel/` es la plantilla que el comando `useradd` copia automáticamente cada vez que se crea una nueva cuenta en Linux.

Para que cualquier nuevo usuario tenga el entorno listo al crearse:
```bash
# Agregar variables al .bashrc de la plantilla
if ! grep -q "ANDROID_HOME" /etc/skel/.bashrc; then
sudo tee -a /etc/skel/.bashrc << 'EOF'

# --- ANDROID & JAVA ENVIRONMENT ---
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_USER_HOME="$HOME/.android"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
# --- FIN ANDROID & JAVA ENVIRONMENT ---
EOF
fi
```

---

### Solución C: Script de Onboarding para usuarios existentes en esta PC

Si ya existe otro usuario en la PC (por ejemplo `juan` o `maria`), ese usuario solo necesita ejecutar este script una sola vez en su sesión (sin necesidad de permisos root):

Guarda este script como `setup_other_user.sh`:
```bash
#!/usr/bin/env bash
set -e

echo "==> Configurando entorno de desarrollo Google/Android para $(whoami)..."

# 1. Variables en ~/.bashrc
BASHRC="$HOME/.bashrc"
if ! grep -q "ANDROID_HOME" "$BASHRC" 2>/dev/null; then
    cat << 'EOF' >> "$BASHRC"

# --- ANDROID & JAVA ENVIRONMENT ---
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_USER_HOME="$HOME/.android"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
# --- FIN ANDROID & JAVA ENVIRONMENT ---
EOF
    echo "[OK] Variables de entorno añadidas a ~/.bashrc"
fi

# 2. Herramientas CLI de usuario (agy y firebase) vía omarchy/mise
mkdir -p "$HOME/.local/bin"
if command -v omarchy-mise-install &>/dev/null; then
    omarchy-mise-install antigravity-cli agy
    omarchy-mise-install npm:firebase-tools firebase
    echo "[OK] 'agy' y 'firebase' vinculados vía omarchy-mise-install"
elif command -v mise &>/dev/null; then
    mise use -g antigravity-cli
    mise use -g firebase
    echo "[OK] 'agy' y 'firebase' vinculados vía mise"
fi

# 3. Google Chrome alias de usuario si no está en /usr/local/bin
if ! command -v google-chrome &>/dev/null && [[ -f /usr/bin/google-chrome-stable ]]; then
    ln -sf /usr/bin/google-chrome-stable "$HOME/.local/bin/google-chrome"
    echo "[OK] Symlink de google-chrome creado en ~/.local/bin"
fi

# 4. Python SDK
if ! python3 -c "import google.antigravity" &>/dev/null; then
    python3 -m pip install --user --upgrade google-antigravity
    echo "[OK] google-antigravity Python SDK instalado"
fi

echo "==> ¡Listo! Todo el entorno está configurado para $(whoami)."
```

---

## 4. Grupos de Sistema Necesarios para Nuevos Usuarios

Para que otro usuario pueda usar emuladores y depuración USB en Android sin pedir sudo:

```bash
# KVM (Para emuladores AVD acelerados por GPU/CPU)
sudo usermod -aG kvm <OTRO_USUARIO>

# Depuración USB con ADB (evita error "adb: no permissions")
sudo usermod -aG adbusers <OTRO_USUARIO> 2>/dev/null || sudo usermod -aG plugdev <OTRO_USUARIO> 2>/dev/null || true
```

---

## 5. Resumen de Ejecutables ya listos para Cualquier Usuario

Cualquier usuario en el equipo puede invocar directamente en su terminal:

```bash
antigravity            # Abre Google Antigravity 2.0 (Orquestador Multi-Agente)
antigravity-ide        # Abre Google Antigravity IDE (VS Code modificado)
android-studio-canary  # Abre Android Studio Rabbit con soporte BYOA
gcloud                 # Google Cloud CLI (disponible para todos)
java -version          # OpenJDK 21
kotlinc -version       # Compilador de Kotlin 2.4+
gradle --version       # Gradle 9.8+
adb devices            # Android Debug Bridge
```

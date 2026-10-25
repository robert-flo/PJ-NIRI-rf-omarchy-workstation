# Prompt de Ejecución para Agente: Instalación One-Shot de la Suite Google, Android Studio Canary (BYOA) y Entorno Global Multi-Usuario (Compose/Kotlin/Java/Fish/Bash)

> **Rol del agente:** Actúa como un Administrador de Sistemas Linux Senior e Ingeniero de Entornos de Desarrollo especializado en Arch Linux, Omarchy y el ecosistema de desarrollo móvil y de IA de Google. Tu prioridad es garantizar una instalación limpia en modalidad **One-Shot**, con arquitectura **Global Multi-Usuario por Defecto**, verificar la autenticidad de las fuentes oficiales de Google, compilar los paquetes AUR sin privilegios de root en almacenamiento persistente (previniendo desbordamientos de RAM en `/tmp`), configurar dependencias sin conflictos, activar el espacio colaborativo compartido en `/z` mediante `pj-domina-rf-shared_dir` y dejar el entorno listo para cualquier usuario o agente (tanto en Bash como en Fish Shell).

---

## 1. Contexto y Objetivos Técnicos ("El Porqué" de cada componente)

El usuario requiere replicar en cualquier equipo con **Arch Linux** (o derivados como **Omarchy**) el stack completo de herramientas oficiales de Google:

### A. Ecosistema Google Antigravity

1. **Google Antigravity 2.0 (`aur/antigravity`)**:
   - *Por qué:* Es la plataforma de escritorio para orquestación multi-agente paralela de Google (Canvas de agentes, terminales auxiliares, subagentes en background y visualización de artefactos).
   - *Origen oficial:* Distribuido en Google Cloud Storage (`https://storage.googleapis.com/antigravity-public/antigravity-hub/...`).
   - *Binario:* [`/usr/bin/antigravity`](file:///usr/bin/antigravity).

2. **Google Antigravity IDE (`aur/antigravity-ide`)**:
   - *Por qué:* Es el entorno interactivo de código basado en VS Code con capacidades nativas de predicción de intención (Tab Autocomplete/Supercomplete), edición guiada (`Ctrl+I`) y panel colaborativo de agente.
   - *Origen oficial:* Distribuido desde servidores de Google (`https://dl.google.com/release2/...`).
   - *Detalle técnico:* El PKGBUILD oficial de AUR sustituye el binario bundled de `@parcel/watcher` por una versión estable (`2.5.6`), previniendo caídas con `SIGTRAP` al cerrar el editor en Linux.
   - *Binario:* [`/usr/bin/antigravity-ide`](file:///usr/bin/antigravity-ide).

3. **Google Antigravity CLI (`aur/antigravity-cli`)**:
   - *Por qué:* Es la interfaz de línea de comandos (`agy`) para interacción rápida con agentes directamente desde la terminal, automatización con slash commands (`/goal`, `/plan`, `/schedule`), gestión de subagentes y sidecars sin abrir la interfaz gráfica pesada.
   - *Origen oficial:* Google Cloud Storage (`https://storage.googleapis.com/antigravity-public/antigravity-cli/...`).
   - *Binario:* [`/usr/bin/agy`](file:///usr/bin/agy).

4. **Python SDK de Antigravity (`google-antigravity`)**:
   - *Por qué:* Permite crear scripts en Python para orquestar agentes, registrar herramientas MCP personalizadas y automatizar pipelines con la API de Antigravity (`import google.antigravity`).

---

### B. IDE Android y Soporte BYOA (Bring Your Own Agent)

5. **Android Studio Rabbit 2 Canary (`aur/android-studio-canary`)**:
   - *Por qué:* El usuario necesita conectar su cuenta de **Google Antigravity** directamente a Android Studio. La funcionalidad **BYOA (Bring Your Own Agent)** se introdujo de manera preliminar exclusivamente en el canal **Canary** a partir de **Android Studio Rabbit 2** (versión `2026.2.2+`), permitiendo vincular agentes de Google Antigravity, Claude Agent y Codex en `Settings > Tools > AI > Agents`.
   - *Origen oficial:* Repositorio oficial de IDEs de Google (`https://edgedl.me.gvt1.com/android/studio/ide-zips/.../android-studio-rabbit2-canary...`).
   - *Binario:* [`/usr/bin/android-studio-canary`](file:///usr/bin/android-studio-canary).

---

### C. Servicios Cloud, Firebase y Navegador Oficial

6. **Google Cloud CLI (`aur/google-cloud-cli`)**:
   - *Por qué:* Proporciona el comando `gcloud` oficial para interactuar con Google Cloud Platform, Vertex AI, Cloud Functions, Cloud Run y almacenamiento en GCS.

7. **Firebase Tools (`aur/firebase-tools-bin`)**:
   - *Por qué:* El CLI oficial de Firebase (`firebase`) para emuladores locales de Firestore/Auth/Functions, despliegues y configuración en proyectos móviles.

8. **Google Chrome (`aur/google-chrome`)**:
   - *Por qué:* Navegador oficial necesario para los flujos de autenticación OAuth de Google Cloud y Android Studio, además de depuración web e inspección con DevTools.

---

### D. Stack de Desarrollo: Android, Kotlin, Java y Jetpack Compose

9. **Entorno Java: OpenJDK 21 y OpenJDK 17 (`jdk21-openjdk`, `jdk17-openjdk`)**:
   - *Por qué:* Android Studio Rabbit y las versiones actuales de Gradle (8.5+ y 9.x) utilizan Java 21 como estándar. Proyectos existentes con Android Gradle Plugin (AGP) 8.0 a 8.3 requieren Java 17. Disponer de ambos y gestionarlos con `archlinux-java` evita errores de incompatibilidad de bytecode.

10. **Compilador y Herramientas Kotlin (`kotlin`)**:
    - *Por qué:* Proporciona `kotlinc` y el entorno de ejecución para scripts `.kts` y Kotlin Multiplatform.

11. **Sistema de Construcción Gradle (`gradle`)**:
    - *Por qué:* Permite construir, probar y depurar proyectos Android y JVM directamente desde la terminal sin depender exclusivamente del wrapper `./gradlew`.

12. **Herramientas de Plataforma Android (`android-tools`)**:
    - *Por qué:* Incluye `adb` (Android Debug Bridge) y `fastboot` para depuración en emuladores o dispositivos físicos, instalación de APKs e inspección de logs (`adb logcat`).

13. **Reglas de Acceso Udev (`android-udev`)**:
    - *Por qué:* Evita el error habitual de `adb: no permissions` al conectar dispositivos físicos reales (Pixel, Samsung, Xiaomi, Motorola, etc.) vía USB.

14. **Virtualización por Hardware (KVM - `/dev/kvm`)**:
    - *Por qué:* Fundamental para que el Android Emulator (AVD) se ejecute a 60 fps con aceleración nativa por hardware.

---

## 2. ¿Se necesita algo extra para Jetpack Compose?

**A nivel de Sistema Operativo: NO.** No se requiere ningún paquete binario adicional en Arch Linux.

### Justificación técnica:
1. **Compilador integrado en Kotlin 2.0+:** Desde Kotlin 2.0+, Google y JetBrains fusionaron el compilador de Compose directamente dentro del compilador de Kotlin (`org.jetbrains.kotlin.plugin.compose`).
2. **Aceleración Gráfica y Previews:** 
   - `@Preview` y **Live Edit** corren en Android Studio usando layoutlib sobre la JVM y la GPU del sistema.
   - El stack gráfico estándar (`mesa`, `vulkan-intel` / `vulkan-radeon` / NVIDIA) junto con `/dev/kvm` satisfacen todos los requerimientos de Compose a 60/120 fps.

### Configuración estándar en `build.gradle.kts` (Module :app):
```kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose) // Plugin oficial de Compose en Kotlin 2.0+
}

android {
    buildFeatures {
        compose = true
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.02.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
```

---

## 3. Arquitectura Omarchy: Criterio de Selección entre Mise y AUR

En sistemas Omarchy (y distribuciones modernas basadas en Arch), existe una separación deliberada entre herramientas de usuario y componentes del sistema:

| Categoría | Herramientas | Gestor Recomendado | Razón Técnica |
| :--- | :--- | :--- | :--- |
| **Agentes de IA y CLI de Usuario** | `antigravity-cli` (`agy`), `firebase-tools`, `claude`, `codex` | **`mise`** (`omarchy-mise-install`) | Omarchy gestiona los agentes CLI en espacio de usuario (`~/.local/share/mise`). Permite actualizaciones inmediatas con el alias `mup` (`mise up`) sin requerir `sudo` ni recompilar PKGBUILDs de AUR. |
| **Aplicaciones Gráficas (GUI / IDEs)** | `antigravity` (2.0), `antigravity-ide`, `android-studio-canary`, `google-chrome` | **`AUR` / `pacman`** | Requieren integración profunda con el escritorio: archivos `.desktop` en `/usr/share/applications/`, iconos en `/usr/share/pixmaps/`, reglas de ventana en Hyprland, sandboxing y directorios en `/opt/`. |
| **Reglas de Hardware y Sistema** | `android-udev`, `android-tools`, KVM | **`Pacman` (Arch oficial)** | `android-udev` instala reglas en `/usr/lib/udev/rules.d/51-android.rules` y recarga el daemon del kernel `udevadm`. Esto **requiere permisos de root**. |
| **Servicios Cloud y Perfil Global** | `google-cloud-cli` (`gcloud`) | **`AUR`** | La versión de AUR proporciona la configuración de entorno en `/etc/profile.d/google-cloud-cli.sh`, autocompletado en zsh/bash a nivel de sistema y módulos binarios compilados. |
| **Runtimes de Desarrollo** | `jdk21-openjdk`, `jdk17-openjdk`, `kotlin`, `gradle` | **Híbrido (`pacman` + `mise`)** | Pacman garantiza que el daemon de Gradle y Android Studio encuentren los JDKs del sistema; `mise` permite alternar versiones por carpeta (`mise local java@17`). |

> **Comportamiento inteligente del script:** El script [`install_full_stack.sh`](install_full_stack.sh) detecta automáticamente si `omarchy-mise-install` o `mise` están disponibles. Si es así, instala `agy` y `firebase` a través de `mise`; si se ejecuta en una máquina Arch estándar sin `mise`, recurre de manera transparente a compilar `aur/antigravity-cli` y `aur/firebase-tools-bin`.

---

## 4. Reglas Estrictas de Seguridad para el Agente

1. **NUNCA pedir ni registrar contraseñas de `sudo` en texto plano.**
   - En Omarchy/Hyprland (o entornos sin TTY directo), invocar la instalación a través del lanzador de terminal flotante de Omarchy:
     ```bash
     omarchy launch floating terminal with presentation "./install_full_stack.sh"
     ```
   - Esto permite que el usuario ingrese su contraseña de forma segura en una ventana de terminal aislada.
2. **NUNCA ejecutar `makepkg` como `root`.** La descarga y empaquetado de AUR se realiza siempre como usuario estándar.
3. **Idempotencia:** Comprobar siempre con `pacman -Q` o `command -v` si el paquete o binario ya existe antes de volver a descargarlo o compilarlo.

---

## 5. Métodos de Ejecución

### Método A: Ejecución mediante Script Automatizado One-Shot (Recomendado)

En esta misma carpeta se encuentra el script [`install_full_stack.sh`](install_full_stack.sh), que contiene la lógica idempotente para instalar solo lo que falte:

```bash
chmod +x ./install_full_stack.sh
./install_full_stack.sh
```

En entornos Omarchy / Hyprland:
```bash
omarchy launch floating terminal with presentation "./install_full_stack.sh"
```

---

### Método B: Ejecución Manual Paso a Paso

#### Paso 1: Dependencias del sistema, Java, Kotlin, Android, Fish y Monitorización ACL
```bash
sudo pacman -S --needed --noconfirm \
    base-devel git curl unzip zip jq python python-pip python-installer \
    jdk21-openjdk jdk17-openjdk kotlin gradle android-tools android-udev \
    alsa-lib gtk3 nss nspr webkit2gtk-4.1 libsecret libsoup3 mesa vulkan-icd-loader \
    acl inotify-tools fish

# Configurar Java 21 como predeterminado
sudo archlinux-java set java-21-openjdk
```

#### Paso 2: Compilación e instalación segura de paquetes AUR en disco persistente
> [!IMPORTANT]
> **Prevención de fallo de cuota:** NUNCA compiles en `/tmp` (tmpfs de RAM de 7.8 GB). Usa `$HOME/.cache/google_dev_stack_build` con más de 180 GB libres.

```bash
BUILD_CACHE="${HOME}/.cache/google_dev_stack_build"
mkdir -p "$BUILD_CACHE/tmp"
export TMPDIR="$BUILD_CACHE/tmp"
BUILD_DIR=$(mktemp -d -p "$BUILD_CACHE" build_XXXXXX)
cd "$BUILD_DIR"

# Helper: compila, instala con pacman -U y purga fuentes inmediatamente
build_and_install() {
    local repo="$1"
    git clone "https://aur.archlinux.org/${repo}.git"
    cd "$repo"
    makepkg -s --noconfirm
    sudo pacman -U --needed --noconfirm *.pkg.tar.zst
    cd "$BUILD_DIR"
    rm -rf "$repo"
}

# 1. Antigravity 2.0
pacman -Q antigravity || build_and_install "antigravity"

# 2. Antigravity IDE
pacman -Q antigravity-ide || build_and_install "antigravity-ide"

# 3. Android Studio Canary (Rabbit con BYOA)
pacman -Q android-studio-canary || build_and_install "android-studio-canary"

# 4. Google Cloud CLI
pacman -Q google-cloud-cli || build_and_install "google-cloud-cli"

# Limpieza final del directorio temporal de construcción
rm -rf "$BUILD_DIR"
```

#### Paso 3: Python SDK y Symlink global de Chrome
```bash
# SDK de Python global
sudo pip install --break-system-packages google-antigravity || python3 -m pip install --user google-antigravity

# Symlink global de Chrome
sudo ln -sf /usr/bin/google-chrome-stable /usr/local/bin/google-chrome
```

#### Paso 5: Variables de Entorno Globales y Directorios Compartidos (Multi-Usuario)
Para que todos los usuarios de la PC (incluyendo usuarios de **Fish** y **Bash** como `niri`) compartan el SDK y los proyectos sin duplicar gigabytes ni tener problemas de permisos:

```bash
# 1. Configurar directorios compartidos con pj-domina-rf-shared_dir (SGID + ACLs + inotify)
sudo ./pj-domina-rf-shared_dir/shared_dir /z /opt/android-sdk /z/android-projects

# 2. Configurar perfil global /etc/profile.d/android.sh
sudo tee /etc/profile.d/android.sh << 'EOF'
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_USER_HOME="$HOME/.android"
export ANDROID_PROJECTS_DIR="/z/android-projects"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
EOF
sudo chmod +x /etc/profile.d/android.sh

# 3. Para cualquier nuevo usuario o agente (soporta Bash y Fish Shell):
./nuevo-usuario.sh
```

---

## 6. Instrucciones para Conectar Antigravity en Android Studio Rabbit 2

1. Iniciar Android Studio Canary:
   ```bash
   android-studio-canary &
   ```
2. En la barra lateral o durante el asistente de bienvenida, abrir el panel de **AI / Agent**.
3. Seleccionar **Google Antigravity** de la lista de agentes BYOA (Google Antigravity, Claude Agent, Codex).
4. Si no aparece en la ventana principal, dirigirse a:
   `Settings` → `Tools` → `AI` → `Agents`
5. Seleccionar **Google Antigravity** e iniciar sesión con tu cuenta o ingresar tu API Key.

---

## 7. Matriz de Comprobación Final

Ejecutar para certificar el estado de todos los componentes:

```bash
# Ecosistema Antigravity
/usr/bin/antigravity --version || true
which antigravity-ide
which agy && agy --help
python3 -c "import google.antigravity; print('SDK OK')"

# Android Studio Canary
which android-studio-canary

# Cloud y Firebase
gcloud --version
firebase --version
which google-chrome

# Toolchain Kotlin / Java / Gradle
java -version
kotlinc -version
gradle --version

# Herramientas Android y Virtualización KVM
adb version
ls -la /dev/kvm

# Espacio Compartido Global (pj-domina-rf-shared_dir) y Shells
ls -ld /z /opt/android-sdk /z/android-projects
systemctl is-active z-perms.service android-sdk-perms.service android-projects-perms.service
fish --version
```

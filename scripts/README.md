# Scripts del Sistema y Automatización

Este directorio contiene los módulos, asistentes y herramientas operativas subyacentes de la estación de trabajo.

> [!NOTE]
> **Puerta de Entrada Canónica:**
> No es necesario invocar manualmente los scripts de estos subdirectorios para tareas comunes. Utiliza la interfaz estandarizada del [`Makefile`](file:///home/rollo/Work/tries/2026-11-08-robert-flo-PJ-NIRI-rf-omarchy-workstation/Makefile) en la raíz del repositorio (`make install`, `make converge`, `make doctor`, etc.). Consulta [[07.5 - Catalogo y Manual de Herramientas CLI del Playbook]] para el catálogo detallado.

---

## 🧭 Mapa de Módulos Operativos

### 1. `scripts/omarchy-onboarding/`
* **`onboard-machine.sh`**: Asistente de onboarding en 4 etapas para incorporar cualquier máquina Arch Linux en Modo PADRE (DEV) o Modo HIJA (Cliente). Expuesto como CLI global `/usr/local/bin/omarchy-onboard` y vía `make install` / `make install-padre` / `make install-hija`.
* **`converge-workstation.sh`**: Script de convergencia directa de capas 01 a 07. Aplica configuración de forma estrictamente idempotente. Expuesto vía `make converge` y `make audit` (`--dry-run`).
* **`ci-idempotencia.sh`**: Suite de validación de inocuidad e idempotencia estricta. Expuesto vía `make test-idempotence`.

### 2. `scripts/secrets/`
* **`desbloquear-secretos.sh`**: Desbloquea en `/dev/shm` y aprovisiona claves SSH, Rclone y Git Suite a todos los usuarios. Expuesto vía `make secrets`.
* **`cifrar-secretos.sh`**: Empaqueta y recifra el bundle en `scripts/secrets/secrets.tar.gz.age`. Expuesto vía `make lock-secrets`.
* **`probar-descifrado.sh`**: Valida que el paquete cifrado sea legible con la frase de paso. Expuesto vía `make test-secrets`.

### 3. `scripts/forkhub/`
* **`forkhub`**: CLI de auditoría y sincronización de los 15 repositorios de la flota de forks. Expuesto vía `make forks` y `make forks-sync`.
* **`auditar-forks.sh`**: Comprueba el estado upstream contra la GitHub API. Expuesto vía `make forks-audit`.

### 4. `scripts/sync-stack/`
* **`sync-all` / `synchub`**: Orquestación de sincronización con escudos de seguridad activos. Expuesto vía `make sync`.
* **`sync-status`**: Dashboard de estado de almacenamiento `/z-drive`, Google Drive y disco Btrfs. Expuesto vía `make sync-status`.

### 5. `scripts/sandbox-btrfs/`
* **`sandbox-btrfs-manager.sh`**: Gestor de subvolúmenes y snapshots para el usuario desechable `sandbox`. Expuesto vía `make sandbox-status` y `make sandbox-reset`.

---

## `pj-trio` (movido)

`pj-trio`, `trio-status`, `trio-pm-prompt.md` y `trio.conf.example` ya no viven acá. La herramienta canónica es [robert-flo/ravn-trio](https://github.com/robert-flo/ravn-trio) (v0.1.2), empaquetada por `ravn-trio-arch` como `/usr/bin/pj-trio` (`trio-status` = `pj-trio status`; prompt y config en `/usr/share/ravn/trio/`). Documentación y pruebas: en ese repo.

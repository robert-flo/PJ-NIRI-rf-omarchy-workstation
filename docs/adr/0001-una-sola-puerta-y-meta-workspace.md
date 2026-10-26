---
title: "ADR 0001: Una Sola Puerta a la Raíz y Meta-Workspace /z/pj-omarchy"
tags:
  - adr
  - arquitectura
  - pacman
  - workspace
  - onboarding
aliases:
  - ADR 0001
  - Una Sola Puerta y Meta-Workspace
date: 2026-10-26
---

# 🏛️ ADR 0001: Una Sola Puerta a la Raíz y Meta-Workspace /z/pj-omarchy

> [!NOTE]
> **Navegación y Metadatos:**
> * **Estado:** Aceptado (Vigente).
> * **Fecha:** 2026-10-26.
> * **Decisor:** Roberto Flores.
> * **Tickets relacionados:** #17 (Una sola fuente de binarios), #18-#20 (Empaquetado formal), #23 (Meta-workspace `/z/pj-omarchy`), #24 (Onboarding convergente), #25 (Consolidación y ADR).
> * **Vault de Referencia:** [[00.0 - Mapa General del Sistema (MOC)|Mapa General del Sistema (MOC)]] y [[01.9 - Onboarding del Sistema y Repositorio Personal (Modo Padre DEV vs Hija)|01.9 Onboarding de Máquinas]].

---

## 1. Estado

**Aceptado**. Esta decisión consolida y formaliza los acuerdos tomados en los tickets #17 y #23, implementados operativamente en #24 y registrados en #25. Rige de forma vinculante sobre toda la arquitectura del vault `PJ-NIRI-rf-omarchy-workstation` y sus playbooks asociados.

---

## 2. Contexto

Hasta la fecha, la estación de trabajo presentaba fricciones de diseño por solapamiento de incumbencias entre la capa del sistema operativo base, los dotfiles y el repositorio paraguas de desarrollo:

1. **Escrituras descontroladas en la raíz (`/`):** Varios scripts y playbooks instalaban ejecutables manualmente en `/usr/local/bin/` mediante copias directas alojadas en `assets/system/usr/local/bin/`. Esto rompía el principio de trazabilidad del gestor de paquetes de la distribución, generando binarios huérfanos difíciles de auditar, actualizar o remover limpiamente.
2. **Conflicto de soberanía sobre `/etc/pacman.conf`:** El archivo `/etc/pacman.conf` es mantenido por el fork de Omarchy a través del comando `omarchy refresh pacman`. Mantener una copia espejo estática en `assets/system/etc/pacman.conf` provocaba que cualquier cambio upstream o sincronización de paquetes pisara ajustes locales o viceversa.
3. **Dispersión de repositorios en el almacenamiento compartido (`/z/`):** No existía una convención estricta sobre la pertenencia y ciclo de vida de los repositorios clonados en `/z/`. Algunos scripts clonaban subproyectos sueltos (`fo-omarchy`, `fork-docs`) de forma dispersa, dificultando la apertura integral del ecosistema en entornos de desarrollo modernos (VSCode, Cursor, Google Antigravity IDE) y complicando la gestión de permisos multiusuario.
4. **Acoplamiento erróneo de roles de máquina al usuario (`gracie`):** Existía documentación y lógica histórica que asumía que la máquina con rol PADRE (Estación de Desarrollo) debía tener obligatoriamente un usuario llamado `gracie`, cuando en la realidad operativa el usuario administrador estándar es `omarchy` y cualquier computadora de la flota (con cualquier nombre de usuario) puede asumir el rol PADRE o HIJA.

Hacía falta definir con precisión milimétrica la política de gobernanza sobre `/`, delimitar qué entra a `assets/system/`, unificar los proyectos bajo un único meta-workspace y asegurar que el proceso de onboarding sea estricta y predeciblemente idempotente.

---

## 3. Decisión

Frente a este contexto, acordamos e implementamos los siguientes lineamientos arquitectónicos fundamentales:

### 3.1. Pacman es la Única Puerta de Entrada a `/` (#17)

* **Exclusividad de Pacman:** La única puerta legítima de instalación y modificación de archivos en el sistema raíz (`/`, `/usr/bin`, `/usr/share`, `/opt`, etc.) es el gestor de paquetes oficial `pacman`.
* **Publicación delegada en `pj-omarchy`:** Los paquetes binarios oficiales del ecosistema son compilados, empaquetados y distribuidos exclusivamente por el proyecto `pj-omarchy` hacia el repositorio público [robert-flo/omarchy-personal-repo](https://github.com/robert-flo/omarchy-personal-repo).
* **Workstation como orquestador:** Este repositorio (`PJ-NIRI-rf-omarchy-workstation`) es un **orquestador y playbook** de configuración. Delega el ciclo de vida del software en `pacman` y en `pj-omarchy`; **no compila ni publica paquetes directamente hacia `/`**.
* **Alcance estricto de `assets/system/`:** La carpeta `assets/system/` queda reservada **exclusivamente para archivos de configuración del sistema en `/etc/`** y para elementos huérfanos indispensables que aún no cuenten con un paquete pacman formal. Se prohíbe mantener en ella binarios o scripts ejecutables terminados que pertenezcan a la distribución de paquetes.

### 3.2. Excepción Validada: El Meta-Workspace `/z/pj-omarchy` (#23)

Por decisión expresa de Roberto, se valida una única excepción a la regla general de no mantener clonaciones fijas:
* Se establece el meta-workspace centralizado **`/z/pj-omarchy`** (clon de [robert-flo/pj-omarchy](https://github.com/robert-flo/pj-omarchy)) como el hogar de todos los repositorios del fork.
* Para preservar la retrocompatibilidad con scripts existentes, paths canónicos y el CLI `fork-docs`, se crean y mantienen los siguientes symlinks en `/z/`:
  * `/z/fo-omarchy` ➔ `/z/pj-omarchy/fo-omarchy`
  * `/z/fork-docs` ➔ `/z/pj-omarchy/rf-fork-docs`
* **Regla para otros repositorios:** Todo repositorio ajeno a este meta-workspace (proyectos experimentales, spikes, pruebas de concepto) se clona obligatoriamente mediante la herramienta `try` dentro de `~/Work/tries/`. Queda prohibido clonar repositorios sueltos en la raíz de `/z/` o en los `$HOME` de los usuarios.

### 3.3. Único Dueño de `/z/pj-omarchy`: El CLI `./pj`

* El único dueño y responsable de la estructura interna de `/z/pj-omarchy` y de sus sub-repositorios es el CLI `./pj` perteneciente a dicho proyecto.
* El comando canónico `./pj listo` es el encargado de consultar `proyecto.yml` y clonar o alinear todos los repositorios del ecosistema.
* El asistente de onboarding de workstation no inventa clonaciones manuales individuales: se limita a invocar `./pj listo`. Únicamente en caso de contingencia o ausencia de `./pj`, utiliza un mecanismo de fallback que lee `proyecto.yml` para clonar exclusivamente los repositorios faltantes.
* `pj-omarchy.code-workspace` (el workspace multi-raíz con los nombres descriptivos y `settings`) **es de pj-omarchy**: está versionado en `robert-flo/pj-omarchy` (`!pj-omarchy.code-workspace` en su `.gitignore`, listado en `extras:` de `proyecto.yml`). Workstation no lo genera, no lo fusiona ni lo modifica: PADRE solo verifica que exista después de `./pj listo` y, si falta, avisa sin crearlo.

### 3.4. Soberanía de `/etc/pacman.conf` y Drop-in Modular

* `/etc/pacman.conf` pertenece al fork de Omarchy y es actualizado por `omarchy refresh pacman`. Workstation **no debe poseer ni sobreescribir este archivo**.
* El repositorio personal `[omarchy-personal]` se inyecta de forma limpia y desacoplada mediante un archivo drop-in en `/etc/pacman.d/omarchy-personal.conf`.
* En equipos con rol PADRE (DEV), la directiva `IgnorePkg = omarchy-dev omarchy-settings-dev` se gestiona hoy mediante el hook temporal de workstation (no el del fork), hasta que el fork lo asuma de forma nativa en [robert-flo/omarchy#82](https://github.com/robert-flo/omarchy/issues/82).
* La inclusión de la directiva `Include = /etc/pacman.d/omarchy-personal.conf` dentro de `/etc/pacman.conf` que ejecuta transitoriamente workstation es una medida temporal hasta que se complete la integración nativa en [robert-flo/omarchy#82](https://github.com/robert-flo/omarchy/issues/82).
* El archivo espejo huérfano `assets/system/etc/pacman.conf` queda **eliminado definitivamente** de este vault.

### 3.5. Onboarding Idempotente y Fuente Única para `omarchy-onboard`

* **Fuente única autoritativa:** El único origen del asistente de onboarding es `scripts/omarchy-onboarding/onboard-machine.sh`. Se elimina la copia huérfana en `assets/system/usr/local/bin/omarchy-onboard`.
* **Empaquetado diferido:** El empaquetado formal del script para ser instalado bajo `/usr/local/bin/` mediante pacman queda delegado a los tickets #18-#20.
* **Cero escrituras descontroladas:** Fuera de pacman, el onboarding no realiza ninguna nueva escritura sobre `/`, limitándose exclusivamente a las operaciones operativas preexistentes:
  1. Configuración del sistema de git: `safe.directory` en `git config --system`: se comprueba con `--get-all` y solo se añade la entrada si falta; si hay duplicados, se deduplica (`--unset-all` y se vuelven a añadir las entradas únicas). Así una segunda corrida no cambia nada.
  2. Ajuste de permisos SGID `2775`, grupo `wheel` y ACLs por defecto bajo `/z/`.
  3. Creación de los enlaces simbólicos de retrocompatibilidad en `/z/`.
* **Convergencia absoluta:** El onboarding es rigurosamente idempotente: ejecutarlo dos veces consecutivas en la misma máquina no altera nada la segunda vez, convergiendo siempre al mismo estado deseado sin efectos secundarios.

### 3.6. Topología de Usuarios Agnóstica de Roles

* El usuario de administración y mantenimiento del sistema es exclusivamente **`omarchy`**.
* Se depuran todas las referencias al usuario legado `gracie` en la documentación del core y en las reglas del vault.
* La asignación de roles de máquina (PADRE DEV vs. HIJA Cliente) es completamente ortogonal al nombre de usuario: cualquier equipo de la flota puede asumir cualquiera de los dos roles independientemente del usuario administrador que lo configure.

---

## 4. Consecuencias

### Positivas

* **Claridad de responsabilidades:** Separación tajante entre la orquestación declarativa (`PJ-NIRI-rf-omarchy-workstation`) y el empaquetado/distribución de software (`pj-omarchy` + `omarchy-personal-repo`).
* **Sistema limpio y mantenible:** Fin de los binarios huérfanos en `/usr/local/bin/` y de los pisotones sobre `/etc/pacman.conf`. El fork puede actualizar pacman con total libertad sin desconfigurar el repositorio personal.
* **Ergonomía de desarrollo:** El meta-workspace `/z/pj-omarchy` permite abrir todos los componentes del sistema como un único proyecto multi-raíz en el IDE preferido, manteniendo compatibilidad total con scripts legacy mediante symlinks.
* **Convergencia real:** El script de onboarding puede correrse periódicamente o tras una actualización sin temor a desconfigurar la máquina.

### Transitorias y Mitigaciones

* Mientras se completa [robert-flo/omarchy#82](https://github.com/robert-flo/omarchy/issues/82), el onboarding inserta transitoriamente el `Include` hacia `/etc/pacman.d/omarchy-personal.conf` en `/etc/pacman.conf`. Una vez mergeado el PR correspondiente en el fork, dicha lógica podrá retirarse.
* Mientras se implementan los tickets #18-#20, el script de onboarding se ejecuta directamente desde `scripts/omarchy-onboarding/onboard-machine.sh` sin instalarse como binario de sistema huérfano.

### Pendientes Fuera de Alcance (Out of Scope)

* **Ticket #32:** Extracción y desacople del script y watcher `shared_dir` / `fix_shared_dir_perms.sh`.
* **Ticket #33:** Manejo, tratamiento y políticas de almacenamiento de archivos pesados multimedia (`.mp4`).

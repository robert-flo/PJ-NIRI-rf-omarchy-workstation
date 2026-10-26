# Scripts del Sistema y Automatización

Este directorio contiene herramientas y utilidades operativas de la estación de trabajo.

## `pj-trio`

`pj-trio` es un inicializador idempotente para herdr que prepara un workspace con tres tabs dedicados e independientes a pantalla completa para los roles del trío: **PM**, **WK** y **RV**.

### Uso

```bash
pj-trio [--dry-run] <proyecto> <ticket> [--repo <miembro>]
```

- `<proyecto>`: Ruta al checkout git del proyecto meta (`pj-*`) o nombre del directorio. Si pasás únicamente el nombre, se resuelve contra la variable de entorno `$PJ_TRIO_ROOT`, o por defecto contra el directorio padre de `$PWD` o `~/.cache/ravn-piloto`.
- `<ticket>`: Identificador del issue o ticket a trabajar (por ejemplo `18` o `999`).
- `--repo <miembro>`: Repositorio miembro opcional (hermano del proyecto meta, subdirectorio o ruta absoluta). Se añade al espacio de trabajo del agente mediante `--add-dir`.
- `--dry-run`: Muestra los comandos y la topología sin aplicarlos.

### Disposición de Tabs (Topología)

En lugar de dividir un único tab en paneles pequeños, `pj-trio` crea o reutiliza tres tabs en herdr a pantalla completa dentro del workspace, garantizando que cada agente tenga el espacio completo de terminal sin splits:

- **pm**: Tab raíz para la coordinación y gestión del ticket. Panel etiquetado como `PM-<ticket>`, con agente `pm-<ticket>`.
- **wk**: Tab dedicado a la implementación de cambios y código. Panel etiquetado como `WK-<ticket>`, con agente `wk-<ticket>`.
- **rv**: Tab dedicado a la revisión técnica y validación de entregas. Panel etiquetado como `RV-<ticket>`, con agente `rv-<ticket>`.

El directorio de trabajo (`cwd`) para los tres tabs es la carpeta del proyecto meta (`pj-*`). Si se especifica un repositorio miembro con `--repo`, la ruta resuelta se inyecta como contexto adicional al agente mediante `--add-dir <ruta-miembro>`.

### Etiquetado de Workspace

La etiqueta del espacio de trabajo se genera automáticamente:
- Sin `--repo`: `trio <proyecto>#<ticket>`
- Con `--repo`: `trio <proyecto>/<miembro>#<ticket>`

### Configuración de Kinds por Rol

El tipo de agente a iniciar en cada rol se define mediante variables en un archivo de configuración:

- `PM_KIND`: Kind del agente para el rol PM (por ejemplo `"agy"`).
- `WK_KIND`: Kind del agente para el rol WK (por ejemplo `"agy"`).
- `RV_KIND`: Kind del agente para el rol RV (por ejemplo `"agy"`).

Si dejás un valor vacío (`""`), el tab correspondiente queda en un shell interactivo para que arranques el proceso manualmente.

El archivo de configuración se busca en el siguiente orden de precedencia:

1. Ruta definida en la variable de entorno `PJ_TRIO_CONFIG`.
2. Archivo `.trio/trio.conf` dentro del proyecto objetivo.
3. Archivo del sistema `/usr/share/ravn/trio/trio.conf`.
4. Archivo de respaldo `scripts/trio.conf.example`.
5. Archivo `scripts/trio.conf.example` dentro del proyecto objetivo.

### Rol Directo y Verificación

Cuando el kind configurado es `agy`, cada tab arranca el agente directamente con su rol asignado (`--agent PM-<proyecto>`, `--agent WK-<proyecto>`, `--agent RV-<proyecto>`), sin pasar por menús interactivos ni selectores manuales.

Antes de inicializar, `pj-trio` consulta `agy agents` para verificar que los agentes del proyecto existan en el sistema (registrados globalmente en `~/.gemini/config/agents/`). Si alguno falta, la ejecución se detiene con un mensaje de error explícito.

### Integración Idempotente con herdr

Antes de arrancar los agentes, `pj-trio` verifica mediante `herdr integration status` que la integración correspondiente al kind (por ejemplo `antigravity-cli` para `agy`) esté instalada. Si falta, la instala automáticamente mediante `herdr integration install <target>`.

### Idempotencia

Si ejecutás `pj-trio` una segunda vez con los mismos argumentos:
- Detecta el workspace existente por su etiqueta.
- Reutiliza los tabs `pm`, `wk` y `rv` ya creados.
- No duplica procesos ni paneles de agentes en ejecución.
- Mantiene exactamente 3 tabs y 3 paneles en total, sin splits residuales ni paneles huérfanos.

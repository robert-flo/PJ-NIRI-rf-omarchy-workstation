# Scripts del Sistema y Automatización

Este directorio contiene herramientas y utilidades operativas de la estación de trabajo.

## `pj-trio`

`pj-trio` es un inicializador idempotente para herdr que prepara un workspace con tres paneles dedicados a los roles del trío: **PM**, **WK** y **RV**.

### Uso

```bash
pj-trio [--dry-run] <repo> <ticket>
```

- `<repo>`: Ruta a un checkout git o nombre de directorio ubicado bajo `$PJ_TRIO_ROOT`.
- `<ticket>`: Identificador del issue o ticket a trabajar (por ejemplo `18` o `59`).
- `--dry-run`: Muestra los comandos que se ejecutarían sin aplicarlos.

### Disposición de paneles (Topología)

El comando configura el directorio raíz del repositorio como `cwd` para todos los paneles y genera la siguiente estructura:

- **PM-<ticket>** (izquierda): Panel raíz para la coordinación y gestión del ticket.
- **WK-<ticket>** (superior derecha): Panel para la implementación de cambios.
- **RV-<ticket>** (inferior derecha): Panel para la revisión y validación de entregas.

### Configuración de Kinds por Rol

El agente a iniciar en cada rol se define mediante variables en un archivo de configuración:

- `PM_KIND`: Kind del agente para el rol PM.
- `WK_KIND`: Kind del agente para el rol WK.
- `RV_KIND`: Kind del agente para el rol RV.

Si dejás un valor vacío (`""`), el panel correspondiente queda en un shell interactivo para que arranques el proceso manualmente.

El archivo de configuración se busca en el siguiente orden de precedencia:

1. Ruta definida en la variable de entorno `PJ_TRIO_CONFIG`.
2. Archivo `.trio/trio.conf` dentro del repositorio objetivo.
3. Archivo del sistema `/usr/share/ravn/trio/trio.conf`.
4. Archivo de respaldo `scripts/trio.conf.example`.

### Idempotencia

Si ejecutás `pj-trio` una segunda vez sobre el mismo `<repo>` y `<ticket>`, detectará el workspace existente por su etiqueta (`trio <repo>#<ticket>`), reutilizará los paneles ya creados y no duplicará procesos ni splits.

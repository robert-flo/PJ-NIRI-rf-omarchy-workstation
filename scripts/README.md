# Scripts del Sistema y Automatización

Este directorio contiene herramientas y utilidades operativas de la estación de trabajo.

## `pj-trio`

`pj-trio` es un inicializador idempotente para herdr que prepara un workspace con tres tabs dedicados a los roles del trío: **PM**, **WK** y **RV**.

### Uso

```bash
pj-trio [--dry-run] <repo> <ticket>
```

- `<repo>`: Ruta a un checkout git o nombre de directorio ubicado bajo `$PJ_TRIO_ROOT`.
- `<ticket>`: Identificador del issue o ticket a trabajar (por ejemplo `18` o `59`).
- `--dry-run`: Muestra los comandos que se ejecutarían sin aplicarlos.

### Disposición de tabs (Topología)

El comando configura el directorio raíz del repositorio como `cwd` para todos los tabs y paneles, generando un tab individual a pantalla completa para cada rol (sin divisiones de pantalla):

- **Tab 'pm'**: contiene el panel **PM-<ticket>** para la coordinación y gestión del ticket.
- **Tab 'wk'**: contiene el panel **WK-<ticket>** para la implementación de cambios.
- **Tab 'rv'**: contiene el panel **RV-<ticket>** para la revisión y validación de entregas.

### Integración de agentes

Antes de arrancar los agentes, `pj-trio` verifica de forma idempotente el estado de integración en herdr mediante `herdr integration status`. Si la integración correspondiente al kind configurado no está instalada, ejecuta la instalación respectiva (por ejemplo `herdr integration install antigravity-cli`) para que el seguimiento de estado del agente opere correctamente.

### Configuración de Kinds por Rol

El agente a iniciar en cada rol se define mediante variables en un archivo de configuración:

- `PM_KIND`: Kind del agente para el rol PM.
- `WK_KIND`: Kind del agente para el rol WK.
- `RV_KIND`: Kind del agente para el rol RV.

Si dejás un valor vacío (`""`), el tab correspondiente queda en un shell interactivo para que arranques el proceso manualmente.

El archivo de configuración se busca en el siguiente orden de precedencia:

1. Ruta definida en la variable de entorno `PJ_TRIO_CONFIG`.
2. Archivo `.trio/trio.conf` dentro del repositorio objetivo.
3. Archivo del sistema `/usr/share/ravn/trio/trio.conf`.
4. Archivo de respaldo `scripts/trio.conf.example`.

### Idempotencia

Si ejecutás `pj-trio` una segunda vez sobre el mismo `<repo>` y `<ticket>`, detectará el workspace existente por su etiqueta (`trio <repo>#<ticket>`), reutilizará los tabs y paneles ya creados y no duplicará tabs, paneles ni procesos.

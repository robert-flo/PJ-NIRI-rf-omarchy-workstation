# Onboarding de Máquinas — Omarchy Personal Fork

Script canónico de incorporación, aprovisionamiento y convergencia de máquinas al ecosistema del Fork Personal de Omarchy.

La fuente única de verdad es `scripts/omarchy-onboarding/onboard-machine.sh` (los tickets #18-#20 abordan el empaquetado formal del comando en el sistema).

## Instalación como comando global

Para enlazar este script en `/usr/local/bin/omarchy-onboard`:

```bash
sudo ln -sfn "$PWD/scripts/omarchy-onboarding/onboard-machine.sh" /usr/local/bin/omarchy-onboard
```

## Uso

```bash
# Modo PADRE (Estación de Desarrollo / Modo DEV)
sudo omarchy-onboard --padre

# Modo HIJA (Cliente de Producción)
sudo omarchy-onboard --hija

# Modo HIJA con aprovisionamiento de usuarios adicionales
sudo omarchy-onboard --hija --users "omarchy niri nyxuri"

# Simulación sin modificaciones (dry-run, no requiere root)
./scripts/omarchy-onboarding/onboard-machine.sh --padre --dry-run
./scripts/omarchy-onboarding/onboard-machine.sh --hija --dry-run
```

## `~/.bashrc` y el overlay ravn-omarchy (paso 2.10, ambos roles)

Los alias `rs`/`ri` y el env/rc del overlay viven en `/usr/share/ravn/omarchy/bash/{env,rc}`. Solo se cargan si `~/.bashrc` tiene estas dos líneas del stub canónico `/usr/share/omarchy/etc-overrides/dot.bashrc`:

```bash
# justo después de la línea de env-bootstrap
[[ -r /usr/share/ravn/omarchy/bash/env ]] && source /usr/share/ravn/omarchy/bash/env
# justo después de: source "$OMARCHY_PATH/default/bash/rc"
[[ -r /usr/share/ravn/omarchy/bash/rc ]] && source /usr/share/ravn/omarchy/bash/rc
```

El stub se copia a `/etc/skel` solo para usuarios nuevos, así que un `~/.bashrc` hecho con un stub viejo se queda sin ellas. Por eso el onboarding (lógica en `bashrc-overlay.sh`) las asegura en el `~/.bashrc` del usuario que lo ejecuta. El paso es idempotente:

- Si `~/.bashrc` no existe, lo crea copiando el stub.
- Si existe, inserta cada línea que falte justo después de su ancla. Si el ancla no está, la línea env va antes de `[[ $- != *i* ]] && return` (o al principio del archivo) y la línea rc va al final.
- Respalda en `~/.bashrc.bak-<timestamp>` solo cuando cambia algo. Nunca borra contenido del usuario. Si `~/.bashrc` es un symlink (dotfiles), edita el archivo de destino.
- Cuenta en "Cambios aplicados" y respeta `--dry-run`.

Test con fixtures: `bash tests/onboarding/test-bashrc-overlay.sh` (corre en CI).

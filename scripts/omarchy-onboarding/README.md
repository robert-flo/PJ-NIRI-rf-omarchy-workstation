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

---
title: "Piloto Home: Línea Base con Método Actual en niri-test (#41)"
tags:
  - piloto-home
  - btrfs
  - dotbare
  - niri-test
  - linea-base
aliases:
  - 41-linea-base
  - Línea Base niri-test
date: 2026-10-26
---

# Piloto Home: Línea Base con Método Actual en `niri-test` (#41)

> **Contexto:** Sub-issue de [#40](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/40) (spec madre [#17](https://github.com/robert-flo/PJ-NIRI-rf-omarchy-workstation/issues/17)).
> **Objetivo:** Aislar el entorno del usuario desechable `niri-test` en su propio subvolumen Btrfs, realizar wipe completo, desplegar los dotfiles según el método actual documentado en el vault (capas 06.1 y 06.2 con dotbare + repo `robert-flo/niri-dotfiles` rama `master` + postinstall) y capturar un snapshot read-only `snap-niri-test-metodo-actual` como línea base inmutable para el experimento por capas.

---

## 1. Hallazgo de Aislamiento Btrfs

### Estado Inicial (Antes)
Inspección del punto de montaje del sistema de archivos para `/home/niri-test`:

```console
$ findmnt -T /home/niri-test
TARGET SOURCE                   FSTYPE OPTIONS
/home  /dev/mapper/root[/@home] btrfs  rw,relatime,compress=zstd:3,ssd,space_cache=v2,subvolid=257,subvol=/@home
```

Listado de subvolúmenes Btrfs en `/`:
```console
$ sudo btrfs subvolume list /
ID 256 gen 4654 top level 5 path @
ID 257 gen 4655 top level 5 path @home
ID 258 gen 4655 top level 5 path @log
ID 259 gen 4138 top level 5 path @pkg
ID 260 gen 1962 top level 256 path var/lib/portables
ID 261 gen 1962 top level 256 path var/lib/machines
ID 262 gen 1962 top level 256 path swap
ID 263 gen 1962 top level 256 path .snapshots
ID 264 gen 18 top level 5 path @factory
ID 265 gen 24 top level 263 path .snapshots/1/snapshot
ID 267 gen 3616 top level 257 path @home/.sandbox-golden
ID 287 gen 3617 top level 257 path @home/sandbox
ID 288 gen 4652 top level 257 path @home/.niri-test-snaps
ID 289 gen 4652 top level 288 path @home/.niri-test-snaps/backup-pre-piloto-20261026
```

**Diagnóstico:** `/home` reside en el subvolumen Btrfs `@home` (ID 257). Sin embargo, `/home/niri-test` era un directorio estándar dentro de `@home`, no un subvolumen independiente. Ya existía el subvolumen `/home/.niri-test-snaps` con el respaldo de seguridad `backup-pre-piloto-20261026`.

---

## 2. Aislamiento y Wipe

Para permitir snapshots directos y reversiones instantáneas sin afectar el resto de `/home`, se convirtió `/home/niri-test` en un subvolumen Btrfs independiente con permisos estrictos (`0700` y propietario `niri-test:niri-test`).

### Comandos Ejecutados
```bash
# 1. Detener procesos del usuario niri-test (UID 1002)
sudo systemctl stop user@1002

# 2. Mover directorio preexistente y crear el subvolumen dedicado
sudo mv /home/niri-test /home/.niri-test-old-wipe
sudo btrfs subvolume create /home/niri-test
sudo chown niri-test:niri-test /home/niri-test
sudo chmod 700 /home/niri-test

# 3. Limpieza segura del contenido viejo sin seguir symlinks
sudo rm -rf /home/.niri-test-old-wipe
```

> [!NOTE]
> Se verificó no seguir ni desreferenciar ningún enlace simbólico preexistente en el home anterior (`_boveda`, `Cloud`, `Idalia`, `Uploads-Gracie` hacia `/z-drive`). Tampoco se tocó `/z`, `/z-drive` ni la cuenta de producción `niri`.

### Estado Tras el Aislamiento (Después)
```console
$ sudo btrfs subvolume list / | grep niri-test
ID 288 gen 4652 top level 257 path @home/.niri-test-snaps
ID 289 gen 4652 top level 288 path @home/.niri-test-snaps/backup-pre-piloto-20261026
ID 290 gen 4657 top level 257 path @home/niri-test

$ sudo btrfs subvolume show /home/niri-test
@home/niri-test
	Name: 			niri-test
	UUID: 			d4e31617-bfd4-3349-b786-e7cc643b801b
	Subvolume ID: 		290
	Parent ID: 		257
	Top level ID: 		257
```

---

## 3. Despliegue con el Método Actual (Vault 06.1 / 06.2)

Siguiendo el procedimiento documentado en `06.1 - Gestion de Dotfiles con dotbare.md` y `06.2 - Validacion en Usuario Limpio`:

### 1. Clonación Bare con dotbare
```bash
sudo -u niri-test -H bash -c "cd ~ && dotbare finit -y -u 'https://github.com/robert-flo/niri-dotfiles.git' </dev/null"
```
**Resultado:** Repositorio bare clonado en `/home/niri-test/.cfg` y checkout aplicado en `$HOME` exitosamente.

### 2. Configuración de Upstream y Fetch
```bash
sudo -u niri-test git --git-dir=/home/niri-test/.cfg --work-tree=/home/niri-test config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
sudo -u niri-test git --git-dir=/home/niri-test/.cfg --work-tree=/home/niri-test config status.showUntrackedFiles no
sudo -u niri-test git --git-dir=/home/niri-test/.cfg --work-tree=/home/niri-test fetch origin
sudo -u niri-test git --git-dir=/home/niri-test/.cfg --work-tree=/home/niri-test branch -u origin/master master
```

### 3. Ejecución del Postinstall
```bash
sudo -u niri-test env HOME=/home/niri-test XDG_RUNTIME_DIR=/run/user/1002 bash -c '~/.local/bin/niri-dotfiles-postinstall'
```

**Salida resumida del postinstall:**
- `==> Adapting absolute paths to /home/niri-test`: adaptadas rutas en `.config/clavis/config.json`, `.config/obsidian/obsidian.json` y `.config/environment.d/clavis-mpvpaper.conf`.
- `==> GTK, icon and cursor settings (gsettings)`: detectado modo prefer-light / MacTahoe-dark. Advertencia esperada de dconf sin display server interactivo activo.
- `==> Clavis systemd user services`: aviso informativo de user manager detenido.
- `==> Matugen colors from the current wallpaper`: paleta generada exitosamente.
- `==> Validating niri config`:
  ```text
  DEBUG niri_config: loaded config from "/home/niri-test/.config/niri/config.kdl"
  INFO niri: config is valid
  ```
- **Secretos age:** No se solicitaron ni desbloquearon contraseñas ni secretos cifrados, conforme a las instrucciones.

### 4. Verificaciones de Validación
- `sudo -u niri-test rvim --headless -c "echo '[OK] rvim verified!'" -c "qa"`: verificado.
- `sudo -u niri-test 2kvim --headless -c "echo '[OK] 2kvim verified!'" -c "qa"`: verificado (31 plugins compilados/verificados en isolated pack).
- `sudo -u niri-test niri validate -c /home/niri-test/.config/niri/config.kdl`: `INFO niri: config is valid`.
- `sudo -u niri-test git --git-dir=/home/niri-test/.cfg --work-tree=/home/niri-test status`: Rama `master` al día con `origin/master`, con únicamente los 3 archivos modificados por sustitución de rutas absolutas (`clavis/config.json`, `environment.d/clavis-mpvpaper.conf`, `obsidian/obsidian.json`).

---

## 4. Creación del Snapshot Read-Only

Con el home de `niri-test` desplegado en estado prístino con el método actual, se creó el snapshot read-only en el subvolumen de respaldos:

```bash
sudo btrfs subvolume snapshot -r /home/niri-test /home/.niri-test-snaps/snap-niri-test-metodo-actual
```

### Verificación del Snapshot
```console
$ sudo btrfs subvolume list / | grep snap-niri-test-metodo-actual
ID 291 gen 4660 top level 288 path @home/.niri-test-snaps/snap-niri-test-metodo-actual
```

Ruta inmutable:
`/home/.niri-test-snaps/snap-niri-test-metodo-actual`

---

## 5. Reactivación del Servicio y Automatización

1. Se reactivó `user@1002` mediante `sudo systemctl start user@1002`.
2. Se registró cada operación en `CAMBIOS.md` con su correspondiente comando de reversión.
3. Se provee el script `scripts/piloto-home/aislar-niri-test.sh` para verificar o repetir el aislamiento de forma completamente idempotente.

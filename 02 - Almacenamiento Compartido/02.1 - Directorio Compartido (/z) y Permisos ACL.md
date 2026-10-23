---
title: "Directorio Compartido (/z) y Permisos ACL Multiusuario"
tags:
  - almacenamiento
  - compartido
  - z-pool
  - acl
  - setgid
  - git
  - multiusuario
aliases:
  - Directorio Compartido /z
  - Almacenamiento Compartido
  - 02.1 Directorio Compartido /z
date: 2026-10-23
---

# 🗄️ Directorio Compartido (`/z`) y Permisos ACL Multiusuario

> [!NOTE]
> **Navegación:**
> * Anterior: [[01.5 - Snapshots y Recuperacion con Btrfs|01.5 - Snapshots y Recuperación con Btrfs]]
> * Siguiente: [[02.2 - Repositorio de Wallpapers y Medios (/z)|02.2 - Repositorio de Wallpapers y Medios (/z)]]
> * Volver a: [[00.0 - Mapa General del Sistema (MOC)|Índice General (MOC)]]

Uno de los principios de diseño arquitectónico fundamentales de esta estación de trabajo es **maximizar el código y los recursos compartidos, evitando la duplicidad en disco**. 

Para lograrlo, el sistema dispone de un punto central de almacenamiento compartido montado en **`/z/`**, accesible de forma colaborativa por todos los usuarios del sistema (`omarchy`, `gracie`, `niri`, `sura`, `nyxuri`, `nyxuri-test`).

---

## 🏛️ Topología del Directorio `/z/`

```text
/z/
├── nvims/                           # 🚀 Configuraciones centralizadas de Neovim
│   ├── dotfiles-craftzdog/          # Fork de Craftzdog (feat/late-2026, vim.pack)
│   └── rvim/                        # Distro propia mínima (robert-flo/rvim)
├── wallpaper-collection/            # 🌄 Colección extendida de fondos y videos mpvpaper
└── android-projects/                # 📱 Espacio de desarrollo móvil compartido
```

---

## 🔐 Modelo de Permisos: Grupo `wheel`, Setgid y ACLs

Para permitir que cualquier usuario miembro de `wheel` pueda leer, escribir y crear archivos dentro de `/z/` sin que los nuevos archivos queden bloqueados con permisos privados (`0644` o `0700` de umask), se utiliza una combinación de:

1. **Permiso especial Setgid (`2775`)**: Asegura que cualquier archivo o subdirectorio creado dentro de `/z/` herede automáticamente el grupo propietario `wheel` en lugar del grupo primario del usuario que lo creó.
2. **Listas de Control de Acceso por Defecto (Default ACLs)**: Forzan que cualquier nuevo elemento herede permisos de lectura, escritura y ejecución (`rwx`) para el grupo `wheel`.
3. **Regla Git `safe.directory` a nivel de sistema**: Permite que cualquier usuario ejecute comandos de `git` o herramientas que inspeccionen repositorios en `/z/` (como plugins de Neovim o scripts de actualización) sin recibir errores de propiedad dudosa de Git (`fatal: detected dubious ownership in repository`).

---

## 🛠️ Procedimiento de Creación y Configuración

```bash
sudo bash -c '
set -euo pipefail

# 1. Crear el punto de montaje /z si no existe
mkdir -p /z
chown root:wheel /z
chmod 2775 /z

# 2. Configurar ACLs estándar y por defecto (herencia para nuevos archivos)
setfacl -m g:wheel:rwx /z
setfacl -d -m g:wheel:rwx /z

# 3. Habilitar safe.directory a nivel de sistema para todo /z/*
git config --system --add safe.directory "/z/*"

echo "✅ Directorio compartido /z/ configurado exitosamente."
'
```

> [!TIP]
> Si en el futuro agregas un subdirectorio masivo o copias archivos desde otro origen hacia `/z/`, puedes reajustar los permisos grupales y ACLs recursivamente con:
> ```bash
> sudo chgrp -R wheel /z
> sudo chmod -R g+rwX /z
> sudo find /z -type d -exec chmod g+s {} +
> sudo setfacl -R -d -m g:wheel:rwx /z
> ```

---

## 🔍 Pasos de Verificación

```bash
# 1. Comprobar permisos y bit setgid en /z/
ls -ld /z
# Salida esperada: drwxrws---+ ... root wheel ... /z

# 2. Comprobar ACLs activas y por defecto
getfacl /z
# Salida esperada incluye:
# group:wheel:rwx
# default:group:wheel:rwx

# 3. Comprobar safe.directory en gitconfig global del sistema
git config --system --get-all safe.directory
# Salida esperada incluye: /z/*

# 4. Probar creación de archivo como usuario normal
sudo -u niri touch /z/test_niri.tmp
ls -l /z/test_niri.tmp
# Salida esperada: -rw-rw----+ 1 niri wheel ... /z/test_niri.tmp
rm -f /z/test_niri.tmp
```

---

## 🔗 Próximos Pasos

- [[02.2 - Repositorio de Wallpapers y Medios (/z)|➡️ Repositorio de Wallpapers y Medios (/z)]]
- [[05.1 - Arquitectura Neovim Dual Compartida (/z/nvims)|➡️ Despliegue de Neovim Dual en /z/nvims/]]
- [[00.0 - Mapa General del Sistema (MOC)|🏠 Volver al Índice General]]

---
title: "Proyecto: forkhub (Extracción, Mapa SSoT y Orquestación)"
tags:
  - proyectos
  - forkhub
  - duo-repo
  - worktrees
  - pacman
aliases:
  - Proyecto forkhub
  - PJ-CLAVIS-rf-forkhub
date: 2026-11-15
---

# 🛠️ Proyecto: `forkhub` (`PJ-CLAVIS-rf-forkhub` + `PJ-CLAVIS-rf-forkhub-arch`)

> [!NOTE]
> **Navegación y Contexto:**
> * Hub de Proyectos: [[proyectos/00 - Proyectos (MOC)|🚀 Proyectos]]
> * Topología Canónica: [[08.3 - Topologia Canonica de Repositorios, Worktrees y GitHub Workflows|08.3 Topología Canónica]]
> * Estándar Dúo-Repo: [[docs/adr/0002-arbol-de-decision-y-estandar-duo-repositorios|ADR 0002]]
> * Home Repo: `/z-home-repos/PJ-CLAVIS`

## 🎯 Objetivo del Proyecto

Extraer `forkhub` desde `scripts/forkhub/` del vault hacia su propio **dúo de repositorios** empaquetado por `pacman` en `[omarchy-personal]`, ampliándolo para convertirse en la **Única Fuente de la Verdad (SSoT)** que gestione:
1. Forks y sincronización contra upstreams (`ADR 0024` / `ADR 013` / `frozen`).
2. Repositorios bare + worktrees paralelos (orquestando `ravn-git-bare-clone`: `git-bare-clone`, `git-create-worktree`, `git-issue-worktree`).
3. Experimentos rápidos (orquestando `try-clone` en `/z-drive/tries`).
4. Auditoría global de salud (`audit`: cambios sucios, commits sin push, clones fuera de topología en `/zt`).

---

## 🏗️ Repositorios y Plantillas Base

| Rol | Plantilla Base | Nuevo Repositorio Objetivo |
|---|---|---|
| **Código fuente, CLI, tests, `Makefile`** | `robert-flo/pj-domina-rf-git-setup` | `robert-flo/PJ-CLAVIS-rf-forkhub` |
| **Empaquetado Arch (`PKGBUILD`, `.SRCINFO`, CI)** | `robert-flo/pj-domina-rf-git-setup-arch` | `robert-flo/PJ-CLAVIS-rf-forkhub-arch` |
| **Home Repo Orquestador** | [The Home Repo Pattern](https://www.aihero.dev/the-home-repo-pattern) | `/z-home-repos/PJ-CLAVIS` |

### Plan de Renames Diferidos (Regla de Bloqueo)

> [!CAUTION]
> **Bloqueo explícito:** NO se renombrarán `PJ-NIRI-rf-omarchy-workstation` ni `rf-dotfiles` hasta verificar al **100% y de forma idempotente** que `PJ-CLAVIS-rf-forkhub` instalado vía `pacman` cubre todo lo que hoy hace `scripts/forkhub/forkhub`.

Cuando se cumpla la paridad al 100%:
1. Retirar `scripts/forkhub/` del vault y `/usr/local/bin/forkhub` del sistema.
2. Renombrar `robert-flo/PJ-NIRI-rf-omarchy-workstation` → `robert-flo/PJ-CLAVIS-rf-workstation`.
3. Renombrar `robert-flo/rf-dotfiles` → `robert-flo/PJ-CLAVIS-rf-dotfiles`.
4. Conectar todo bajo la filosofía de **Home Repo** (`/z/PJ-CLAVIS`).

---

## ✅ Checklist de Paridad e Idempotencia (100% requerido)

El nuevo `PJ-CLAVIS-rf-forkhub` debe cubrir **sin regresiones** todas las capacidades actuales de `scripts/forkhub/forkhub`:

- [ ] `forkhub list` — Lista todos los repositorios registrados, grupo, ruta y upstream.
- [ ] `forkhub status` — Estado local (no clonado, dirty, ahead/behind/divergente, último commit).
- [ ] `forkhub upstream [-g <grupo>]` — Comparativa contra upstream vía `gh api` (incluyendo estado `frozen`/`manual`).
- [ ] `forkhub sync-upstream [fork|--all] [--dry-run]` — Sincronización `adr0024` / `adr013` y respeto a `frozen`.
- [ ] `forkhub update [repo|--all] [-n] [-f]` — Actualización idempotente local + hooks `post_update`.
- [ ] `forkhub add` / `forkhub remove` — Gestión declarativa del mapa de repositorios.
- [ ] `forkhub audit [--dirty-only]` — Auditoría global de topología (sucios, sin push/upstream, clones en `/zt`).
- [ ] Unidades `systemd` (`forkhub.service` / `forkhub.timer`) empaquetadas limpiamente en `PJ-CLAVIS-rf-forkhub-arch`.
- [ ] Mapa único de repositorios (SSoT) + integración con `ravn-git-bare-clone` y `try-clone`.
- [ ] Suite de tests automatizados heredada de `pj-domina-rf-git-setup` pasando en verde.

---

## 📝 Registro de Decisiones de Diseño (Pendiente de Consenso)

- [ ] Formato del mapa único de repositorios (`fleet.toml` / `repos.toml` vs `repos.d/*.conf` o ambos).
- [ ] Diseño de subcomandos nuevos (`clone`, `wt`, `issue`, `try`, `converge`).
- [ ] Estrategia para unidades `systemd` dentro del dúo `git-setup` (`ADR 0002`).

---

## 🔍 Hallazgos Técnicos (Auditoría del `forkhub` actual sobre `PJ-CLAVIS`)

*Registrado el 2026-11-15 tras probar el `forkhub` actual sobre `/z-home-repos/PJ-CLAVIS`:*

| Capacidad | `forkhub audit` (actual) | `forkhub status` / `update` / `timer` (actual) | Requisito para `PJ-CLAVIS-rf-forkhub` |
|---|---|---|---|
| **Detectar clon local** | ✅ Sí (escanea `/z-home-repos/`) | ❌ No (solo lee `/etc/forkhub/repos.d/*.conf`) | Mapa único SSoT que incluya `home-repo`, `bare+worktrees`, `tries` y `forks` |
| **Detectar árbol sucio** | ✅ Sí (`git status --porcelain`, incluye *untracked*) | ⚠️ Parcial (`git diff --quiet`, ignora *untracked*) | Unificar en `git status --porcelain` en todos los comandos |
| **Detectar commits sin `push` (`ahead`)** | ✅ Sí (`@{u}..HEAD`) | ✅ Sí (pero solo si está en `repos.d/`) | Cubrir toda la flota registrada y escaneada |
| **Detectar falta de `pull` (`behind`)** | ❌ No (100% offline, sin `git fetch`) | ✅ Sí (hace `git fetch`, solo `repos.d/`) | Añadir flag `--fetch` en `audit` y unificar `status` + `audit` |
| **Monitoreo automático (`systemd`)** | ❌ No corre `audit` | ⚠️ Solo `sync-upstream` / `update` en `repos.d/` | Alertar vía `notify-send` / timer si hay repos sucios o sin push/pull |

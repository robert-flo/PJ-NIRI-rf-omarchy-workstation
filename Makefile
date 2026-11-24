.DEFAULT_GOAL := help

SHELL := /bin/bash

# Paleta Rollo
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
BOLD   := \033[1m
DIM    := \033[2m
NC     := \033[0m

DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif

include make/help.mk
include make/install.mk
include make/doctor.mk

# Targets legacy pendientes de extracción (#179)
.PHONY: secrets lock-secrets test-secrets \
        forks forks-audit forks-sync \
        sync sync-replica sync-status \
        sandbox-status sandbox-reset

sync-status: ## [Almacenamiento] Dashboard en tiempo real de sincronizaciones /z-drive y nube
	$(EXEC) sudo sync-status

sync: ## [Almacenamiento] Siembra y sincronización integral inteligente (sync-all)
	$(EXEC) sudo sync-all

sync-replica: ## [Almacenamiento] Fuerza descarga/réplica desde Cloud sin riesgo (sync-all --replica)
	$(EXEC) sudo sync-all --replica

secrets: ## [Secretos] Desbloquea y aprovisiona secretos en todos los usuarios
	$(EXEC) ./scripts/secrets/desbloquear-secretos.sh

lock-secrets: ## [Secretos] Empaqueta y recifra el bundle de secretos (age)
	$(EXEC) ./scripts/secrets/cifrar-secretos.sh

test-secrets: ## [Secretos] Verifica que el bundle de secretos pueda descifrarse
	./scripts/secrets/probar-descifrado.sh

forks: ## [Forkhub] Dashboard de salud y ramas de los repositorios
	forkhub status

forks-audit: ## [Forkhub] Audita divergencias y commits contra upstreams oficiales
	./scripts/forkhub/auditar-forks.sh

forks-sync: ## [Forkhub] Sincroniza y mergea upstreams respetando directiva ADR 0024
	$(EXEC) forkhub sync

sandbox-status: ## [Sandbox] Consulta estado del subvolumen y snapshots del sandbox
	sudo sandbox-btrfs-manager.sh status

sandbox-reset: ## [Sandbox] Rollback instantáneo de fábrica para el usuario sandbox
	$(EXEC) sudo sandbox-btrfs-manager.sh reset

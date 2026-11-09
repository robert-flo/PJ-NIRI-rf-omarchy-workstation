.PHONY: help install install-padre install-hija converge audit doctor \
        secrets lock-secrets test-secrets \
        forks forks-audit forks-sync \
        sync sync-status \
        sandbox-status sandbox-reset \
        test-idempotence clean

SHELL := /bin/bash

BOLD  := \033[1m
CYAN  := \033[36m
GREEN := \033[32m
YELLOW:= \033[33m
RED   := \033[31m
RESET := \033[0m

help:
	@echo -e "$(BOLD)$(CYAN)==========================================================================$(RESET)"
	@echo -e "$(BOLD)$(CYAN)   PJ-NIRI-rf-omarchy-workstation — Orquestación de Estación de Trabajo   $(RESET)"
	@echo -e "$(BOLD)$(CYAN)==========================================================================$(RESET)"
	@echo -e "$(BOLD)🚀 INSTALACIÓN Y DESPLIEGUE:$(RESET)"
	@echo -e "  $(GREEN)make install$(RESET)            Instalación integral completa en Modo PADRE (Full 4 Etapas)"
	@echo -e "  $(GREEN)make install-padre$(RESET)      Instalación integral completa en Modo PADRE (Full 4 Etapas)"
	@echo -e "  $(GREEN)make install-hija$(RESET)       Instalación integral completa en Modo HIJA (Full 4 Etapas)"
	@echo -e "  $(GREEN)make converge$(RESET)           Aplica convergencia directa de capas 01-07 (Rápido / Idempotente)"
	@echo -e "  $(GREEN)make audit$(RESET)              Simula y audita todas las capas sin modificar nada (--dry-run)"
	@echo -e "  $(GREEN)make test-idempotence$(RESET)   Valida inocuidad e idempotencia estricta en el sistema"
	@echo ""
	@echo -e "$(BOLD)🩺 DIAGNÓSTICO Y SALUD:$(RESET)"
	@echo -e "  $(CYAN)make doctor$(RESET)             Diagnóstico unificado integral (Nyxuri, Clavis, Sudoers, Display)"
	@echo -e "  $(CYAN)make sync-status$(RESET)        Dashboard en tiempo real de sincronizaciones /z-drive y nube"
	@echo ""
	@echo -e "$(BOLD)🔐 SECRETOS (AGE):$(RESET)"
	@echo -e "  $(YELLOW)make secrets$(RESET)            Desbloquea y aprovisiona secretos en todos los usuarios"
	@echo -e "  $(YELLOW)make lock-secrets$(RESET)       Empaqueta y recifra el bundle de secretos (age)"
	@echo -e "  $(YELLOW)make test-secrets$(RESET)       Verifica que el bundle de secretos pueda descifrarse"
	@echo ""
	@echo -e "$(BOLD)🐙 FLOTA DE FORKS (FORKHUB):$(RESET)"
	@echo -e "  $(GREEN)make forks$(RESET)              Dashboard de salud y ramas de los 15 repositorios"
	@echo -e "  $(GREEN)make forks-audit$(RESET)        Audita divergencias y commits contra upstreams oficiales"
	@echo -e "  $(GREEN)make forks-sync$(RESET)         Sincroniza y mergea upstreams respetando directiva ADR 0024"
	@echo ""
	@echo -e "$(BOLD)🔄 ALMACENAMIENTO Y SINCRONIZACIÓN:$(RESET)"
	@echo -e "  $(CYAN)make sync$(RESET)               Dispara ciclo de sincronización seguro (sync-all)"
	@echo ""
	@echo -e "$(BOLD)🏝️ SANDBOX DESECHABLE (BTRFS):$(RESET)"
	@echo -e "  $(RED)make sandbox-status$(RESET)     Consulta estado del subvolumen y snapshots del sandbox"
	@echo -e "  $(RED)make sandbox-reset$(RESET)      Rollback instantáneo de fábrica para el usuario sandbox"
	@echo -e "$(BOLD)$(CYAN)==========================================================================$(RESET)"

install: install-padre

install-padre:
	sudo ./scripts/omarchy-onboarding/onboard-machine.sh --padre --full

install-hija:
	sudo ./scripts/omarchy-onboarding/onboard-machine.sh --hija --full

converge:
	sudo ./scripts/omarchy-onboarding/converge-workstation.sh

audit:
	sudo ./scripts/omarchy-onboarding/converge-workstation.sh --dry-run

test-idempotence:
	sudo ./scripts/omarchy-onboarding/ci-idempotencia.sh

doctor:
	@echo -e "$(BOLD)$(CYAN)==> [1/6] Diagnosticando Nyxuri Shell & Plugins...$(RESET)"
	@sudo -u nyxuri nyxuri doctor 2>/dev/null || echo -e "  $(YELLOW)[!] nyxuri doctor no disponible o falló$(RESET)"
	@echo ""
	@echo -e "$(BOLD)$(CYAN)==> [2/6] Diagnosticando Clavis Shell & Key-CLI...$(RESET)"
	@key doctor 2>/dev/null || sudo key doctor 2>/dev/null || echo -e "  $(YELLOW)[!] key doctor no disponible$(RESET)"
	@echo ""
	@echo -e "$(BOLD)$(CYAN)==> [3/6] Verificando Display Manager y Sesiones Wayland...$(RESET)"
	@systemctl is-active --quiet greetd && echo -e "  $(GREEN)[✓] Greetd Display Manager: ACTIVO$(RESET)" || echo -e "  $(YELLOW)[!] Greetd no está activo$(RESET)"
	@systemctl is-active --quiet sddm && echo -e "  $(GREEN)[✓] SDDM Display Manager: ACTIVO$(RESET)" || true
	@echo "  Sesiones registradas en /usr/share/wayland-sessions:"
	@ls -1 /usr/share/wayland-sessions 2>/dev/null | sed 's/^/    - /' || true
	@echo ""
	@echo -e "$(BOLD)$(CYAN)==> [4/6] Verificando Entorno Java y Android SDK...$(RESET)"
	@echo "  Java default: $$(archlinux-java get 2>/dev/null || echo 'No detectado')"
	@echo "  ADB version:  $$(adb version 2>/dev/null | head -n1 || echo 'No detectado')"
	@echo "  ANDROID_HOME: $${ANDROID_HOME:-/opt/android-sdk}"
	@echo ""
	@echo -e "$(BOLD)$(CYAN)==> [5/6] Verificando Integridad de Sudoers y Permisos /z...$(RESET)"
	@sudo visudo -c >/dev/null 2>&1 && echo -e "  $(GREEN)[✓] Sudoers: Sintaxis íntegra (visudo -c OK)$(RESET)" || echo -e "  $(RED)[✗] Error en sintaxis de sudoers$(RESET)"
	@getfacl /z 2>/dev/null | grep -q "default:group:wheel:rwx" && echo -e "  $(GREEN)[✓] Directorio /z: ACLs 2775 y herencia wheel activas$(RESET)" || echo -e "  $(YELLOW)[!] ACLs de /z incompletas$(RESET)"
	@echo ""
	@echo -e "$(BOLD)$(CYAN)==> [6/6] Verificando Timers del Sistema...$(RESET)"
	@systemctl list-timers --no-pager | grep -E "forkhub|sync|niri|z-perms|android" || true

sync-status:
	sudo sync-status

sync:
	sudo sync-all

secrets:
	./scripts/secrets/desbloquear-secretos.sh

lock-secrets:
	./scripts/secrets/cifrar-secretos.sh

test-secrets:
	./scripts/secrets/probar-descifrado.sh

forks:
	forkhub status

forks-audit:
	./scripts/forkhub/auditar-forks.sh

forks-sync:
	forkhub sync

sandbox-status:
	sudo sandbox-btrfs-manager.sh status

sandbox-reset:
	sudo sandbox-btrfs-manager.sh reset

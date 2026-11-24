# ═══════════════════════════════════════════════════════════════════════════
# 🚀 INSTALL — Instalación, convergencia, auditoría e idempotencia
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: install install-padre install-hija converge audit test-idempotence

install: install-padre ## [Instalación] Instalación integral completa en Modo PADRE (Full 4 Etapas)

install-padre: ## [Instalación] Instalación integral completa en Modo PADRE (Full 4 Etapas)
	$(EXEC) sudo ./scripts/omarchy-onboarding/onboard-machine.sh --padre --full

install-hija: ## [Instalación] Instalación integral completa en Modo HIJA (Full 4 Etapas)
	$(EXEC) sudo ./scripts/omarchy-onboarding/onboard-machine.sh --hija --full

converge: ## [Instalación] Aplica convergencia directa de capas 01-07 (Rápido / Idempotente)
	$(EXEC) sudo ./scripts/omarchy-onboarding/converge-workstation.sh

audit: ## [Instalación] Simula y audita todas las capas sin modificar nada (--dry-run)
	$(EXEC) sudo ./scripts/omarchy-onboarding/converge-workstation.sh --dry-run

test-idempotence: ## [Instalación] Valida inocuidad e idempotencia estricta en el sistema
	$(EXEC) sudo ./scripts/omarchy-onboarding/ci-idempotencia.sh

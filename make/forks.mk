# ═══════════════════════════════════════════════════════════════════════════
# 🐙 FORKS — Flota de repositorios y upstreams (forkhub)
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: forks forks-audit forks-sync

forks: ## [Forkhub] Dashboard de salud y ramas de los 15 repositorios
	$(EXEC) forkhub status

forks-audit: ## [Forkhub] Audita divergencias y commits contra upstreams oficiales
	$(EXEC) ./scripts/forkhub/auditar-forks.sh

forks-sync: ## [Forkhub] Sincroniza y mergea upstreams respetando directiva ADR 0024
	$(EXEC) forkhub sync

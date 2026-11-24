# ═══════════════════════════════════════════════════════════════════════════
# 🏝️ SANDBOX — Entorno desechable sobre Btrfs
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: sandbox-status sandbox-reset

sandbox-status: ## [Sandbox] Consulta estado del subvolumen y snapshots del sandbox
	$(EXEC) sudo sandbox-btrfs-manager.sh status

sandbox-reset: ## [Sandbox] Rollback instantáneo de fábrica para el usuario sandbox
	$(EXEC) sudo sandbox-btrfs-manager.sh reset

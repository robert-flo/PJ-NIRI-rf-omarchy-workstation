# ═══════════════════════════════════════════════════════════════════════════
# 🔄 SYNC — Almacenamiento y sincronización (/z-drive y nube)
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: sync sync-replica sync-status

sync: ## [Almacenamiento] Siembra y sincronización integral inteligente (sync-all)
	$(EXEC) sudo sync-all

sync-replica: ## [Almacenamiento] Fuerza descarga/réplica desde Cloud sin riesgo (sync-all --replica)
	$(EXEC) sudo sync-all --replica

sync-status: ## [Diagnóstico] Dashboard en tiempo real de sincronizaciones /z-drive y nube
	$(EXEC) sudo sync-status

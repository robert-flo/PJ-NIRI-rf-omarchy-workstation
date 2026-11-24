# ═══════════════════════════════════════════════════════════════════════════
# 🔐 SECRETS — Gestión y verificación de secretos cifrados (age)
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: secrets lock-secrets test-secrets

secrets: ## [Secretos] Desbloquea y aprovisiona secretos en todos los usuarios
	$(EXEC) ./scripts/secrets/desbloquear-secretos.sh

lock-secrets: ## [Secretos] Empaqueta y recifra el bundle de secretos (age)
	$(EXEC) ./scripts/secrets/cifrar-secretos.sh

test-secrets: ## [Secretos] Verifica que el bundle de secretos pueda descifrarse
	$(EXEC) ./scripts/secrets/probar-descifrado.sh

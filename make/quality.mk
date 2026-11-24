# ═══════════════════════════════════════════════════════════════════════════
# ✅ QUALITY — Validación del Vault y linting de scripts
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: vault-validate lint

vault-validate: ## [Calidad] Valida integridad, frontmatter y wikilinks del Vault
	$(EXEC) python3 scripts/validate_vault.py

lint: ## [Calidad] Ejecuta shellcheck sobre los scripts bash en scripts/
	$(EXEC) bash -c 'find scripts -type f -name "*.sh" -print0 | xargs -0 -r shellcheck -S error -x'

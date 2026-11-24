# ═══════════════════════════════════════════════════════════════════════════
# 📚 HELP — Ayuda dinámica categorizada (Paleta Rollo)
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: help

help: ## [General] Muestra esta ayuda dinámica categorizada
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)══════════════════════════════════════════════════════════════════════════$(NC)\n"
	@printf "$(CYAN)$(BOLD)  PJ-NIRI-rf-omarchy-workstation — Orquestación de Estación de Trabajo$(NC)\n"
	@printf "$(CYAN)══════════════════════════════════════════════════════════════════════════$(NC)\n"
endif
	@awk ' \
		BEGIN { cat_count = 0 } \
		/^[a-zA-Z0-9_-]+:.*## \[/ { \
			target = $$0; sub(/:.*/, "", target); \
			desc = $$0; sub(/^.*## \[/, "", desc); \
			cat = desc; sub(/\].*$$/, "", cat); \
			sub(/^[^\]]*\] */, "", desc); \
			if (!(cat in seen)) { \
				seen[cat] = 1; \
				cats[++cat_count] = cat; \
			} \
			items[cat, ++count[cat]] = sprintf("  $(GREEN)%-22s$(NC) %s", target, desc); \
		} \
		END { \
			for (i = 1; i <= cat_count; i++) { \
				c = cats[i]; \
				printf "\n$(BLUE)$(BOLD)%s$(NC)\n", c; \
				printf "$(DIM)──────────────────────────────────────────────────────────────────────────$(NC)\n"; \
				for (j = 1; j <= count[c]; j++) { \
					print items[c, j]; \
				} \
			} \
		}' $(MAKEFILE_LIST)
ifndef EMBEDDED
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "  $(DIM)make audit$(NC)              Simular convergencia sin cambios (--dry-run)\n"
	@printf "  $(DIM)make doctor$(NC)             Ejecutar diagnóstico completo del sistema\n"
	@printf "  $(DIM)make <target> DRY_RUN=1$(NC) Previsualizar comandos mutantes sin ejecutar\n"
	@printf "$(CYAN)══════════════════════════════════════════════════════════════════════════$(NC)\n\n"
endif

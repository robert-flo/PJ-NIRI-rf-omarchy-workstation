# ═══════════════════════════════════════════════════════════════════════════
# 🩺 DOCTOR — Diagnóstico unificado integral (7 comprobaciones)
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: doctor

doctor: ## [Diagnóstico] Diagnóstico unificado integral (Nyxuri, Clavis, Sudoers, Display)
ifeq ($(DRY_RUN),1)
	@echo "  ▶ [dry-run] Ejecutaría 7 comprobaciones de diagnóstico del sistema (Nyxuri, Clavis/Key-CLI, Display Manager, Java/Android, Sudoers//z, Dotfiles/Chezmoi, Timers)"
else
	@printf "\n$(CYAN)══════════════════════════════════════════════════════════════════════════$(NC)\n"
	@printf "$(BOLD)$(CYAN)  🩺 Diagnóstico Unificado — PJ-NIRI-rf-omarchy-workstation$(NC)\n"
	@printf "$(CYAN)══════════════════════════════════════════════════════════════════════════$(NC)\n\n"
	@printf "$(BOLD)$(CYAN)==> [1/7] Diagnosticando Nyxuri Shell & Plugins...$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────────$(NC)\n"
	@sudo -u nyxuri nyxuri doctor 2>/dev/null || printf "  $(YELLOW)[!] nyxuri doctor no disponible o falló$(NC)\n"
	@printf "\n"
	@printf "$(BOLD)$(CYAN)==> [2/7] Diagnosticando Clavis Shell & Key-CLI...$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────────$(NC)\n"
	@key doctor 2>/dev/null || sudo key doctor 2>/dev/null || printf "  $(YELLOW)[!] key doctor no disponible$(NC)\n"
	@printf "\n"
	@printf "$(BOLD)$(CYAN)==> [3/7] Verificando Display Manager y Sesiones Wayland...$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────────$(NC)\n"
	@systemctl is-active --quiet greetd && printf "  $(GREEN)[✓] Greetd Display Manager: ACTIVO$(NC)\n" || printf "  $(YELLOW)[!] Greetd no está activo$(NC)\n"
	@systemctl is-active --quiet sddm && printf "  $(GREEN)[✓] SDDM Display Manager: ACTIVO$(NC)\n" || true
	@printf "  Sesiones registradas en /usr/share/wayland-sessions:\n"
	@ls -1 /usr/share/wayland-sessions 2>/dev/null | sed 's/^/    - /' || true
	@printf "\n"
	@printf "$(BOLD)$(CYAN)==> [4/7] Verificando Entorno Java y Android SDK...$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  Java default: %s\n" "$$(archlinux-java get 2>/dev/null || echo 'No detectado')"
	@printf "  ADB version:  %s\n" "$$(adb version 2>/dev/null | head -n1 || echo 'No detectado')"
	@printf "  ANDROID_HOME: %s\n" "$${ANDROID_HOME:-/opt/android-sdk}"
	@printf "\n"
	@printf "$(BOLD)$(CYAN)==> [5/7] Verificando Integridad de Sudoers y Permisos /z...$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────────$(NC)\n"
	@sudo visudo -c >/dev/null 2>&1 && printf "  $(GREEN)[✓] Sudoers: Sintaxis íntegra (visudo -c OK)$(NC)\n" || printf "  $(RED)[✗] Error en sintaxis de sudoers$(NC)\n"
	@getfacl /z 2>/dev/null | grep -q "default:group:wheel:rwx" && printf "  $(GREEN)[✓] Directorio /z: ACLs 2775 y herencia wheel activas$(NC)\n" || printf "  $(YELLOW)[!] ACLs de /z incompletas$(NC)\n"
	@printf "\n"
	@printf "$(BOLD)$(CYAN)==> [6/7] Verificando Dotfiles y Manifiesto de Paquetes SSoT (Chezmoi)...$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────────$(NC)\n"
	@[[ -d /z/rf-dotfiles/.git ]] && printf "  $(GREEN)[✓] Repositorio central /z/rf-dotfiles: ACTIVO (%s)$(NC)\n" "$$(git -C /z/rf-dotfiles branch --show-current)" || printf "  $(RED)[✗] /z/rf-dotfiles no existe o no es repositorio git$(NC)\n"
	@[[ -f /z/rf-dotfiles/.chezmoidata/packages.json ]] && printf "  $(GREEN)[✓] Manifiesto SSoT de paquetes: PRESENTE (%s paquetes oficiales)$(NC)\n" "$$(jq '.packages.official | length' /z/rf-dotfiles/.chezmoidata/packages.json)" || printf "  $(RED)[✗] Manifiesto .chezmoidata/packages.json no encontrado$(NC)\n"
	@command -v chezmoi >/dev/null && printf "  $(GREEN)[✓] Chezmoi CLI: Instalado (%s)$(NC)\n" "$$(chezmoi --version | head -n1)" || printf "  $(RED)[✗] chezmoi CLI no encontrado$(NC)\n"
	@printf "\n"
	@printf "$(BOLD)$(CYAN)==> [7/7] Verificando Timers del Sistema...$(NC)\n"
	@printf "$(DIM)──────────────────────────────────────────────────────────────────────────$(NC)\n"
	@systemctl list-timers --no-pager | grep -E "forkhub|sync|niri|z-perms|android" || true
ifndef EMBEDDED
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "  $(DIM)make audit$(NC)     Simular convergencia sin cambios (--dry-run)\n"
	@printf "  $(DIM)make converge$(NC)  Aplicar convergencia de capas 01-07\n"
	@printf "$(CYAN)══════════════════════════════════════════════════════════════════════════$(NC)\n\n"
endif
endif

.PHONY: help install install-padre install-hija audit secrets doctor clean

SHELL := /bin/bash

help:
	@echo "=========================================================================="
	@echo "   PJ-NIRI-rf-omarchy-workstation — Orquestación de Estación de Trabajo   "
	@echo "=========================================================================="
	@echo "Comandos disponibles:"
	@echo "  make install         Instalación integral completa en Modo PADRE (Full)"
	@echo "  make install-padre   Instalación integral completa en Modo PADRE (Full)"
	@echo "  make install-hija    Instalación integral completa en Modo HIJA (Full)"
	@echo "  make audit           Simula y audita todas las capas sin modificar nada"
	@echo "  make secrets         Desbloquea o recifra el bundle de secretos (age)"
	@echo "  make doctor          Diagnóstico del sistema y estado de Nyxuri/Clavis"
	@echo "=========================================================================="

install: install-padre

install-padre:
	sudo ./scripts/omarchy-onboarding/onboard-machine.sh --padre --full

install-hija:
	sudo ./scripts/omarchy-onboarding/onboard-machine.sh --hija --full

audit:
	sudo ./scripts/omarchy-onboarding/converge-workstation.sh --dry-run

secrets:
	./scripts/secrets/desbloquear-secretos.sh

doctor:
	@echo "==> Verificando estado de Nyxuri..."
	@sudo -u nyxuri nyxuri doctor 2>/dev/null || true
	@echo ""
	@echo "==> Verificando display manager..."
	@systemctl status display-manager.service --no-pager || true

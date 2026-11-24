.DEFAULT_GOAL := help

SHELL := /bin/bash

# Paleta Rollo
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
BOLD   := \033[1m
DIM    := \033[2m
NC     := \033[0m

DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = @echo "  ▶ [dry-run]"
else
  EXEC =
endif

include make/help.mk
include make/install.mk
include make/doctor.mk
include make/secrets.mk
include make/forks.mk
include make/sync.mk
include make/sandbox.mk
include make/quality.mk

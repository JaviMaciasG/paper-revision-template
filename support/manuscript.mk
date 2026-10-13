.DEFAULT_GOAL := all
BASH_CMD ?= bash
TYPE ?= manuscript
BASELINE ?=
TEMPLATE_SUPPORT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DRIVER = $(BASH_CMD) "$(TEMPLATE_SUPPORT)/build.sh"
.PHONY: all paper help check-tools zip clean distclean
ifeq ($(TYPE),revision)
.PHONY: diff
all: diff
diff:
	@$(DRIVER) diff --baseline "$(BASELINE)"
else
all:
	@$(DRIVER) paper
endif
paper:
	@$(DRIVER) paper
help:
	@printf '%s\n' '  all          Build paper$(if $(filter revision,$(TYPE)), and comparison) (default)' \
	 '  help         Show applicable commands without TeX' \
	 '  paper        Build the manuscript only' '  check-tools  Check required tools' '  zip          Standalone sources in paper-<folder>.zip beside paper.tex' \
	 '  clean        Remove auxiliaries; retain PDFs and ZIPs' \
	 '  distclean    Remove generated outputs; preserve source PDF figures' \
	 'PDFs and source ZIP: stage folder; auxiliaries: build/';
ifeq ($(TYPE),revision)
	@printf '%s\n' '  diff         Compare text and rendered bibliography' 'Baseline: $(BASELINE)';
endif
check-tools:
	@$(DRIVER) check-tools $(if $(filter revision,$(TYPE)),--diff)
zip:
	@$(DRIVER) zip
clean distclean:
	@$(DRIVER) $@

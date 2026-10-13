.DEFAULT_GOAL := all
PYTHON ?= python3
TYPE ?= manuscript
BASELINE ?=
TEMPLATE_BUILD := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DRIVER = $(PYTHON) "$(TEMPLATE_BUILD)/template.py"
.PHONY: all help check-tools zip clean distclean
ifeq ($(TYPE),revision)
.PHONY: diff
all: diff
diff:
	@$(DRIVER) diff --baseline "$(BASELINE)"
else
all:
	@$(DRIVER) paper
endif
help:
	@printf '%s\n' '  all          Build paper$(if $(filter revision,$(TYPE)), and comparison) (default)' 	  '  help         Show applicable commands without TeX' 	  '  check-tools  Check required tools' 	  '  zip          Create a standalone manuscript source ZIP' 	  '  clean        Remove auxiliaries; retain final PDFs and ZIPs' 	  '  distclean    Remove all generated outputs';
ifeq ($(TYPE),revision)
	@printf '%s\n' '  diff         Build both versions and their text/bibliography comparison' 'Baseline: $(BASELINE)' 'Example: make diff';
endif
check-tools:
	@$(DRIVER) check-tools $(if $(filter revision,$(TYPE)),--diff)
zip:
	@$(DRIVER) zip
clean distclean:
	@$(DRIVER) $@

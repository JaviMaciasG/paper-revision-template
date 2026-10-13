.DEFAULT_GOAL := all
PYTHON ?= python3
REVISION ?=
REVIEWERS ?= 1 2
TEMPLATE_BUILD := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DRIVER = $(PYTHON) "$(TEMPLATE_BUILD)/template.py"
LETTERS := responses editor $(addprefix reviewer,$(REVIEWERS))
.PHONY: all help check-tools bundle clean distclean $(LETTERS)
all:
	@$(DRIVER) reply --letters $(LETTERS)
$(LETTERS):
	@$(DRIVER) reply --letters $@
bundle:
	@$(DRIVER) bundle --revision "$(REVISION)" --letters $(LETTERS)
help:
	@printf '%s\n' '  all          Build combined, editor and individual letters (default)' 	  '  responses    Build the combined letter' '  editor       Build the editor letter' 	  '  $(addprefix reviewer,$(REVIEWERS)) Build individual reviewer letters' 	  '  bundle       Build letters and append the matching manuscript comparison' 	  '  check-tools  Check compilation, comparison and PDF merging tools' 	  '  clean        Remove auxiliaries; retain final PDFs' 	  '  distclean    Remove all generated outputs' '  help         Show applicable commands without TeX' 'PDFs: stage folder; auxiliaries: build/' 	  'Revision: $(REVISION)' 'Example: make reviewer1; make bundle';
check-tools:
	@$(DRIVER) check-tools --merge
clean distclean:
	@$(DRIVER) $@

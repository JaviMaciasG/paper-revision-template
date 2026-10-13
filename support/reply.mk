.DEFAULT_GOAL := all
BASH_CMD ?= bash
REVISION ?=
REVIEWERS ?= 1 2
COVER ?= 0
TEMPLATE_SUPPORT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DRIVER = $(BASH_CMD) "$(TEMPLATE_SUPPORT)/build.sh"
REVIEWER_DRIVER = $(BASH_CMD) "$(TEMPLATE_SUPPORT)/reviewers.sh"
LETTERS := responses editor $(addprefix reviewer,$(REVIEWERS))
.PHONY: all help check-tools bundle clean distclean add-reviewer remove-reviewer info-reviewer $(LETTERS)
all:
	@$(DRIVER) reply --revision "$(REVISION)"
$(LETTERS):
	@$(DRIVER) reply --revision "$(REVISION)" --letters $@
bundle:
	@$(DRIVER) bundle --revision "$(REVISION)" --cover "$(COVER)"
add-reviewer remove-reviewer info-reviewer:
	@$(REVIEWER_DRIVER) $@ --round "$(ROUND)" --reviewer "$(REVIEWER)"
help:
	@printf '%s\n' '  all             Combined, editor, and configured reviewer letters (default)' \
	 '  responses       Build the combined letter' '  editor          Build the editor letter' \
	 '  $(addprefix reviewer,$(REVIEWERS)) Build individual letters' \
	 '  add-reviewer     Add next reviewer here; optional REVIEWER=X' \
	 '  remove-reviewer  Remove untouched reviewer here: REVIEWER=X' \
	 '  info-reviewer    Show this round and its reviewer count' \
	 '  bundle           Append comparison; COVER=1 adds a cover (default $(COVER))' \
	 '  check-tools      Check required tools' '  clean            Remove auxiliaries; keep PDFs' \
	 '  distclean        Remove generated files; keep sources and removal guards' \
	 '  help             Show this help without TeX' 'Revision: $(REVISION)' \
	 'PDFs: reply folder; auxiliaries: build/';
check-tools:
	@$(DRIVER) check-tools --merge
clean distclean:
	@$(DRIVER) $@

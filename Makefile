.DEFAULT_GOAL := all
BASH_CMD ?= bash
MANUSCRIPTS := original $(sort $(wildcard revised[0-9]*))
REPLIES := $(sort $(wildcard reply[0-9]*))
STAGES := $(MANUSCRIPTS) $(REPLIES)
.PHONY: all help check-tools init-project new-round add-reviewer remove-reviewer info-reviewer zip clean distclean test container container-bundle bundle $(STAGES)
all: $(STAGES)
$(STAGES):
	+$(MAKE) -C "$@" all
help:
	@printf '%s\n' 'IEEE manuscript and rebuttal template' \
	 '  all              Build PDFs beside sources; auxiliaries stay in build/ (default)' \
	 '  help             Show this help without TeX' \
	 '  check-tools      Check Bash, archive, TeX, and PDF tools' \
	 '  init-project     Create an author project: DEST=../my-paper' \
	 '  new-round        Create the first or next revisedN/replyN pair' \
	 '  add-reviewer     Add the next number: ROUND=N; optional REVIEWER=X' \
	 '  remove-reviewer  Remove an untouched scaffold: ROUND=N REVIEWER=X' \
	 '  info-reviewer    Report all rounds; optional ROUND=N' \
	 '  bundle           Append diffs to letters; COVER=1 adds a note page' \
	 '  zip              Create standalone manuscript source archives' \
	 '  clean            Remove auxiliaries, retaining PDFs and ZIPs' \
	 '  distclean        Remove generated outputs, preserving source figures and guards' \
	 '  test             Run Bash integration tests, including the README walkthrough' \
	 '  container        Build all documents in the container' \
	 '  container-bundle Build bundles in the container; optional COVER=1';
check-tools:
	@$(BASH_CMD) support/build.sh check-tools --merge
init-project:
	@$(BASH_CMD) support/project.sh init-project --dest "$(DEST)"
new-round:
	@$(BASH_CMD) support/project.sh new-round
add-reviewer remove-reviewer info-reviewer:
	@$(BASH_CMD) support/reviewers.sh $@ --round "$(ROUND)" --reviewer "$(REVIEWER)"
zip:
	@set -e; for stage in $(MANUSCRIPTS); do $(MAKE) -C "$$stage" zip; done
bundle:
	@set -e; for stage in $(REPLIES); do $(MAKE) -C "$$stage" bundle; done
clean distclean:
	@set -e; for stage in $(STAGES); do $(MAKE) -C "$$stage" $@; done
test:
	@$(BASH_CMD) tests/run.sh
container:
	@sh support/container.sh all
container-bundle:
	@sh support/container.sh bundle $(if $(filter undefined,$(origin COVER)),,COVER="$(COVER)")

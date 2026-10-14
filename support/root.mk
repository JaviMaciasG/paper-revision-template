MANUSCRIPTS := original $(sort $(wildcard revised[0-9]*))
REPLIES := $(sort $(wildcard reply[0-9]*))
STAGES := $(MANUSCRIPTS) $(REPLIES)
.PHONY: git-init github-init current status submission update-project update-template all docs help check-tools init-project new-round remove-round restore-round add-reviewer remove-reviewer info-reviewer zip clean distclean test bundle $(STAGES)
all: $(STAGES)

DOC_SUPPORT := support/docs.sh support/docs.lua support/docs-header.tex support/common.sh support/latexmkrc
docs: README.pdf HOWTO.pdf
README.pdf HOWTO.pdf: %.pdf: %.md $(DOC_SUPPORT)
	@$(BASH_CMD) support/docs.sh build "$*"

$(STAGES):
	+$(MAKE) -C "$@" all
help:
	@printf '%s\n' 'IEEE manuscript and rebuttal template' \
	 '  all              Build PDFs beside sources; auxiliaries stay in build/ (default)' \
	 '  help             Show this help without TeX' \
	 '  check-tools      Check Bash, archive, TeX, and PDF tools' \
	 '  init-project     Create an author project: DEST=../my-paper' \
	 '  new-round        Create next round; optional REVIEWERS="1 3 4"' \
	 '  current          Build latest manuscript, comparison, and plain letters' \
	 '  status           Show rounds, outputs, TODOs, and local Git information' \
	 '  git-init         Preview sources and confirm the initial Git commit' \
	 '  github-init      Create/connect SSH origin; optional REPO=owner/name VISIBILITY=public' \
	 '  submission       Prepare latest submission; optional ROUND=N COVER=1' \
	 '  update-project   Preview author update: DEST=path; APPLY=1 applies' \
	 '  update-template  Preview update from FROM=template-path; APPLY=1 applies' \
	 '  remove-round     Archive latest round: ROUND=N (publication root only)' \
	 '  restore-round    Restore next round: ROUND=N; optional ARCHIVE=name' \
	 '  add-reviewer     Add reviewer: ROUND=N; optional REVIEWER=X (publication only)' \
	 '  remove-reviewer  Remove untouched reviewer: ROUND=N REVIEWER=X (publication only)' \
	 '  info-reviewer    Report all rounds; optional ROUND=N' \
	 '  bundle           Append diffs to letters; COVER=1 adds a note page' \
	 '  zip              Create manuscript source ZIPs in stage folders' \
	 '  docs             Build numbered README.pdf and HOWTO.pdf (requires Pandoc)' \
	 '  clean            Remove auxiliaries, retaining PDFs and ZIPs' \
	 '  distclean        Remove generated outputs, preserving source figures and guards' \
	 '  test             Run Bash integration tests, including the HOWTO walkthrough';
check-tools:
	@$(BASH_CMD) support/build.sh check-tools --merge
init-project:
	@$(BASH_CMD) support/project.sh init-project --dest "$(DEST)"
new-round:
	@$(BASH_CMD) support/project.sh new-round $(if $(filter undefined,$(origin REVIEWERS)),,--reviewers "$(REVIEWERS)")
remove-round restore-round:
	@$(BASH_CMD) support/rounds.sh $@ --round "$(ROUND)" --archive "$(ARCHIVE)"
add-reviewer remove-reviewer info-reviewer:
	@$(BASH_CMD) support/reviewers.sh $@ --round "$(ROUND)" --reviewer "$(REVIEWER)"
zip:
	@set -e; for stage in $(MANUSCRIPTS); do $(MAKE) -C "$$stage" zip; done
bundle:
	@set -e; for stage in $(REPLIES); do $(MAKE) -C "$$stage" bundle; done
clean distclean:
	@set -e; for stage in $(STAGES); do $(MAKE) -C "$$stage" $@; done
	@$(BASH_CMD) support/docs.sh $@
test:
	@$(BASH_CMD) tests/run.sh

current status submission:
	+@$(BASH_CMD) support/workflow.sh $@ --round "$(ROUND)" $(if $(filter undefined,$(origin COVER)),,--cover "$(COVER)")
update-project:
	@$(BASH_CMD) support/update.sh --dest "$(DEST)" --apply "$(or $(APPLY),0)"
update-template:
	@test -n "$(FROM)" || { printf '%s\n' 'Set FROM=/path/to/template-checkout' >&2; exit 1; }
	@$(BASH_CMD) "$(FROM)/support/update.sh" --dest "$(CURDIR)" --apply "$(or $(APPLY),0)"

# Export user-supplied data instead of interpolating it into shell command text.
export TEMPLATE_GIT_REPO := $(REPO)
export TEMPLATE_GIT_VISIBILITY := $(or $(VISIBILITY),private)
git-init github-init:
	@$(BASH_CMD) support/git.sh $@

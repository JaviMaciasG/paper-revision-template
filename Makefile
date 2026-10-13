.DEFAULT_GOAL := all
PYTHON ?= python3
MANUSCRIPTS := original $(sort $(wildcard revised[0-9]*))
REPLIES := $(sort $(wildcard reply[0-9]*))
STAGES := $(MANUSCRIPTS) $(REPLIES)
.PHONY: all help check-tools new-round zip clean distclean test container container-bundle bundle $(STAGES)
all: $(STAGES)
$(STAGES):
	+$(MAKE) -C $@ all
help:
	@printf '%s\n' 'IEEE manuscript and rebuttal template' 	  '  all             Build all manuscripts, comparisons and response letters (default)' 	  '  help            Show commands; no TeX installation needed' 	  '  check-tools     Check compilation, comparison and bundle dependencies' 	  '  new-round       Create the next revisedN/replyN pair without overwriting' 	  '  bundle          Append the revision diff to each response letter' 	  '  zip             Create standalone manuscript source archives' 	  '  clean           Remove auxiliary outputs, retaining final PDFs and ZIPs' 	  '  distclean       Remove all generated outputs' 	  '  test            Run workflow integration checks in temporary copies' 	  '  container       Build all documents in the pinned container' 	  '  container-bundle Build response bundles in the pinned container' 	  'Examples: make -C revised1 diff; make -C reply1 reviewer1; make -j4';
check-tools:
	@$(PYTHON) support/template.py check-tools --merge
new-round:
	@$(PYTHON) support/template.py new-round
zip:
	@set -e; for stage in $(MANUSCRIPTS); do $(MAKE) -C "$$stage" zip; done
bundle:
	@set -e; for stage in $(REPLIES); do $(MAKE) -C "$$stage" bundle; done
clean distclean:
	@set -e; for stage in $(STAGES); do $(MAKE) -C "$$stage" $@; done
test:
	@$(PYTHON) -m unittest discover -s tests -v
container:
	@sh support/container.sh all
container-bundle:
	@sh support/container.sh bundle

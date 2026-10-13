# Standalone manuscript build rules. The packager prepends the MIT notice.
.DEFAULT_GOAL := all
.PHONY: all paper help clean distclean

all: paper

paper:
	@for tool in latexmk pdflatex bibtex; do \
		command -v "$$tool" >/dev/null 2>&1 || { printf 'Missing tool: %s\n' "$$tool" >&2; exit 1; }; \
	done
	@test ! -L build || { printf '%s\n' 'Refusing a symlinked build directory' >&2; exit 1; }
	@mkdir -p build
	@latexmk -norc -pdf -interaction=nonstopmode -halt-on-error -file-line-error \
		-recorder -auxdir=build -outdir=. -emulate-aux-dir \
		-e '$$pdf_mode=1; $$bibtex_use=2; $$max_repeat=8; $$bibtex_fudge=0;' \
		'-pdflatex=pdflatex -interaction=nonstopmode -halt-on-error -file-line-error -synctex=1 %O %S' paper.tex
	@if grep -Eq 'LaTeX Warning: Citation .*undefined|There were undefined (references|citations)' build/paper.log; then \
		printf '%s\n' 'Unresolved citations/references; see build/paper.log' >&2; exit 1; \
	fi
	@if [ -f build/paper.blg ] && grep -q '\\bibdata{' build/paper.aux && \
		grep -q 'Warning--I didn.t find a database entry' build/paper.blg; then \
		printf '%s\n' 'Missing bibliography entry; see build/paper.blg' >&2; exit 1; \
	fi

help:
	@printf '%s\n' 'Standalone manuscript sources; install latexmk and TeX Live with the required packages.' \
		'  all / paper  Compile paper.tex; paper.pdf appears beside the source' \
		'  clean        Remove auxiliaries; retain paper.pdf and source assets' \
		'  distclean    Also remove paper.pdf' '  help         Show available commands' \
		'Auxiliaries: build/; bibliography: BibTeX when used by the manuscript.'

clean:
	@test ! -L build || { printf '%s\n' 'Refusing to clean a symlinked build directory' >&2; exit 1; }
	@rm -rf -- build
	@rm -f -- paper.synctex paper.synctex.gz

distclean: clean
	@rm -f -- paper.pdf

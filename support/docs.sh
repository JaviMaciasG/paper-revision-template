#!/usr/bin/env bash
# Render project Markdown guides; manuscript builds do not depend on Pandoc.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
setup_traps
command=${1:-}; name=${2:-}
[ "$(pwd -P)" = "$TEMPLATE_ROOT" ] || fail 'Run documentation targets from the project root'
[ ! -L "$TEMPLATE_ROOT/build" ] && [ ! -L "$TEMPLATE_ROOT/build/docs" ] || fail 'Documentation build directories must not be symlinks'
case "$command" in
    clean|distclean)
        lock "$TEMPLATE_ROOT"
        rm -rf -- "$TEMPLATE_ROOT/build/docs"
        if [ "$command" = distclean ]; then rm -f -- "$TEMPLATE_ROOT/README.pdf" "$TEMPLATE_ROOT/HOWTO.pdf"; fi
        if [ -d "$TEMPLATE_ROOT/build" ]; then rmdir -- "$TEMPLATE_ROOT/build" 2>/dev/null || :; fi
        exit 0;;
    build) case "$name" in README|HOWTO) ;; *) fail 'Documentation source must be README or HOWTO';; esac;;
    *) fail "Unknown documentation command: $command";;
esac
require pandoc latexmk pdflatex kpsewhich
for package in fvextra.sty xurl.sty xcolor.sty lmodern.sty booktabs.sty longtable.sty hyperref.sty etoolbox.sty needspace.sty tcolorbox.sty; do
    [ -n "$(kpsewhich "$package")" ] || fail "Documentation PDFs need the LaTeX package $package (install TeX Live latex-extra and fonts-recommended packages)"
done
lock "$TEMPLATE_ROOT"
directory=$TEMPLATE_ROOT/build/docs/$name
[ ! -L "$directory" ] || fail "Documentation build directory must not be a symlink: $directory"
mkdir -p -- "$directory"
pandoc "$TEMPLATE_ROOT/$name.md" --from=markdown --to=latex --standalone \
    --lua-filter="$TEMPLATE_SUPPORT/docs.lua" --include-in-header="$TEMPLATE_SUPPORT/docs-header.tex" \
    --highlight-style=tango --number-sections --toc --toc-depth=3 \
    -V documentclass=article -V fontsize=11pt -V papersize=a4 -V geometry:margin=22mm \
    -V secnumdepth=3 -V colorlinks=true -V linkcolor=MidnightBlue -V urlcolor=MidnightBlue \
    -M author="Javier Macias-Guarasa" -M date= --output="$directory/$name.tex.tmp"
update_file "$directory/$name.tex.tmp" "$directory/$name.tex"
(cd -- "$directory" && latexmk -norc -r "$TEMPLATE_SUPPORT/latexmkrc" -pdf -bibtex- \
    -interaction=nonstopmode -halt-on-error -file-line-error "$name.tex")
[ -s "$directory/$name.pdf" ] || fail "Documentation compilation did not produce $name.pdf"
make_temp "$TEMPLATE_ROOT/build/docs"
cp -- "$directory/$name.pdf" "$TASK_TEMP/$name.pdf"
mv -- "$TASK_TEMP/$name.pdf" "$TEMPLATE_ROOT/$name.pdf"
printf 'Created %s\n' "$TEMPLATE_ROOT/$name.pdf"

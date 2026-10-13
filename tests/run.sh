#!/usr/bin/env bash
# CLI integration tests; no Python interpreter or packages are used.
source "$(dirname -- "${BASH_SOURCE[0]}")/../support/common.sh" || exit 1
TEST_SOURCE_ROOT=$TEMPLATE_ROOT
TEST_SCRIPT=$TEST_SOURCE_ROOT/tests/run.sh
setup_traps
assert_file() { [ -f "$1" ] || fail "Expected file: $1"; }
assert_absent() { [ ! -e "$1" ] || fail "Unexpected file: $1"; }
assert_has() { grep -Fq -- "$2" "$1" || fail "Expected '$2' in $1"; }
assert_not() { ! grep -Fq -- "$2" "$1" || fail "Unexpected '$2' in $1"; }
ok() {
    if ! "$@" > "$CASE_DIR/command.log" 2>&1; then tail -60 "$CASE_DIR/command.log" >&2; fail "Command failed: $*"; fi
}
bad() { if "$@" > "$CASE_DIR/command.log" 2>&1; then fail "Unexpected command success: $*"; fi; }
pages() {
    if command -v pdfinfo >/dev/null 2>&1; then pdfinfo "$1" | awk '/^Pages:/ {print $2}'
    else gs -q -dNODISPLAY "--permit-file-read=$1" "-sPDFname=$1" -c 'PDFname (r) file runpdfbegin pdfpagecount = quit'; fi
}
pdf_text() {
    if command -v pdftotext >/dev/null 2>&1; then pdftotext "$1" -
    else gs -q -dBATCH -dNOPAUSE -sDEVICE=txtwrite -sOutputFile=- "$1"; fi
}
init_case() {
    make_temp
    CASE_DIR=$TASK_TEMP
    project=$CASE_DIR/'project with spaces'; mkdir -- "$project"
    for name in Makefile README.md LICENSE .gitignore; do cp -- "$TEST_SOURCE_ROOT/$name" "$project/$name"; done
    for name in support tests .github; do copy_sources "$TEST_SOURCE_ROOT/$name" "$project/$name"; done
    for stage in original revised1 reply1; do copy_sources "$TEST_SOURCE_ROOT/tests/fixtures/$stage" "$project/$stage"; done
    # Any accidental Python use fails the command, even if Python is installed locally.
    mkdir -- "$CASE_DIR/no-python"
    for name in python python3; do
        printf '#!/bin/sh\nprintf "Unexpected Python invocation\\n" >&2\nexit 88\n' > "$CASE_DIR/no-python/$name"
        chmod +x "$CASE_DIR/no-python/$name"
    done
    export PATH="$CASE_DIR/no-python:$PATH"
    cd -- "$project"
}
fresh_author() {
    author=$CASE_DIR/'author project'
    ok make init-project "DEST=$author"
    cd -- "$author"
}
test_help_tools() {
    for stage in . original revised1 reply1; do
        ok make -C "$stage" help; assert_has "$CASE_DIR/command.log" help
    done
    mkdir -- "$CASE_DIR/minimal-bin"
    ln -s "$(command -v make)" "$CASE_DIR/minimal-bin/make"
    for stage in . original revised1 reply1; do ok env PATH="$CASE_DIR/minimal-bin" make -C "$stage" help; done
    ok make check-tools
    bad env PATH="$CASE_DIR/minimal-bin" make check-tools "BASH_CMD=$(command -v bash)"
}
test_build_incremental_archives() {
    ok make -j4
    for file in original/paper.pdf revised1/paper.pdf revised1/paper-diff.pdf reply1/responses.pdf reply1/editor.pdf reply1/reviewer1.pdf reply1/reviewer2.pdf; do assert_file "$file"; done
    for stage in original revised1 reply1; do assert_absent "$stage/build/paper.pdf"; done
    for log in original/build/*.log revised1/build/*.log reply1/build/*.log; do assert_not "$log" 'undefined'; assert_not "$log" 'Overfull'; done
    assert_has revised1/build/paper-diff.tex '\bibitem{legacy}'
    assert_has revised1/build/paper-diff.tex '\bibitem{automation}'
    cp revised1/paper-diff.pdf "$CASE_DIR/noop.pdf"
    ok make -C revised1 diff; cmp -s revised1/paper-diff.pdf "$CASE_DIR/noop.pdf" || fail 'No-op comparison changed its PDF'
    sleep 1
    printf '\nDependency verification sentence.\n' >> revised1/sections/comparisons.tex
    sed 's/An Automated Build Checklist/A Revised Automated Build Checklist/' revised1/paper.bib > revised1/paper.bib.tmp; mv revised1/paper.bib.tmp revised1/paper.bib
    ok make -C reply1 bundle
    assert_has revised1/build/paper-expanded.tex 'Dependency verification sentence.'
    assert_has revised1/build/paper-expanded.tex 'A revised automated build checklist'
    ok make zip
    for stage in original revised1; do
        mkdir -- "$CASE_DIR/extracted-$stage"
        (cd -- "$CASE_DIR/extracted-$stage" && unzip -q "$project/$stage/build/paper.zip" && make > "$CASE_DIR/extraction.log" 2>&1) || fail 'Archive did not compile independently'
        assert_file "$CASE_DIR/extracted-$stage/paper.pdf"
        assert_file "$CASE_DIR/extracted-$stage/support/build.sh"
    done
    printf 'PDF figure source\n' > revised1/illustration.pdf
    printf 'Nested PDF figure source\n' > revised1/figures/paper.pdf
    ok make clean
    assert_file revised1/paper-diff.pdf; assert_file revised1/build/paper.zip
    assert_absent revised1/build/paper.aux
    ok make distclean
    assert_absent revised1/build; assert_absent reply1/responses-with-diff.pdf
    assert_file revised1/illustration.pdf; assert_file revised1/figures/paper.pdf
    ok make -C original
    rm -rf -- original/build
    ok make -C original distclean; assert_absent original/paper.pdf
}
test_bibliography() {
    ok make -C reply1
    assert_has reply1/build/responses.bbl '\bibitem{guide}'
    assert_has reply1/build/responses.bbl '\bibitem{bibliography}'
    assert_has reply1/build/responses.bbl '\bibitem{rebuttalnote}'
    assert_has reply1/build/editor.bbl '\bibitem{guide}'
    assert_not reply1/build/editor.bbl '\bibitem{rebuttalnote}'
    assert_has reply1/build/reviewer2.bbl '\bibitem{rebuttalnote}'
    assert_not reply1/build/reviewer2.bbl '\bibitem{guide}'
    assert_not reply1/build/reviewer1.aux '\bibdata'
    printf '%% A comment containing \\cite{nonexistent} is not an executed citation.\n' >> reply1/reviewer1-comments.tex
    ok make -C reply1 reviewer1; assert_not reply1/build/reviewer1.aux '\bibdata'
    sleep 1
    sed 's/A Fictional Checklist for Reviewer Responses/A Changed Fictional Checklist/' revised1/paper.bib > revised1/paper.bib.tmp; mv revised1/paper.bib.tmp revised1/paper.bib
    ok make -C reply1 reviewer2; assert_has reply1/build/reviewer2.bbl 'A changed fictional checklist'
    printf '\n\\response{An optional citation \\cite[page 2]{guide}.}\n' >> reply1/reviewer1-comments.tex
    ok make -C reply1 reviewer1; assert_has reply1/build/reviewer1.bbl '\bibitem{guide}'
    sed '/An optional citation/d' reply1/reviewer1-comments.tex > reply1/reviewer1-comments.tex.tmp; mv reply1/reviewer1-comments.tex.tmp reply1/reviewer1-comments.tex
    ok make -C reply1 reviewer1
    assert_not reply1/build/reviewer1.aux '\bibdata'
    pdf_text "$project/reply1/reviewer1.pdf" > "$CASE_DIR/letter.txt"; assert_not "$CASE_DIR/letter.txt" 'References'
    printf '\n\\nocite{guide}\n' >> reply1/reviewer1-comments.tex
    ok make -C reply1 reviewer1; assert_has reply1/build/reviewer1.bbl '\bibitem{guide}'
    printf '\n\\response{Bad key \\cite{missing-key}.}\n' >> reply1/reviewer1-comments.tex
    bad make -C reply1 reviewer1
    # A new project's citation-free skeletons work with an empty or absent database.
    fresh_author; ok make new-round
    : > revised1/paper.bib
    ok make -C reply1
    assert_not reply1/build/responses.aux '\bibdata'
    assert_absent reply1/build/responses.blg
    rm -- revised1/paper.bib
    ok make -C reply1
    printf '\n\\response{Needs a missing database \\cite{guide}.}\n' >> reply1/reviewer1-comments.tex
    bad make -C reply1 reviewer1
}
test_management_and_guards() {
    bad make remove-reviewer ROUND=1 REVIEWER=1
    assert_has "$CASE_DIR/command.log" 'Refusing removal'
    fresh_author; ok make new-round
    ok make info-reviewer; assert_has "$CASE_DIR/command.log" '1 2'
    printf 'source figure\n' > revised1/figure.pdf
    ok make -C reply1 remove-reviewer REVIEWER=2
    assert_not reply1/Makefile 'REVIEWERS := 1 2'
    assert_absent reply1/reviewer2.tex
    ok make -C reply1 add-reviewer
    assert_file reply1/reviewer2.tex
    ok make add-reviewer ROUND=1 REVIEWER=4
    assert_has reply1/reviewer4.tex 'reviewer 4'
    assert_has reply1/reviewer4-comments.tex 'reviewer 4'
    ok make remove-reviewer ROUND=1 REVIEWER=4
    assert_absent reply1/reviewer4.tex
    bad make -C reply1 add-reviewer ROUND=2
    bad make -C reply1 remove-reviewer ROUND=2 REVIEWER=1
    bad make add-reviewer
    bad make remove-reviewer ROUND=1
    bad make -C reply1 add-reviewer REVIEWER=0
    cp reply1/Makefile "$CASE_DIR/original-config"
    printf '\nAuthor content must not be removed.\n' >> reply1/reviewer1-comments.tex
    bad make -C reply1 remove-reviewer REVIEWER=1
    cmp -s reply1/Makefile "$CASE_DIR/original-config" || fail 'Refusal modified configuration'
    assert_has reply1/reviewer1-comments.tex 'Author content must not be removed.'
    printf '\n%% Customized wrapper\n' >> reply1/reviewer2.tex
    bad make -C reply1 remove-reviewer REVIEWER=2
    # Newly reset answers are safe, but a custom wrapper stays protected across rounds.
    ok make new-round
    assert_file reply2/.reviewer-scaffolds/reviewer1-comments.tex
    assert_not reply2/reviewer1-comments.tex 'Author content'
    ok make -C reply2 remove-reviewer REVIEWER=1
    bad make -C reply2 remove-reviewer REVIEWER=2
    assert_file revised1/figure.pdf
    # Missing provenance is protected even for an apparently blank file.
    rm -- reply1/.reviewer-scaffolds/reviewer1-comments.tex
    bad make -C reply1 remove-reviewer REVIEWER=1
    ok make info-reviewer
    ok make -C reply1 info-reviewer; assert_not "$CASE_DIR/command.log" 'reply2 '
    mv reply2/reviewer2.tex reply2/reviewer2.saved
    bad make info-reviewer; assert_has "$CASE_DIR/command.log" 'Missing reviewer 2 files'
    mv reply2/reviewer2.saved reply2/reviewer2.tex
}
test_editor_only_and_rounds() {
    fresh_author
    ok make info-reviewer; assert_has "$CASE_DIR/command.log" 'No review rounds yet'
    ok make new-round
    ok make -C reply1 remove-reviewer REVIEWER=1
    ok make -C reply1 remove-reviewer REVIEWER=2
    ok make -j4
    assert_has reply1/build/reply-config.tex 'the editor'
    assert_not reply1/build/reviewer-inputs.tex 'reviewer'
    pdf_text "$author/reply1/responses.pdf" > "$CASE_DIR/editor-only.txt"
    assert_has "$CASE_DIR/editor-only.txt" 'the editor'
    ok make -C reply1 bundle COVER=1
    ok make new-round
    assert_has reply2/Makefile 'REVIEWERS := '
    assert_absent reply2/reviewer1.tex
    ok make -j4
    ok make info-reviewer
    mkdir -- reply3; printf 'keep\n' > reply3/keep.txt
    bad make new-round
    assert_file reply3/keep.txt; assert_absent revised3
}
test_covers_metadata_cleanup() {
    ok make -C reply1
    cp reply1/reviewer1.pdf "$CASE_DIR/plain.pdf"
    ok make -C reply1 bundle COVER=0
    plain_pages=$(pages "$project/reply1/responses-with-diff.pdf")
    ok make bundle COVER=1
    [ "$(pages "$project/reply1/responses-with-diff.pdf")" = "$((plain_pages + 1))" ] || fail 'Cover did not add one page'
    cmp -s reply1/reviewer1.pdf "$CASE_DIR/plain.pdf" || fail 'Cover changed a plain letter'
    assert_file reply1/build/rebuttal-cover.pdf; assert_absent reply1/rebuttal-cover.pdf
    pdf_text "$project/reply1/responses-with-diff.pdf" > "$CASE_DIR/covered.txt"
    assert_has "$CASE_DIR/covered.txt" 'Note to the reviewers:'
    set_cfg reply1/Makefile COVER 1
    ok make -C reply1 bundle
    [ "$(pages "$project/reply1/responses-with-diff.pdf")" = "$((plain_pages + 1))" ] || fail 'Persistent cover default ignored'
    ok make -C reply1 bundle COVER=0
    [ "$(pages "$project/reply1/responses-with-diff.pdf")" = "$plain_pages" ] || fail 'Cover override ignored'
    bad make -C reply1 bundle COVER=2
    sed 's/EXAMPLE-001/NEW-ID-2026/' reply1/metadata.tex > reply1/metadata.tex.tmp; mv reply1/metadata.tex.tmp reply1/metadata.tex
    ok make -C reply1 bundle COVER=1
    pdf_text "$project/reply1/responses-with-diff.pdf" > "$CASE_DIR/updated.txt"
    assert_has "$CASE_DIR/updated.txt" 'NEW-ID-2026'; assert_not "$CASE_DIR/updated.txt" 'EXAMPLE-001'
    ok make new-round; assert_has reply2/Makefile 'COVER := 1'
    assert_file reply2/.reviewer-scaffolds/reviewer1-comments.tex
    ok make clean; assert_absent reply1/build/rebuttal-cover.pdf
    assert_file reply1/responses-with-diff.pdf
    assert_file reply2/.reviewer-scaffolds/reviewer1-comments.tex
}
test_init_failures() {
    bad make init-project
    bad make init-project "DEST=$project"
    bad make init-project "DEST=$project/inside"
    assert_absent inside
    fresh_author
    assert_absent revised1; assert_absent reply1; assert_absent .git
    assert_has original/paper.tex 'Replace \texttt{original/paper.tex}'
    assert_has original/paper.tex '\texttt{original/paper.bib}'
    ok make -j4
    ok make new-round
    assert_file reply1/.reviewer-scaffolds/reviewer1.tex
    assert_file reply1/.reviewer-scaffolds/reviewer1-comments.tex
    [ "$(grep -c '\\item \\reviewercomment' reply1/reviewer1-comments.tex)" = 3 ] || fail 'Missing guided scaffold items'
    printf '\n\\response{Old round text.}\n' >> reply1/reviewer1-comments.tex
    ok make new-round
    assert_not reply2/reviewer1-comments.tex 'Old round text'
    assert_has reply2/Makefile '../revised2'
    bad make -C revised2 diff BASELINE=../missing
    printf '\\documentclass{article}\n\\begin{document}\n\\notacommand\n\\end{document}\n' > original/paper.tex
    bad make -C original
    if [ -z "${TEMPLATE_TEST_NESTED:-}" ]; then
        ok env TEMPLATE_TEST_NESTED=1 make test
    fi
}
test_ghostscript_fallback() {
    command -v gs >/dev/null 2>&1 || return 0
    mkdir -- "$CASE_DIR/merge-tools"
    # Retain all installed tools except pdfunite and Python, forcing the fallback.
    for tool in bash make dirname pwd cat awk sed find cp mv rm mkdir rmdir mktemp cmp sleep head grep sort zip unzip latexmk pdflatex bibtex kpsewhich gs touch perl uname date tr wc basename ln readlink env latexpand latexdiff diff; do
        path=$(command -v "$tool" || :); [ -z "$path" ] || ln -s "$path" "$CASE_DIR/merge-tools/$tool"
    done
    ok env PATH="$CASE_DIR/merge-tools" make -C reply1 bundle COVER=1
    assert_file reply1/responses-with-diff.pdf
}
check_email() {
    local email=$1 role=$2 tex=$3
    awk -v role="$role" '
      /^EDITOR \(/ || /^REVIEWER [12] \(/ {active=(index($0,role)==1); next}
      /^Please use / || /^The Fictional Editor/ {active=0}
      active && NF {sub(/^[0-9]+\. /, ""); sub(/^- /, ""); print}' "$email" > "$CASE_DIR/email-comments.txt"
    sed -n 's/.*\\reviewercomment{\(.*\)}.*/\1/p' "$tex" > "$CASE_DIR/tex-comments.txt"
    cmp -s "$CASE_DIR/email-comments.txt" "$CASE_DIR/tex-comments.txt" || fail "Email/TeX mismatch: $tex"
}
test_readme_walkthrough() {
    # All fenced FILE blocks are compared against the actual walkthrough assets.
    while IFS= read -r asset; do
        awk -v marker="<!-- FILE $asset -->" '
          $0==marker {found=1; next} found && /^```/ && !body {body=1; next}
          body && /^```/ {exit} body {print}' "$project/README.md" > "$CASE_DIR/readme-file"
        cmp -s "$CASE_DIR/readme-file" "$project/$asset" || fail "README asset differs: $asset"
    done < <(sed -n 's/^<!-- FILE \(.*\) -->$/\1/p' "$project/README.md")
    for round in 1 2; do
        check_email "$project/support/walkthrough/emails/round$round.txt" EDITOR "$project/support/walkthrough/reply$round/editor-comments.tex"
        check_email "$project/support/walkthrough/emails/round$round.txt" 'REVIEWER 1' "$project/support/walkthrough/reply$round/reviewer1-comments.tex"
        check_email "$project/support/walkthrough/emails/round$round.txt" 'REVIEWER 2' "$project/support/walkthrough/reply$round/reviewer2-comments.tex"
    done
    {
        printf '#!/usr/bin/env bash\nset -e -o pipefail\n'
        awk '/^<!-- RUN -->$/ {nextblock=1; next}
          nextblock && /^```bash$/ {body=1; nextblock=0; next}
          body && /^```/ {body=0; print ""; next} body {print}' "$project/README.md"
    } > "$CASE_DIR/walkthrough.sh"
    grep -q 'init-project' "$CASE_DIR/walkthrough.sh" || fail 'README lacks the executable walkthrough'
    ok bash "$CASE_DIR/walkthrough.sh"
    guide=$CASE_DIR/guided-paper
    assert_file "$guide/revised2/paper.pdf"; assert_file "$guide/reply2/responses-with-diff.pdf"
    assert_file "$guide/submission-check/paper.pdf"
    for stage in original revised1; do cmp -s "$guide/$stage/paper.tex" "$guide/support/walkthrough/$stage/paper.tex" || fail 'Earlier manuscript changed'; done
    for stage in reply1 reply2; do
        assert_has "$guide/$stage/Makefile" 'REVIEWERS := 1 2'
        assert_absent "$guide/$stage/reviewer3.tex"
    done
}
CASES=(test_help_tools test_build_incremental_archives test_bibliography test_management_and_guards test_editor_only_and_rounds test_covers_metadata_cleanup test_init_failures test_ghostscript_fallback test_readme_walkthrough)
if [ "${1:-}" = --case ]; then
    init_case
    "$2"
    exit 0
fi
failed=0
for name in "${CASES[@]}"; do
    printf '%s ... ' "$name"
    if bash "$TEST_SCRIPT" --case "$name" > "${TMPDIR:-/tmp}/paper-template-$name.log" 2>&1; then printf 'ok\n'
    else printf 'FAIL\n'; tail -65 "${TMPDIR:-/tmp}/paper-template-$name.log" >&2; failed=$((failed + 1)); fi
done
[ "$failed" = 0 ] || fail "$failed integration groups failed"
printf 'All %s Bash integration groups passed.\n' "${#CASES[@]}"

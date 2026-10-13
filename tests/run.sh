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
    # Workflow fixtures model editable publication projects, not the protected clone.
    set_cfg "$project/Makefile" PROJECT_ROLE publication
    for name in support tests; do copy_sources "$TEST_SOURCE_ROOT/$name" "$project/$name"; done
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
    assert_has Makefile 'PROJECT_ROLE := publication'
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
snapshot_protected() {
    rm -rf -- "$CASE_DIR/protected-snapshot"
    cp -R -- "$project" "$CASE_DIR/protected-snapshot"
}
refused_protected() {
    bad "$@"
    assert_has "$CASE_DIR/command.log" 'requires an initialized publication project'
    diff -r "$CASE_DIR/protected-snapshot" "$project" > "$CASE_DIR/protection-diff" || fail 'Protected command changed files or directories'
}
test_template_protection() {
    set_cfg Makefile PROJECT_ROLE template
    snapshot_protected
    refused_protected make new-round
    refused_protected make add-reviewer ROUND=1
    refused_protected make remove-reviewer ROUND=1 REVIEWER=1
    refused_protected make remove-round ROUND=1
    refused_protected make restore-round ROUND=2
    refused_protected make remove-round ROUND=1 PROJECT_ROLE=publication
    refused_protected make restore-round ROUND=2 PROJECT_ROLE=publication
    refused_protected bash support/rounds.sh remove-round --round 1
    refused_protected bash support/rounds.sh restore-round --round 2
    refused_protected make -C reply1 add-reviewer
    refused_protected make -C reply1 remove-reviewer REVIEWER=1
    refused_protected bash support/project.sh new-round
    refused_protected bash support/reviewers.sh add-reviewer --round 1
    refused_protected bash support/reviewers.sh remove-reviewer --round 1 --reviewer 1
    refused_protected make new-round PROJECT_ROLE=publication
    refused_protected make add-reviewer ROUND=1 PROJECT_ROLE=publication
    refused_protected make -C reply1 remove-reviewer REVIEWER=1 PROJECT_ROLE=publication
    refused_protected env PROJECT_ROLE=publication make -e new-round
    refused_protected env PROJECT_ROLE=publication bash support/reviewers.sh add-reviewer --round 1
    (cd reply1 && refused_protected bash ../support/reviewers.sh add-reviewer) || fail 'Folder-local helper bypassed protection'
    # Even a publication declaration in a stage Makefile cannot grant permission.
    printf '\nPROJECT_ROLE := publication\n' >> reply1/Makefile
    snapshot_protected
    refused_protected make -C reply1 add-reviewer
    # Permission comes only from a valid literal declaration in the root file.
    for role in unknown ''; do
        set_cfg Makefile PROJECT_ROLE "$role"
        snapshot_protected
        refused_protected make new-round
        refused_protected make add-reviewer ROUND=1
        refused_protected make -C reply1 remove-reviewer REVIEWER=1
    done
    sed '/^PROJECT_ROLE[[:space:]]*[:?]*=/d' Makefile > Makefile.tmp; mv Makefile.tmp Makefile
    snapshot_protected
    refused_protected make new-round
    refused_protected bash support/reviewers.sh remove-reviewer --round 1 --reviewer 1
    mv Makefile "$CASE_DIR/root-Makefile"
    snapshot_protected
    refused_protected bash support/project.sh new-round
    mv "$CASE_DIR/root-Makefile" Makefile
    set_cfg Makefile PROJECT_ROLE template
    # Non-mutating workflow commands and generated-output cleanup stay available.
    copy_sources "$project" "$CASE_DIR/protected-sources"
    ok make help; ok make -C reply1 help
    ok make check-tools; ok make info-reviewer; ok make -C reply1 info-reviewer
    ok make -j4
    ok make bundle; ok make zip
    ok make clean
    assert_file original/paper.pdf; assert_file revised1/build/paper.zip
    ok make distclean
    assert_absent original/paper.pdf; assert_absent revised1/build
    copy_sources "$project" "$CASE_DIR/protected-sources-after"
    diff -r "$CASE_DIR/protected-sources" "$CASE_DIR/protected-sources-after" > "$CASE_DIR/protection-diff" || fail 'Building or cleanup changed protected sources'
    fresh_author
    assert_absent .paper-template-role
    ok make new-round
    ok make -C reply1 remove-reviewer REVIEWER=2
    ok make add-reviewer ROUND=1
    ok make new-round
    assert_file revised2/paper.tex
}
test_manuscript_dependencies() {
    fresh_author
    copy_sources "$TEST_SOURCE_ROOT/tests/fixtures/original" "$author/original"
    mkdir -p original/sections/nested original/styles original/figures
    cat > original/copytestclass.cls <<'TEX'
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{copytestclass}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{IEEEtran}}
\ProcessOptions\relax
\LoadClass{IEEEtran}
TEX
    printf '\\ProvidesPackage{copytest}\n\\newcommand{\\CopyTestText}{Custom package text.}\n' > original/copytest.sty
    cp "$(kpsewhich IEEEtran.bst)" original/styles/localrefs.bst
    printf 'Nested input retained.\n' > original/sections/nested/child.tex
    printf 'Input with spaces retained.\n' > 'original/sections/part with spaces.tex'
    printf 'Hidden source retained.\n' > original/.hidden-fragment.tex
    printf 'Ignored source still required.\n' > original/ignored-by-git.tex
    printf 'TikZ-format source retained.\n' > original/figures/local.tikz
    printf 'Unused source omitted.\n' > original/unused.txt
    printf 'Inactive input omitted.\n' > original/sections/inactive.tex
    printf 'Unused SVG omitted.\n' > original/figures/unused.svg
    printf 'Unused log omitted.\n' > original/stale.log
    printf 'Unused build file omitted.\n' > original/stale.aux
    printf '\n/original/ignored-by-git.tex\n' >> .gitignore
    printf '\\documentclass{article}\n\\pagestyle{empty}\n\\begin{document}Source figure.\\end{document}\n' > "$CASE_DIR/figure.tex"
    ok pdflatex -interaction=nonstopmode -halt-on-error "-output-directory=$CASE_DIR" "$CASE_DIR/figure.tex"
    cp "$CASE_DIR/figure.pdf" 'original/figures/sensor plot.pdf'
    cat > original/sections/main.tex <<'TEX'
\CopyTestText
\input{sections/nested/child.tex}
\input{sections/part with spaces.tex}
\input{.hidden-fragment.tex}
\input{ignored-by-git.tex}
\input{figures/local.tikz}
\includegraphics[width=0.07\linewidth]{figures/sensor plot.pdf}
\iffalse\input{sections/inactive.tex}\fi
TEX
    awk '
      /^\\documentclass/ {sub(/IEEEtran/, "copytestclass")}
      /^\\usepackage\{graphicx\}/ {print "\\usepackage{copytest}"}
      /^\\bibliographystyle/ {print "\\input{sections/main.tex}"; print "\\bibliographystyle{styles/localrefs}"; next}
      {print}' original/paper.tex > original/paper.tex.tmp
    mv original/paper.tex.tmp original/paper.tex
    ok make new-round
    assert_file original/build/paper.deps
    for file in paper.tex paper.bib copytestclass.cls copytest.sty styles/localrefs.bst sections/main.tex sections/nested/child.tex 'sections/part with spaces.tex' .hidden-fragment.tex ignored-by-git.tex figures/local.tikz 'figures/sensor plot.pdf'; do
        assert_file "revised1/$file"
        cmp -s "original/$file" "revised1/$file" || fail "Dependency changed: $file"
    done
    for file in unused.txt figures/unused.svg sections/inactive.tex stale.log stale.aux paper.pdf build; do assert_absent "revised1/$file"; done
    # Both the copy and its comparison work when inactive input files are absent.
    ok make -C revised1 diff
    ok make -C original zip
    mkdir "$CASE_DIR/dependency-archive"
    (cd "$CASE_DIR/dependency-archive" && unzip -q "$author/original/build/paper.zip" && make > "$CASE_DIR/dependency-archive.log" 2>&1) || fail 'Dependency archive did not compile independently'
    assert_file "$CASE_DIR/dependency-archive/support/dependencies.sh"
    assert_file "$CASE_DIR/dependency-archive/styles/localrefs.bst"
    assert_file "$CASE_DIR/dependency-archive/figures/sensor plot.pdf"
    assert_absent "$CASE_DIR/dependency-archive/unused.txt"
    # Some TeX installations register texmf.cnf above/outside their TEXMF trees.
    mkdir "$CASE_DIR/config-tools" "$CASE_DIR/registered-config"
    printf 'Registered TeX configuration.\n' > "$CASE_DIR/registered-config/texmf.cnf"
    export DEPENDENCY_REAL_KPSE="$(command -v kpsewhich)"
    cat > "$CASE_DIR/config-tools/kpsewhich" <<'SH'
#!/usr/bin/env bash
if [ "$#" = 2 ] && [ "$1" = -all ] && [ "$2" = texmf.cnf ]; then
    "$DEPENDENCY_REAL_KPSE" "$@"
    printf '%s\n' "$DEPENDENCY_EXTRA_CONFIG"
else
    exec "$DEPENDENCY_REAL_KPSE" "$@"
fi
SH
    chmod +x "$CASE_DIR/config-tools/kpsewhich"
    cp original/build/paper.deps "$CASE_DIR/real-dependencies"
    printf '    %s\n' "$CASE_DIR/registered-config/texmf.cnf" >> original/build/paper.deps
    ok env PATH="$CASE_DIR/config-tools:$PATH" "DEPENDENCY_EXTRA_CONFIG=$CASE_DIR/registered-config/texmf.cnf" \
        bash -c 'source "$1/common.sh"; source "$1/dependencies.sh"; copy_manuscript_dependencies "$2" "$3"' \
        -- "$author/support" "$author/original" "$CASE_DIR/config-dependency-copy"
    assert_file "$CASE_DIR/config-dependency-copy/paper.tex"
    assert_absent "$CASE_DIR/config-dependency-copy/texmf.cnf"
    cp "$CASE_DIR/real-dependencies" original/build/paper.deps
    # Refresh the graph when an included file starts using a new source.
    sed '/input{sections\/nested\/child.tex}/d' revised1/sections/main.tex > revised1/sections/main.tex.tmp
    mv revised1/sections/main.tex.tmp revised1/sections/main.tex
    printf 'New input retained.\n' > revised1/sections/added.tex
    printf '\n\\input{sections/added.tex}\n' >> revised1/sections/main.tex
    cp revised1/sections/main.tex "$CASE_DIR/valid-main.tex"
    # Failed builds and rejected dependencies must never publish a partial pair.
    printf '\n\\MissingCommandForTest\n' >> revised1/sections/main.tex
    bad make new-round
    assert_absent revised2; assert_absent reply2
    cp "$CASE_DIR/valid-main.tex" revised1/sections/main.tex
    printf '\n\\input{missing-source.tex}\n' >> revised1/sections/main.tex
    bad make new-round
    assert_absent revised2; assert_absent reply2
    cp "$CASE_DIR/valid-main.tex" revised1/sections/main.tex
    printf 'Outside the manuscript stage.\n' > shared.tex
    printf '\n\\input{../shared.tex}\n' >> revised1/sections/main.tex
    bad make new-round
    assert_has "$CASE_DIR/command.log" 'stage-local'
    assert_absent revised2; assert_absent reply2
    cp "$CASE_DIR/valid-main.tex" revised1/sections/main.tex
    printf 'Outside the project too.\n' > "$CASE_DIR/external.tex"
    printf '\n\\input{%s}\n' "$CASE_DIR/external.tex" >> revised1/sections/main.tex
    bad make new-round
    assert_has "$CASE_DIR/command.log" 'outside the manuscript stage'
    cp "$CASE_DIR/valid-main.tex" revised1/sections/main.tex
    printf 'A local source.\n' > revised1/sections/real.tex
    ln -s sections/real.tex revised1/alias.tex
    printf '\n\\input{alias.tex}\n' >> revised1/sections/main.tex
    bad make new-round
    assert_has "$CASE_DIR/command.log" 'Source symlinks'
    cp "$CASE_DIR/valid-main.tex" revised1/sections/main.tex
    ln -s sections revised1/linked
    printf '\n\\input{linked/real.tex}\n' >> revised1/sections/main.tex
    bad make new-round
    assert_has "$CASE_DIR/command.log" 'Source symlinks'
    cp "$CASE_DIR/valid-main.tex" revised1/sections/main.tex
    ok make new-round
    assert_file revised2/sections/added.tex
    assert_absent revised2/sections/nested/child.tex
    assert_absent revised2/sections/real.tex
    assert_absent revised2/alias.tex; assert_absent revised2/linked
    ok make -C revised2
    # A complete database is retained even when only future replies will cite it.
    empty_author=$CASE_DIR/'citation-free publication'
    ok make init-project "DEST=$empty_author"
    cd "$empty_author"
    printf '\\documentclass{article}\n\\begin{document}No citations.\\end{document}\n' > original/paper.tex
    ok make new-round
    cmp -s original/paper.bib revised1/paper.bib || fail 'Citation-free round lost the shared bibliography'
    assert_not original/build/paper.deps 'paper.bib'
    rm revised1/paper.bib
    ok make new-round
    assert_absent revised2/paper.bib
}
test_ignore_rules() {
    command -v git >/dev/null 2>&1 || return 0
    ok git init -q
    for file in original/paper.aux original/paper.bcf original/paper.ind original/paper.gls original/paper.nav original/paper.synctex.gz original/paper.synctex.gz\(busy\) original/.notes.tex.swp original/.DS_Store original/Thumbs.db original/paper.bak original/paper.pdf .removed-rounds/round2-example/revised2/paper.pdf .removed-rounds/round2-example/reply2/reviewer1.pdf; do
        ok git -c core.excludesFile=/dev/null check-ignore -q "$file"
    done
    for extension in tex bib bst sty cls pdf eps svg png jpg tikz ist xdy mp mf gnuplot table; do
        bad git -c core.excludesFile=/dev/null check-ignore -q "original/figures/source.$extension"
        bad git -c core.excludesFile=/dev/null check-ignore -q ".removed-rounds/round2-example/revised2/figures/source.$extension"
    done
    bad git -c core.excludesFile=/dev/null check-ignore -q reply1/.reviewer-scaffolds/reviewer1.tex
    bad git -c core.excludesFile=/dev/null check-ignore -q .vscode/tasks.json
}
capture_archive() {
    ARCHIVE_ID=$(sed -n 's/.*ARCHIVE=//p' "$CASE_DIR/command.log")
    [ -n "$ARCHIVE_ID" ] && [ -d ".removed-rounds/$ARCHIVE_ID" ] || fail 'Removal did not report its archive'
}
test_round_lifecycle() {
    fresh_author
    bad make remove-round
    bad make restore-round
    bad make remove-round ROUND=0
    bad make restore-round ROUND=-1
    bad make restore-round ROUND=1
    ok make new-round; ok make new-round
    (cd reply2 && bad bash ../support/rounds.sh remove-round --round 2) || fail 'Round removal accepted a stage working directory'
    assert_has "$CASE_DIR/command.log" 'publication project root'
    mkdir -p revised2/sections revised2/figures
    printf '\\section{Unused author notes}\n' > revised2/sections/notes.tex
    printf 'Source PDF figure\n' > revised2/figures/plot.pdf
    printf '\n%% Edited manuscript retained during removal.\n' >> revised2/paper.tex
    printf '\n%% Edited bibliography retained during removal.\n' >> revised2/paper.bib
    printf '\n\\response{An edited answer must survive archiving.}\n' >> reply2/reviewer1-comments.tex
    ok make -C revised2 paper
    ok make -C reply2 responses
    cp -R revised2 "$CASE_DIR/before-revised2"
    cp -R reply2 "$CASE_DIR/before-reply2"
    bad make remove-round ROUND=1
    assert_has "$CASE_DIR/command.log" 'latest active round'
    set_cfg revised1/Makefile BASELINE ../revised2
    bad make remove-round ROUND=2
    assert_has "$CASE_DIR/command.log" 'depends on round 2'
    set_cfg revised1/Makefile BASELINE ../original
    ok make remove-round ROUND=2; capture_archive; first=$ARCHIVE_ID
    assert_absent revised2; assert_absent reply2
    diff -r "$CASE_DIR/before-revised2" ".removed-rounds/$first/revised2" || fail 'Archive changed manuscript contents'
    diff -r "$CASE_DIR/before-reply2" ".removed-rounds/$first/reply2" || fail 'Archive changed response contents'
    assert_absent ".removed-rounds/$first/revised2/.template-lock"
    assert_absent ".removed-rounds/$first/reply2/.template-lock"
    ok make clean; ok make distclean
    diff -r "$CASE_DIR/before-revised2" ".removed-rounds/$first/revised2" || fail 'Cleanup changed archived manuscript'
    diff -r "$CASE_DIR/before-reply2" ".removed-rounds/$first/reply2" || fail 'Cleanup changed archived responses'
    if command -v git >/dev/null 2>&1; then
        ok git init -q
        ok git -c core.excludesFile=/dev/null check-ignore -q ".removed-rounds/$first/revised2/paper.pdf"
        ok git -c core.excludesFile=/dev/null check-ignore -q ".removed-rounds/$first/reply2/responses.pdf"
        bad git -c core.excludesFile=/dev/null check-ignore -q ".removed-rounds/$first/revised2/paper.tex"
        bad git -c core.excludesFile=/dev/null check-ignore -q ".removed-rounds/$first/revised2/figures/plot.pdf"
        bad git -c core.excludesFile=/dev/null check-ignore -q ".removed-rounds/$first/reply2/.reviewer-scaffolds/reviewer1.tex"
    fi
    bad make restore-round ROUND=3
    bad make restore-round ROUND=2 ARCHIVE=../outside
    bad make restore-round ROUND=2 ARCHIVE=/tmp/outside
    bad make restore-round ROUND=2 ARCHIVE=round1-wrong
    bad make restore-round ROUND=2 ARCHIVE=round2-missing
    set_cfg ".removed-rounds/$first/revised2/Makefile" BASELINE ../missing
    bad make restore-round ROUND=2
    assert_has "$CASE_DIR/command.log" 'Missing baseline manuscript'
    set_cfg ".removed-rounds/$first/revised2/Makefile" BASELINE ../revised1
    set_cfg ".removed-rounds/$first/reply2/Makefile" REVISION ../revised1
    bad make restore-round ROUND=2
    set_cfg ".removed-rounds/$first/reply2/Makefile" REVISION ../revised2
    mv ".removed-rounds/$first/reply2/editor.tex" "$CASE_DIR/editor.tex"
    bad make restore-round ROUND=2
    mv "$CASE_DIR/editor.tex" ".removed-rounds/$first/reply2/editor.tex"
    ln -s "$author/.removed-rounds/$first" .removed-rounds/round2-linked
    bad make restore-round ROUND=2 ARCHIVE=round2-linked
    rm .removed-rounds/round2-linked
    mv ".removed-rounds/$first/revised2" "$CASE_DIR/stored-revised2"
    ln -s "$CASE_DIR/stored-revised2" ".removed-rounds/$first/revised2"
    bad make restore-round ROUND=2
    rm ".removed-rounds/$first/revised2"
    mv "$CASE_DIR/stored-revised2" ".removed-rounds/$first/revised2"
    mv .removed-rounds "$CASE_DIR/stored-archives"
    ln -s "$CASE_DIR/stored-archives" .removed-rounds
    bad make restore-round ROUND=2
    rm .removed-rounds; mv "$CASE_DIR/stored-archives" .removed-rounds
    ok make restore-round ROUND=2
    assert_absent ".removed-rounds/$first"
    diff -r "$CASE_DIR/before-revised2" revised2 || fail 'Restore changed manuscript contents'
    diff -r "$CASE_DIR/before-reply2" reply2 || fail 'Restore changed response contents'
    bad make restore-round ROUND=2
    ok make remove-round ROUND=2; capture_archive; edited=$ARCHIVE_ID
    ok make new-round
    assert_absent revised2/sections/notes.tex
    assert_not reply2/reviewer1-comments.tex 'An edited answer'
    assert_file ".removed-rounds/$edited/revised2/sections/notes.tex"
    ok make remove-round ROUND=2; capture_archive; replacement=$ARCHIVE_ID
    [ "$edited" != "$replacement" ] || fail 'Removal overwrote an existing attempt'
    bad make restore-round ROUND=2
    assert_has "$CASE_DIR/command.log" 'Several archives match'
    assert_has "$CASE_DIR/command.log" "$edited"
    assert_has "$CASE_DIR/command.log" "$replacement"
    printf 'Extra recovery information\n' > ".removed-rounds/$edited/extra.txt"
    ok make restore-round ROUND=2 "ARCHIVE=$edited"
    assert_file ".removed-rounds/$edited/extra.txt"
    assert_absent ".removed-rounds/$edited/revised2"
    diff -r "$CASE_DIR/before-revised2" revised2 || fail 'Explicit archive choice restored the wrong manuscript'
    diff -r "$CASE_DIR/before-reply2" reply2 || fail 'Explicit archive choice restored the wrong responses'
    ok make new-round
    ok make remove-round ROUND=3; capture_archive; third=$ARCHIVE_ID
    ok make remove-round ROUND=2; capture_archive; second=$ARCHIVE_ID
    bad make restore-round ROUND=3 "ARCHIVE=$third"
    assert_has "$CASE_DIR/command.log" 'Restore the next round (2)'
    ok make restore-round ROUND=2 "ARCHIVE=$second"
    ok make restore-round ROUND=3 "ARCHIVE=$third"
    # An occupied half-pair also refuses restoration without touching either side.
    ok make remove-round ROUND=3; capture_archive; third=$ARCHIVE_ID
    mkdir revised3; printf 'Do not overwrite\n' > revised3/keep.txt
    bad make restore-round ROUND=3 "ARCHIVE=$third"
    assert_file revised3/keep.txt
    rm revised3/keep.txt; rmdir revised3
    ok make restore-round ROUND=3 "ARCHIVE=$third"
    # Force the second move to fail, including failures while restoring.
    mkdir "$CASE_DIR/move-tools"
    export ROUND_REAL_MV="$(command -v mv)"
    cat > "$CASE_DIR/move-tools/mv" <<'SH'
#!/usr/bin/env bash
if [ "$#" = 3 ] && [ "$1" = -- ]; then
    if [ "$2" = "$ROUND_FAIL_SOURCE" ]; then
        [ "${ROUND_FAIL_SIGNAL:-}" != term ] || kill -TERM "$PPID"
        exit 97
    fi
    if [ "${ROUND_FAIL_ROLLBACK:-}" = 1 ]; then
        case "$2" in */.removed-rounds/round3-*/revised3) exit 98;; esac
    fi
fi
exec "$ROUND_REAL_MV" "$@"
SH
    chmod +x "$CASE_DIR/move-tools/mv"
    cp -R revised3 "$CASE_DIR/before-revised3"
    cp -R reply3 "$CASE_DIR/before-reply3"
    bad env PATH="$CASE_DIR/move-tools:$PATH" "ROUND_FAIL_SOURCE=$author/reply3" make remove-round ROUND=3
    diff -r "$CASE_DIR/before-revised3" revised3 || fail 'Removal failure did not roll back manuscript'
    diff -r "$CASE_DIR/before-reply3" reply3 || fail 'Removal failure did not preserve responses'
    bad env PATH="$CASE_DIR/move-tools:$PATH" "ROUND_FAIL_SOURCE=$author/reply3" ROUND_FAIL_SIGNAL=term make remove-round ROUND=3
    diff -r "$CASE_DIR/before-revised3" revised3 || fail 'Signal did not roll back manuscript'
    ok make remove-round ROUND=3; capture_archive; third=$ARCHIVE_ID
    bad env PATH="$CASE_DIR/move-tools:$PATH" "ROUND_FAIL_SOURCE=$author/.removed-rounds/$third/reply3" make restore-round ROUND=3 "ARCHIVE=$third"
    assert_absent revised3; assert_absent reply3
    diff -r "$CASE_DIR/before-revised3" ".removed-rounds/$third/revised3" || fail 'Restoration failure changed archive'
    diff -r "$CASE_DIR/before-reply3" ".removed-rounds/$third/reply3" || fail 'Restoration failure changed replies'
    ok make restore-round ROUND=3 "ARCHIVE=$third"
    bad env PATH="$CASE_DIR/move-tools:$PATH" "ROUND_FAIL_SOURCE=$author/reply3" ROUND_FAIL_ROLLBACK=1 make remove-round ROUND=3
    assert_has "$CASE_DIR/command.log" 'Rollback failed; recovery data remains'
    recovery=$(sed -n 's/^Rollback failed; recovery data remains at \(.*\)\. Do not overwrite it\.$/\1/p' "$CASE_DIR/command.log")
    [ -n "$recovery" ] || fail 'Rollback failure did not identify recovery data'
    diff -r "$CASE_DIR/before-revised3" "$recovery" || fail 'Failed rollback lost manuscript data'
    diff -r "$CASE_DIR/before-reply3" reply3 || fail 'Failed rollback lost reply data'
    mv "$recovery" revised3; rmdir "$(dirname -- "$recovery")"
    # A concurrent stage lock must finish before the round can move.
    lock "$author/reply3"
    bash support/rounds.sh remove-round --round 3 > "$CASE_DIR/locked-removal.log" 2>&1 &
    removal_pid=$!
    for attempt in 1 2 3 4 5; do
        [ "$(cat revised3/.template-lock/owner 2>/dev/null || :)" != "$removal_pid" ] || break
        sleep 1
    done
    [ "$(cat revised3/.template-lock/owner 2>/dev/null || :)" = "$removal_pid" ] || fail 'Concurrent removal did not acquire the manuscript lock'
    assert_file revised3/paper.tex; assert_file reply3/responses.tex
    unlock "$author/reply3"
    wait "$removal_pid" || fail 'Removal failed after releasing the stage lock'
    assert_absent revised3; assert_absent reply3
    ok make restore-round ROUND=3
    assert_absent .template-lock; assert_absent revised3/.template-lock; assert_absent reply3/.template-lock
    ok make -j4
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
      /^EDITOR \(/ || /^REVIEWER [1-9][0-9]* \(/ {active=(index($0,role " (")==1); next}
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
        if [ "$round" = 1 ]; then ids=(1 2 3); else ids=(1 3 4); fi
        for id in "${ids[@]}"; do
            check_email "$project/support/walkthrough/emails/round$round.txt" "REVIEWER $id" "$project/support/walkthrough/reply$round/reviewer$id-comments.tex"
        done
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
    for stage in original revised1; do
        for source in paper.tex paper.bib; do
            cmp -s "$guide/$stage/$source" "$guide/support/walkthrough/$stage/$source" || fail 'Earlier manuscript changed'
        done
    done
    for round in 1 2; do
        stage=reply$round
        if [ "$round" = 1 ]; then ids=(1 2 3); else ids=(1 3 4); fi
        assert_has "$guide/$stage/Makefile" "REVIEWERS := ${ids[*]}"
        for document in metadata.tex editor-comments.tex; do
            cmp -s "$guide/$stage/$document" "$guide/support/walkthrough/$stage/$document" || fail 'Earlier response sources changed'
        done
        for letter in responses editor; do assert_file "$guide/$stage/$letter.pdf"; done
        for id in "${ids[@]}"; do
            assert_file "$guide/$stage/reviewer$id.tex"
            assert_file "$guide/$stage/reviewer$id.pdf"
            assert_file "$guide/$stage/reviewer$id-with-diff.pdf"
            cmp -s "$guide/$stage/reviewer$id-comments.tex" "$guide/support/walkthrough/$stage/reviewer$id-comments.tex" || fail 'Reviewer responses changed'
        done
    done
    for suffix in .tex -comments.tex .pdf -with-diff.pdf; do
        assert_absent "$guide/reply2/reviewer2$suffix"
        assert_absent "$guide/reply1/reviewer4$suffix"
    done
    ok make -C "$guide" info-reviewer
    awk '$1=="reply1" && $3==3 && $4==1 && $5==2 && $6==3 && $7=="yes" {first=1}
         $1=="reply2" && $3==3 && $4==1 && $5==3 && $6==4 && $7=="yes" {second=1}
         END {exit !(first && second)}' "$CASE_DIR/command.log" || fail 'Unexpected walkthrough reviewer information'
}
CASES=(test_help_tools test_template_protection test_manuscript_dependencies test_ignore_rules test_round_lifecycle test_build_incremental_archives test_bibliography test_management_and_guards test_editor_only_and_rounds test_covers_metadata_cleanup test_init_failures test_ghostscript_fallback test_readme_walkthrough)
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

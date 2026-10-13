#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
source "$TEMPLATE_SUPPORT/dependencies.sh" || exit 1
setup_traps
stage=$(pwd -P)
command=${1:-}; [ "$#" -gt 0 ] && shift
baseline= revision= cover=0 internal=0 need_diff=0 need_merge=0
destination=
letters=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --baseline|--revision|--cover|--dest) option=$1; [ "$#" -ge 2 ] || fail "Missing value for $1"; value=$2; shift 2
            case "$option" in --baseline) baseline=$value;; --revision) revision=$value;; --cover) cover=$value;; --dest) destination=$value;; esac;;
        --diff) need_diff=1; shift;; --merge) need_diff=1; need_merge=1; shift;;
        --letters) shift; while [ "$#" -gt 0 ]; do letters+=("$1"); shift; done;;
        *) fail "Unknown option: $1";;
    esac
 done
[[ "$cover" = 0 || "$cover" = 1 ]] || fail 'COVER must be 0 or 1'
compile() {
    local directory=$1 name=$2 bib=${3:-1} inside=${4:-0} source out=. log
    source=$name.tex
    local options=()
    [ -f "$directory/$source" ] || source=build/$name.tex
    [ -f "$directory/$source" ] || fail "Missing document source: $directory/$name.tex"
    require latexmk pdflatex
    if [ "$bib" = 0 ]; then options+=('-bibtex-'); else require bibtex; fi
    [ "$inside" = 0 ] || out=build
    [ ! -L "$directory/build" ] || fail "Build directory symlinks are not supported: $directory/build"
    mkdir -p -- "$directory/build"
    if [ "$name" = paper ]; then
        options+=('-deps' '-deps-escape=none' '-deps-out=build/paper.deps.tmp')
    fi
    (cd -- "$directory" && latexmk -norc -r "$TEMPLATE_SUPPORT/latexmkrc" -pdf -interaction=nonstopmode -halt-on-error -file-line-error -recorder -auxdir=build "-outdir=$out" -emulate-aux-dir "${options[@]}" "$source")
    log=$directory/build/$name.log
    if grep -Eq 'LaTeX Warning: Citation .*undefined|There were undefined (references|citations)' "$log"; then fail "Unresolved citations/references in $log"; fi
    if [ -f "$directory/build/$name.blg" ] && [ "$bib" != 0 ] && grep -q 'Warning--I didn.t find a database entry' "$directory/build/$name.blg"; then
        # Ignore an old .blg only when the current document has no bibliography.
        if grep -q '\\bibdata{' "$directory/build/$name.aux"; then fail "Missing bibliography entry; see $directory/build/$name.blg"; fi
    fi
    if [ "$name" = paper ]; then
        [ -f "$directory/build/paper.deps.tmp" ] || fail 'latexmk did not export manuscript dependencies'
        update_file "$directory/build/paper.deps.tmp" "$directory/build/paper.deps"
    fi
}
expand_paper() {
    local directory=$1
    if [ -f "$directory/build/paper.bbl" ] && grep -q '\\bibdata{' "$directory/build/paper.aux"; then
        (cd -- "$directory" && latexpand --expand-bbl build/paper.bbl paper.tex) > "$directory/build/paper-expanded.tex.tmp"
    else
        (cd -- "$directory" && latexpand paper.tex) > "$directory/build/paper-expanded.tex.tmp"
    fi
    update_file "$directory/build/paper-expanded.tex.tmp" "$directory/build/paper-expanded.tex"
}
build_diff() {
    local directory=$1 previous_value=$2 previous
    require latexpand latexdiff
    [ -n "$previous_value" ] || previous_value=$(cfg "$directory/Makefile" BASELINE)
    [ -n "$previous_value" ] || fail "Set BASELINE in $directory/Makefile"
    previous=$(canonical "$directory/$previous_value")
    [ -f "$previous/paper.tex" ] || fail "Baseline manuscript not found: $previous"
    [ "$previous" != "$directory" ] || fail 'A revision cannot be its own baseline'
    lock "$previous"; compile "$previous" paper; expand_paper "$previous"
    make_temp
    cp -- "$previous/build/paper-expanded.tex" "$TASK_TEMP/baseline.tex"
    unlock "$previous"
    lock "$directory"; compile "$directory" paper; expand_paper "$directory"
    cp -- "$TASK_TEMP/baseline.tex" "$directory/build/baseline-expanded.tex"
    # Strip volatile latexdiff file timestamps; compare content to retain no-op builds.
    latexdiff --encoding=utf8 --type=UNDERLINE --exclude-textcmd=hskip,vskip,smallskip,medskip,bigskip "$directory/build/baseline-expanded.tex" "$directory/build/paper-expanded.tex" |
        sed '/^%DIF DEL /d; /^%DIF ADD /d' > "$directory/build/paper-diff.tex.tmp"
    update_file "$directory/build/paper-diff.tex.tmp" "$directory/build/paper-diff.tex"
    compile "$directory" paper-diff 0
    unlock "$directory"
}
choose_letters() {
    local id name
    validate_reply "$stage"
    if [ "${#letters[@]}" = 0 ]; then
        letters=(responses editor)
        for id in "${REVIEWER_IDS[@]}"; do letters+=("reviewer$id"); done
    fi
    for name in "${letters[@]}"; do
        case "$name" in responses|editor) ;; reviewer*)
            id=${name#reviewer}; positive "$id"
            case " ${REVIEWER_IDS[*]} " in *" $id "*) ;; *) fail "Reviewer $id is not configured";; esac;;
            *) fail "Unknown letter: $name";; esac
    done
}
archive() {
    local name staging
    require zip
    lock "$stage"; compile "$stage" paper
    make_temp "$stage/build"; staging=$TASK_TEMP/sources
    copy_manuscript_dependencies "$stage" "$staging"
    mkdir -p -- "$staging/support"
    for name in common.sh dependencies.sh build.sh manuscript.mk latexmkrc; do
        [ ! -e "$staging/support/$name" ] || fail "Manuscript dependency conflicts with archive build helper: support/$name"
        cp -- "$TEMPLATE_SUPPORT/$name" "$staging/support/$name"
    done
    for name in LICENSE Makefile README.md; do
        [ ! -e "$staging/$name" ] || fail "Manuscript dependency conflicts with archive metadata: $name"
    done
    cp -- "$TEMPLATE_ROOT/LICENSE" "$staging/LICENSE"
    printf 'TYPE := manuscript\ninclude support/manuscript.mk\n' > "$staging/Makefile"
    printf '%s\n' 'Standalone manuscript sources.' 'Install GNU Make, Bash, and TeX Live (IEEEtran and latexmk).' 'Run make; paper.pdf appears beside paper.tex.' > "$staging/README.md"
    (cd -- "$staging" && zip -qr "$TASK_TEMP/paper.zip" .)
    mv -- "$TASK_TEMP/paper.zip" "$stage/build/paper.zip"
    printf 'Created %s\n' "$stage/build/paper.zip"
}
clean_outputs() {
    local everything=$1 file name
    [ ! -L "$stage/build" ] || fail 'Refusing to clean a symlinked build directory'
    lock "$stage"
    if [ -d "$stage/build" ]; then
        while IFS= read -r -d '' file; do
            if [ "$everything" = 0 ] && [[ "$file" = *.zip ]]; then continue; fi
            rm -rf -- "$file"
        done < <(find "$stage/build" -mindepth 1 -maxdepth 1 -print0)
    fi
    for file in "$stage"/*.pdf; do
        [ -f "$file" ] || continue
        name=${file#"$stage"/}
        if generated_pdf "$stage" "$name"; then
            [ "$everything" = 0 ] || rm -f -- "$file"
            rm -f -- "${file%.pdf}.synctex" "${file%.pdf}.synctex.gz"
        fi
    done
    if [ "$everything" = 1 ] && [ -d "$stage/build" ]; then rmdir -- "$stage/build"; fi
}
case "$command" in
    check-tools)
        require bash make cmp awk sed find mktemp zip latexmk pdflatex bibtex kpsewhich
        [ "$need_diff" = 0 ] || require latexpand latexdiff
        for name in IEEEtran.cls IEEEtran.bst; do [ -n "$(kpsewhich "$name")" ] || fail "Missing TeX package: $name"; done
        if [ "$need_merge" = 1 ]; then command -v pdfunite >/dev/null 2>&1 || command -v gs >/dev/null 2>&1 || fail 'Bundles require pdfunite or gs'; fi
        printf 'Required tools are available.\n';;
    paper) lock "$stage"; compile "$stage" paper;;
    snapshot)
        [ -n "$destination" ] || fail 'Set a snapshot destination'
        [ ! -e "$destination" ] && [ ! -L "$destination" ] || fail 'Snapshot destination already exists'
        [ -f "$stage/paper.tex" ] || fail 'Missing manuscript paper.tex'
        lock "$stage"; compile "$stage" paper
        copy_manuscript_dependencies "$stage" "$destination";;
    diff) build_diff "$stage" "$baseline";;
    reply) choose_letters; lock "$stage"; reply_inputs "$stage" "$revision"; for name in "${letters[@]}"; do compile "$stage" "$name"; done;;
    bundle)
        choose_letters
        [ -n "$revision" ] || revision=$(cfg "$stage/Makefile" REVISION)
        [ -n "$revision" ] || fail 'Set REVISION in the reply Makefile'
        revision_directory=$(canonical "$stage/$revision")
        build_diff "$revision_directory" ''
        lock "$stage"; reply_inputs "$stage" "$revision"
        prefix=()
        if [ "$cover" = 1 ]; then
            cp -- "$TEMPLATE_SUPPORT/rebuttal-cover.tex" "$stage/build/rebuttal-cover.tex.tmp"
            update_file "$stage/build/rebuttal-cover.tex.tmp" "$stage/build/rebuttal-cover.tex"
            compile "$stage" rebuttal-cover 0 1
            prefix+=("$stage/build/rebuttal-cover.pdf")
        fi
        for name in "${letters[@]}"; do
            compile "$stage" "$name"
            temporary=$stage/build/$name-with-diff.tmp.pdf
            if command -v pdfunite >/dev/null 2>&1; then
                pdfunite "${prefix[@]}" "$stage/$name.pdf" "$revision_directory/paper-diff.pdf" "$temporary"
            else
                require gs
                gs -q -dBATCH -dNOPAUSE -dSAFER -sDEVICE=pdfwrite "-sOutputFile=$temporary" "${prefix[@]}" "$stage/$name.pdf" "$revision_directory/paper-diff.pdf"
            fi
            mv -- "$temporary" "$stage/$name-with-diff.pdf"
        done;;
    zip) archive;; clean) clean_outputs 0;; distclean) clean_outputs 1;;
    *) fail "Unknown build command: $command";;
esac

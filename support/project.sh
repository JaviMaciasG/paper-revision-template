#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
setup_traps
command=${1:-}; [ "$#" -gt 0 ] && shift
destination=
while [ "$#" -gt 0 ]; do
    case "$1" in --dest) [ "$#" -ge 2 ] || fail 'Missing DEST'; destination=$2; shift 2;; *) fail "Unknown option: $1";; esac
 done
case "$command" in
    init-project)
        [ -n "$destination" ] || fail 'Set DEST, for example make init-project DEST=../my-paper'
        case "$destination" in '~/'*) destination=${HOME:-}/${destination#\~/};; esac
        [ ! -e "$destination" ] && [ ! -L "$destination" ] || fail "Refusing to overwrite existing destination: $destination"
        destination=$(canonical "$destination")
        case "$destination/" in "$TEMPLATE_ROOT/"*) fail 'Choose a destination outside the template repository';; esac
        mkdir -p -- "$(dirname -- "$destination")"
        make_temp "$(dirname -- "$destination")"; project=$TASK_TEMP/project; mkdir -- "$project"
        for name in Makefile README.md HOWTO.md LICENSE .gitignore; do cp -p -- "$TEMPLATE_ROOT/$name" "$project/$name"; done
        set_cfg "$project/Makefile" PROJECT_ROLE publication
        for name in support tests; do copy_sources "$TEMPLATE_ROOT/$name" "$project/$name"; done
        copy_sources "$TEMPLATE_SUPPORT/starter" "$project/original"
        awk '
          /^# (IEEE|Generic) manuscript and rebuttal template$/ {print "# Manuscript project"; next}
          /^A reusable paper project/ {
            print "This initialized author project starts with a minimal IEEE manuscript in original/. Replace original/paper.tex and original/paper.bib with your real manuscript and bibliography. There are no active revisions yet; make new-round creates round one. The guided HOWTO.md, example assets, and independent test fixtures are included for reference."; next}
          {print}' "$project/README.md" > "$project/README.md.tmp"
        mv -- "$project/README.md.tmp" "$project/README.md"
        [ ! -e "$destination" ] && [ ! -L "$destination" ] || fail "Refusing to overwrite existing destination: $destination"
        mv -- "$project" "$destination"
        printf 'Created %s\nReplace original/paper.tex and original/paper.bib with your real manuscript and bibliography.\n' "$destination";;
    new-round)
        require_publication "$command"
        lock "$TEMPLATE_ROOT"
        latest=0
        for directory in "$TEMPLATE_ROOT"/revised*; do
            [ -d "$directory" ] || continue
            name=${directory##*/}
            if [[ "$name" =~ ^revised([1-9][0-9]*)$ ]]; then
                id=${BASH_REMATCH[1]}; [ "$id" -le "$latest" ] || latest=$id
            fi
        done
        if [ "$latest" = 0 ]; then previous=$TEMPLATE_ROOT/original; previous_reply=$TEMPLATE_SUPPORT/reply-skeleton
        else previous=$TEMPLATE_ROOT/revised$latest; previous_reply=$TEMPLATE_ROOT/reply$latest; fi
        [ -f "$previous/paper.tex" ] || fail "Latest manuscript is missing: $previous"
        [ ! -L "$previous" ] || fail "Source stage symlinks are not supported: $previous"
        [ -d "$previous_reply" ] || fail "Missing reply stage: $previous_reply"
        for directory in "$TEMPLATE_ROOT"/reply*; do
            [ -d "$directory" ] || continue; name=${directory##*/}
            if [[ "$name" =~ ^reply([1-9][0-9]*)$ ]]; then
                [ -d "$TEMPLATE_ROOT/revised${BASH_REMATCH[1]}" ] || fail "Unpaired reply stage: $name"
            fi
        done
        next=$((latest + 1)); revision=$TEMPLATE_ROOT/revised$next; reply=$TEMPLATE_ROOT/reply$next
        [ ! -e "$revision" ] && [ ! -e "$reply" ] || fail "Refusing to overwrite revised$next or reply$next"
        validate_reply "$previous_reply"
        ids=("${REVIEWER_IDS[@]}")
        cover=$(cfg "$previous_reply/Makefile" COVER 0)
        [[ "$cover" = 0 || "$cover" = 1 ]] || fail 'COVER must be 0 or 1'
        make_temp "$TEMPLATE_ROOT"; new_revision=$TASK_TEMP/revised$next; new_reply=$TASK_TEMP/reply$next
        (cd -- "$previous" && bash "$TEMPLATE_SUPPORT/build.sh" snapshot --dest "$new_revision")
        lock "$previous_reply"; copy_sources "$previous_reply" "$new_reply"
        printf 'TYPE := revision\nBASELINE := ../%s\ninclude ../support/manuscript.mk\n' "${previous##*/}" > "$new_revision/Makefile"
        printf 'REVISION := ../revised%s\nREVIEWERS := %s\nCOVER := %s\ninclude ../support/reply.mk\n' "$next" "${ids[*]}" "$cover" > "$new_reply/Makefile"
        # Discard inactive reviewers from the new stage only; preserve older rounds.
        for file in "$new_reply"/reviewer*.tex; do
            [ -f "$file" ] || continue; name=${file##*/}
            if [[ "$name" =~ ^reviewer([1-9][0-9]*)(-comments)?\.tex$ ]]; then
                id=${BASH_REMATCH[1]}
                case " ${ids[*]} " in *" $id "*) ;; *) rm -f -- "$file" "$new_reply/.reviewer-scaffolds/reviewer$id.tex" "$new_reply/.reviewer-scaffolds/reviewer$id-comments.tex";; esac
            fi
        done
        for identity in editor $(printf 'reviewer%s ' "${ids[@]}"); do
            # printf with an empty array would produce 'reviewer'; skip it.
            [ "$identity" != reviewer ] || continue
            file=$new_reply/$identity-comments.tex
            style=$(sed -n -e 's/.*\\begin{enumerate}.*/enumerate/p' -e 's/.*\\begin{itemize}.*/itemize/p' "$file" | head -1)
            [ -n "$style" ] || style=enumerate
            scaffold "$identity" "$style" "$file"
        done
        mkdir -p -- "$new_reply/.reviewer-scaffolds"
        for id in "${ids[@]}"; do
            cp -p -- "$new_reply/reviewer$id-comments.tex" "$new_reply/.reviewer-scaffolds/reviewer$id-comments.tex"
            if [ -f "$previous_reply/.reviewer-scaffolds/reviewer$id.tex" ]; then
                cp -p -- "$previous_reply/.reviewer-scaffolds/reviewer$id.tex" "$new_reply/.reviewer-scaffolds/reviewer$id.tex"
            else
                reviewer_wrapper "$id" "$TASK_TEMP/wrapper.tex"
                if cmp -s -- "$new_reply/reviewer$id.tex" "$TASK_TEMP/wrapper.tex"; then
                    cp -p -- "$TASK_TEMP/wrapper.tex" "$new_reply/.reviewer-scaffolds/reviewer$id.tex"
                else
                    rm -f -- "$new_reply/.reviewer-scaffolds/reviewer$id.tex"
                fi
            fi
        done
        unlock "$previous_reply"
        mv -- "$new_revision" "$revision"
        if ! mv -- "$new_reply" "$reply"; then rm -rf -- "$revision"; fail 'Unable to publish reply stage; revision creation rolled back'; fi
        printf 'Created revised%s and reply%s; baseline is %s.\nUpdate metadata and fill the new response scaffolds.\n' "$next" "$next" "${previous##*/}";;
    *) fail "Unknown project command: $command";;
esac

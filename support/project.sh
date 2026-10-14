#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
source "$TEMPLATE_SUPPORT/managed.sh" || exit 1
setup_traps
command=${1:-}; [ "$#" -gt 0 ] && shift
destination= reviewers_given=0 reviewers_value=
while [ "$#" -gt 0 ]; do
    case "$1" in --dest) [ "$#" -ge 2 ] || fail 'Missing DEST'; destination=$2; shift 2;; --reviewers) [ "$#" -ge 2 ] || fail "Missing REVIEWERS"; reviewers_given=1; reviewers_value=$2; shift 2;; *) fail "Unknown option: $1";; esac
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
        publication_readme "$project/README.md"
        record_managed "$project"
        [ ! -e "$destination" ] && [ ! -L "$destination" ] || fail "Refusing to overwrite existing destination: $destination"
        mv -- "$project" "$destination"
        printf 'Created %s\nNext steps:\n  1. Replace original/paper.tex and original/paper.bib; keep dependencies inside original/.\n  2. Enter your project: cd %q\n  3. Build: make current\n  4. Prepare original submission: make submission\n  5. After receiving reviews: make new-round REVIEWERS="1 2"\nSee HOWTO.md for a complete example.\n' "$destination" "$destination";;
    new-round)
        require_publication "$command"
        # Validate explicit membership before locks, builds, or copies.
        explicit_ids=(); seen=' '
        if [ "$reviewers_given" = 1 ]; then
            [[ "$reviewers_value" =~ ^[[:space:]0-9]*$ ]] || fail "REVIEWERS must be a space-separated list of positive integers"
            for id in $reviewers_value; do
                positive "$id"
                case "$seen" in *" $id "*) fail "Duplicate reviewer $id";; esac
                seen="$seen$id "; explicit_ids+=("$id")
            done
        fi
        lock "$TEMPLATE_ROOT"
        active_rounds
        latest=$LATEST_ROUND
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
        [ "$reviewers_given" = 0 ] || ids=("${explicit_ids[@]}")
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
        for id in "${ids[@]}"; do
            if [ ! -f "$new_reply/reviewer$id.tex" ]; then
                reviewer_wrapper "$id" "$new_reply/reviewer$id.tex"
                mkdir -p -- "$new_reply/.reviewer-scaffolds"
                cp -p -- "$new_reply/reviewer$id.tex" "$new_reply/.reviewer-scaffolds/reviewer$id.tex"
            fi
        done
        for identity in editor $(printf 'reviewer%s ' "${ids[@]}"); do
            # printf with an empty array would produce 'reviewer'; skip it.
            [ "$identity" != reviewer ] || continue
            file=$new_reply/$identity-comments.tex
            style=$(sed -n -e 's/.*\\begin{enumerate}.*/enumerate/p' -e 's/.*\\begin{itemize}.*/itemize/p' "$file" 2>/dev/null | head -1 || :)
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
        printf 'Created revised%s and reply%s; baseline is %s.\nReviewers: %s (editor separate).\nResponse files to fill:\n  reply%s/editor-comments.tex\n' "$next" "$next" "${previous##*/}" "${ids[*]:-(none)}" "$next"
        for id in "${ids[@]}"; do printf '  reply%s/reviewer%s-comments.tex\n' "$next" "$id"; done
        printf 'Next steps:\n  1. Edit revised%s/paper.tex, included sources, and the bibliography if used.\n  2. Update reply%s/metadata.tex with the title, authors, and manuscript ID.\n  3. Fill the response files listed above.\n  4. Inspect: make status\n  5. Build: make current\n  6. Prepare submission: make submission\n' "$next" "$next";;
    *) fail "Unknown project command: $command";;
esac

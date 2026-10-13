#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
setup_traps
command=${1:-}; [ "$#" -gt 0 ] && shift
round= reviewer=
while [ "$#" -gt 0 ]; do
    case "$1" in --round|--reviewer)
        option=$1; [ "$#" -ge 2 ] || fail "Missing value for $1"; value=$2; shift 2
        case "$option" in --round) round=$value;; --reviewer) reviewer=$value;; esac;;
        *) fail "Unknown option: $1";; esac
 done
cwd=$(pwd -P); folder=${cwd##*/}
if [[ "$folder" =~ ^reply([1-9][0-9]*)$ ]] && [ "$(dirname -- "$cwd")" = "$TEMPLATE_ROOT" ]; then
    current=${BASH_REMATCH[1]}
    [ -z "$round" ] || [ "$round" = "$current" ] || fail "ROUND conflicts with current stage $folder"
    round=$current
elif [ "$cwd" != "$TEMPLATE_ROOT" ]; then
    fail 'Run this target from the project root or a replyX folder'
fi
info_row() {
    local stage=$1 id revision editor=yes problem=0
    load_reviewers "$stage"
    revision=$(cfg "$stage/Makefile" REVISION)
    [ -f "$stage/editor.tex" ] && [ -f "$stage/editor-comments.tex" ] || editor=no
    printf '%-10s %-20s %-8s %-18s %s\n' "${stage##*/}" "$revision" "${#REVIEWER_IDS[@]}" "${REVIEWER_IDS[*]:-(none)}" "$editor"
    [ "$editor" = yes ] || { printf '  Missing editor files in %s\n' "$stage" >&2; problem=1; }
    [ -n "$revision" ] && [ -f "$(canonical "$stage/$revision")/paper.tex" ] || { printf '  Missing associated manuscript for %s\n' "$stage" >&2; problem=1; }
    for id in "${REVIEWER_IDS[@]}"; do
        [ -f "$stage/reviewer$id.tex" ] && [ -f "$stage/reviewer$id-comments.tex" ] || { printf '  Missing reviewer %s files\n' "$id" >&2; problem=1; }
    done
    return "$problem"
}
if [ "$command" = info-reviewer ]; then
    printf '%-10s %-20s %-8s %-18s %s\n' ROUND MANUSCRIPT COUNT REVIEWERS EDITOR
    status=0; count=0
    if [ -n "$round" ]; then
        positive "$round"; stage=$TEMPLATE_ROOT/reply$round
        [ -f "$stage/Makefile" ] || fail "No reply stage for round $round"
        info_row "$stage" || status=1; count=1
    else
        while IFS= read -r number; do
            [ -n "$number" ] || continue
            info_row "$TEMPLATE_ROOT/reply$number" || status=1; count=$((count + 1))
        done < <(for stage in "$TEMPLATE_ROOT"/reply*; do
            [ -d "$stage" ] || continue; name=${stage##*/}; [[ "$name" =~ ^reply([1-9][0-9]*)$ ]] && printf '%s\n' "${BASH_REMATCH[1]}"
        done | sort -n)
    fi
    [ "$count" != 0 ] || printf 'No review rounds yet.\n'
    exit "$status"
fi
require_publication "$command"
[ -n "$round" ] || fail 'Root reviewer management requires ROUND=N'
positive "$round"; stage=$TEMPLATE_ROOT/reply$round
[ -d "$stage" ] || fail "No reply stage for round $round"
lock "$TEMPLATE_ROOT"; lock "$stage"
validate_reply "$stage"; ids=("${REVIEWER_IDS[@]}")
if [ "$command" = add-reviewer ] && [ -z "$reviewer" ]; then
    reviewer=0; for id in "${ids[@]}"; do [ "$id" -le "$reviewer" ] || reviewer=$id; done; reviewer=$((reviewer + 1))
fi
[ -n "$reviewer" ] || fail 'Removal requires REVIEWER=N'
positive "$reviewer"
case "$command" in
    add-reviewer)
        case " ${ids[*]} " in *" $reviewer "*) fail "Reviewer $reviewer already configured";; esac
        for suffix in .tex -comments.tex; do [ ! -e "$stage/reviewer$reviewer$suffix" ] && [ ! -L "$stage/reviewer$reviewer$suffix" ] || fail "Existing reviewer file: reviewer$reviewer$suffix"; done
        ids+=("$reviewer");;
    remove-reviewer)
        case " ${ids[*]} " in *" $reviewer "*) ;; *) fail "Reviewer $reviewer is not configured";; esac
        for suffix in .tex -comments.tex; do
            file=$stage/reviewer$reviewer$suffix; pristine=$stage/.reviewer-scaffolds/reviewer$reviewer$suffix
            [ -f "$pristine" ] && [ ! -L "$file" ] && cmp -s -- "$file" "$pristine" || fail "Refusing removal: edited, populated, or unrecognized file $file. Review it manually; no force option is provided."
        done
        remaining=(); for id in "${ids[@]}"; do [ "$id" = "$reviewer" ] || remaining+=("$id"); done; ids=("${remaining[@]}");;
    *) fail "Unknown reviewer command: $command";;
esac
make_temp "$stage"; transaction=$TASK_TEMP
cp -p -- "$stage/Makefile" "$transaction/Makefile"
for suffix in .tex -comments.tex; do
    [ ! -f "$stage/reviewer$reviewer$suffix" ] || cp -p -- "$stage/reviewer$reviewer$suffix" "$transaction/old$suffix"
    [ ! -f "$stage/.reviewer-scaffolds/reviewer$reviewer$suffix" ] || cp -p -- "$stage/.reviewer-scaffolds/reviewer$reviewer$suffix" "$transaction/base$suffix"
done
# Prepare everything before touching live files; rollback restores affected sources.
cp -p -- "$stage/Makefile" "$transaction/new-Makefile"
set_cfg "$transaction/new-Makefile" REVIEWERS "${ids[*]}"
if [ "$command" = add-reviewer ]; then
    reviewer_wrapper "$reviewer" "$transaction/new.tex"
    scaffold "reviewer$reviewer" enumerate "$transaction/new-comments.tex"
fi
rollback_reviewers() {
    local rc=$? suffix
    if [ "$rc" != 0 ]; then
        cp -p -- "$transaction/Makefile" "$stage/Makefile"
        for suffix in .tex -comments.tex; do
            if [ -f "$transaction/old$suffix" ]; then cp -p -- "$transaction/old$suffix" "$stage/reviewer$reviewer$suffix"; else rm -f -- "$stage/reviewer$reviewer$suffix"; fi
            if [ -f "$transaction/base$suffix" ]; then
                mkdir -p -- "$stage/.reviewer-scaffolds"; cp -p -- "$transaction/base$suffix" "$stage/.reviewer-scaffolds/reviewer$reviewer$suffix"
            else rm -f -- "$stage/.reviewer-scaffolds/reviewer$reviewer$suffix"; fi
        done
    fi
    cleanup
}
trap rollback_reviewers EXIT
if [ "$command" = add-reviewer ]; then
    cp -p -- "$transaction/new.tex" "$stage/reviewer$reviewer.tex"
    cp -p -- "$transaction/new-comments.tex" "$stage/reviewer$reviewer-comments.tex"
    record_baseline "$stage" "$reviewer"
else
    for suffix in .tex -comments.tex; do rm -- "$stage/reviewer$reviewer$suffix" "$stage/.reviewer-scaffolds/reviewer$reviewer$suffix"; done
fi
mv -- "$transaction/new-Makefile" "$stage/Makefile"
# Remove only reserved outputs; figure assets and other reviewer letters stay intact.
rm -f -- "$stage/responses.pdf" "$stage/responses-with-diff.pdf"
if [ "$command" = remove-reviewer ]; then
    rm -f -- "$stage/reviewer$reviewer.pdf" "$stage/reviewer$reviewer-with-diff.pdf" "$stage/reviewer$reviewer.synctex.gz"
    if [ -d "$stage/build" ]; then
        for file in "$stage/build/reviewer$reviewer."* "$stage/build/reviewer$reviewer-with-diff."*; do [ ! -f "$file" ] || rm -f -- "$file"; done
    fi
fi
printf '%s reviewer %s in reply%s; configured reviewers: %s\n' "$command" "$reviewer" "$round" "${ids[*]:-(none)}"

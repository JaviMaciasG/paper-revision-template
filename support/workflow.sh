#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
setup_traps
command=${1:-}; [ "$#" -gt 0 ] && shift
round= cover= cover_given=0
while [ "$#" -gt 0 ]; do
    option=$1; [ "$#" -ge 2 ] || fail "Missing value for $option"
    case "$option" in
        --round) round=$2;;
        --cover) cover=$2; cover_given=1; [[ "$cover" = 0 || "$cover" = 1 ]] || fail 'COVER must be 0 or 1';;
        *) fail "Unknown option: $option";;
    esac
    shift 2
done
[ "$(pwd -P)" = "$TEMPLATE_ROOT" ] || fail 'Run status, current, and submission from the project root'
case "$command" in status|current|submission) ;; *) fail "Unknown workflow command: $command";; esac
# Numeric stage selection shared by all shortcuts; never choose an orphaned pair.
active_rounds
if [ "$command" = status ]; then
    role=$(cfg "$TEMPLATE_ROOT/Makefile" PROJECT_ROLE)
    case "$role" in template|publication) ;; *) fail 'Invalid PROJECT_ROLE in root Makefile';; esac
    printf 'Project role: %s\nLatest round: %s\n' "$role" "$LATEST_ROUND"
    printf 'Output presence below does not establish freshness or submission readiness.\n'
    printf '\nLocal Git information (no fetch performed):\n'
    if ! command -v git >/dev/null 2>&1; then printf '  Git is not installed (optional).\n'
    else
        git_root=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --show-toplevel 2>/dev/null || :)
        if [ -z "$git_root" ] || [ "$(canonical "$git_root")" != "$TEMPLATE_ROOT" ]; then
            printf '  No independent publication Git repository.\n'
        else
            git_branch=$(GIT_OPTIONAL_LOCKS=0 git symbolic-ref --quiet --short HEAD 2>/dev/null || :)
            git_origin=$(GIT_OPTIONAL_LOCKS=0 git remote get-url origin 2>/dev/null || :)
            git_upstream=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || :)
            printf '  Branch: %s\n  Origin: %s\n  Upstream: %s\n' "${git_branch:-(detached HEAD)}" "${git_origin:-(none)}" "${git_upstream:-(none)}"
        fi
    fi
    report_output() {
        local path=$1 state=absent
        [ ! -f "$TEMPLATE_ROOT/$path" ] || state=present
        printf '  %-55s %s\n' "$path" "$state"
    }
    printf '\nOriginal manuscript\n'; report_output original/paper.pdf; report_output original/paper-original.zip
    for number in "${ACTIVE_ROUNDS[@]}"; do
        manuscript=$TEMPLATE_ROOT/revised$number; reply=$TEMPLATE_ROOT/reply$number
        validate_reply "$reply"
        printf '\nRound %s: baseline %s; reviewers %s; editor separate\n' "$number" "$(cfg "$manuscript/Makefile" BASELINE)" "${REVIEWER_IDS[*]:-(none)}"
        report_output "revised$number/paper.pdf"; report_output "revised$number/paper-diff.pdf"
        report_output "revised$number/paper-revised$number.zip"
        for letter in responses editor $(printf 'reviewer%s ' "${REVIEWER_IDS[@]}"); do
            [ "$letter" != reviewer ] || continue
            report_output "reply$number/$letter.pdf"; report_output "reply$number/$letter-with-diff.pdf"
        done
    done
    printf '\nSource TODO locations (check each occurrence; comments may contain reminders):\n'
    todos=0
    source_stages=(original)
    for number in "${ACTIVE_ROUNDS[@]}"; do source_stages+=("revised$number" "reply$number"); done
    for stage in "${source_stages[@]}"; do
        [ -d "$TEMPLATE_ROOT/$stage" ] || continue
        while IFS= read -r -d '' file; do
            matches=$(grep -nF TODO "$file" || :)
            if [ -n "$matches" ]; then
                while IFS= read -r line; do printf '%s:%s\n' "${file#"$TEMPLATE_ROOT"/}" "$line"; done <<< "$matches"
                todos=$((todos + 1))
            fi
        done < <(find "$TEMPLATE_ROOT/$stage" \( -name build -o -name .reviewer-scaffolds \) -prune -o -type f \( -name '*.tex' -o -name '*.bib' \) -print0)
    done
    [ "$todos" != 0 ] || printf '  None found.\n'
    exit 0
fi
[ "$command" != current ] || [ -z "$round" ] || fail 'current selects the latest round; use submission ROUND=N for a selected submission'
[ -z "$round" ] || positive "$round"
selected=${round:-$LATEST_ROUND}
if [ "$selected" = 0 ]; then manuscript=original; reply=
else
    case " ${ACTIVE_ROUNDS[*]} " in *" $selected "*) ;; *) fail "No complete active round $selected";; esac
    manuscript=revised$selected; reply=reply$selected
    validate_reply "$TEMPLATE_ROOT/$reply"
fi
lock "$TEMPLATE_ROOT"
# Recursive make preserves command-line configuration and the GNU Make jobserver.
make -C "$TEMPLATE_ROOT/$manuscript" all
[ -z "$reply" ] || make -C "$TEMPLATE_ROOT/$reply" all
if [ "$command" = submission ]; then
    if [ -n "$reply" ]; then
        if [ "$cover_given" = 1 ]; then make -C "$TEMPLATE_ROOT/$reply" bundle "COVER=$cover"
        else make -C "$TEMPLATE_ROOT/$reply" bundle; fi
    fi
    make -C "$TEMPLATE_ROOT/$manuscript" zip
fi
printf '\n%s complete. Outputs:\n  %s/paper.pdf\n' "$command" "$manuscript"
if [ -n "$reply" ]; then
    printf '  %s/paper-diff.pdf\n' "$manuscript"
    for letter in responses editor $(printf 'reviewer%s ' "${REVIEWER_IDS[@]}"); do
        [ "$letter" != reviewer ] || continue
        printf '  %s/%s.pdf\n' "$reply" "$letter"
        [ "$command" != submission ] || printf '  %s/%s-with-diff.pdf\n' "$reply" "$letter"
    done
fi
[ "$command" != submission ] || printf '  %s/paper-%s.zip\nInspect the files and submit those required by your journal.\n' "$manuscript" "$manuscript"

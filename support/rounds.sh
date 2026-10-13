#!/usr/bin/env bash
# Root-only reversible transfers of complete review rounds. Bash 3.2 compatible.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
setup_traps
command=${1:-}; [ "$#" -gt 0 ] && shift
round= archive_name=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --round|--archive)
            option=$1; [ "$#" -ge 2 ] || fail "Missing value for $1"
            case "$option" in --round) round=$2;; --archive) archive_name=$2;; esac
            shift 2;;
        *) fail "Unknown option: $1";;
    esac
done
case "$command" in remove-round|restore-round) ;; *) fail "Unknown round command: $command";; esac
require_publication "$command"
[ "$(pwd -P)" = "$TEMPLATE_ROOT" ] || fail 'Run remove-round and restore-round from the publication project root'
[ -n "$round" ] || fail 'Set ROUND=N explicitly'
positive "$round"
archive_root=$TEMPLATE_ROOT/.removed-rounds
revision=$TEMPLATE_ROOT/revised$round
reply=$TEMPLATE_ROOT/reply$round
if [ "$command" = remove-round ]; then
    [ -z "$archive_name" ] || fail 'ARCHIVE is selected only when restoring; removal creates a unique archive'
elif [ -n "$archive_name" ]; then
    [[ "$archive_name" =~ ^round${round}-[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'ARCHIVE must be a round-matching directory basename, not a path'
fi
if [ -e "$archive_root" ] || [ -L "$archive_root" ]; then
    [ -d "$archive_root" ] && [ ! -L "$archive_root" ] || fail 'Archive root must be a real directory, not a symlink'
fi

validate_pair() {
    local rev=$1 rep=$2 id=$3 baseline associated resolved
    [ -d "$rev" ] && [ ! -L "$rev" ] && [ -d "$rep" ] && [ ! -L "$rep" ] || fail "Incomplete or symlinked round $id pair"
    [ -f "$rev/Makefile" ] && [ -f "$rep/Makefile" ] && [ -f "$rev/paper.tex" ] || fail "Missing round $id manuscript or configuration"
    [ "$(cfg "$rev/Makefile" TYPE)" = revision ] || fail "Invalid manuscript TYPE for round $id"
    validate_reply "$rep"
    associated=$(cfg "$rep/Makefile" REVISION)
    [ -n "$associated" ] && [ "$(canonical "$TEMPLATE_ROOT/reply$id/$associated")" = "$TEMPLATE_ROOT/revised$id" ] || fail "Round $id reply REVISION does not name revised$id"
    baseline=$(cfg "$rev/Makefile" BASELINE)
    [ -n "$baseline" ] || fail "Missing BASELINE for round $id"
    # Archived declarations are interpreted at their future active locations.
    resolved=$(canonical "$TEMPLATE_ROOT/revised$id/$baseline")
    [ "$resolved" != "$TEMPLATE_ROOT/revised$id" ] || fail "Round $id cannot be its own baseline"
    [ -f "$resolved/paper.tex" ] || fail "Missing baseline manuscript: $resolved/paper.tex"
}
active_rounds() {
    local path name id
    latest=0
    [ -f "$TEMPLATE_ROOT/original/paper.tex" ] || fail 'Original manuscript is missing'
    for path in "$TEMPLATE_ROOT"/revised* "$TEMPLATE_ROOT"/reply*; do
        [ -e "$path" ] || [ -L "$path" ] || continue
        name=${path##*/}
        if [[ "$name" =~ ^(revised|reply)([1-9][0-9]*)$ ]]; then
            id=${BASH_REMATCH[2]}
            [ -d "$TEMPLATE_ROOT/revised$id" ] && [ ! -L "$TEMPLATE_ROOT/revised$id" ] &&
                [ -d "$TEMPLATE_ROOT/reply$id" ] && [ ! -L "$TEMPLATE_ROOT/reply$id" ] || fail "Unpaired or symlinked active round $id"
            [ "$id" -le "$latest" ] || latest=$id
            case "$name" in revised*) validate_pair "$TEMPLATE_ROOT/revised$id" "$TEMPLATE_ROOT/reply$id" "$id";; esac
        fi
    done
}
check_dependencies() {
    local stage key value resolved
    for stage in "$TEMPLATE_ROOT/original" "$TEMPLATE_ROOT"/revised* "$TEMPLATE_ROOT"/reply*; do
        [ -d "$stage" ] && [ -f "$stage/Makefile" ] || continue
        [ "$stage" != "$revision" ] && [ "$stage" != "$reply" ] || continue
        for key in BASELINE REVISION; do
            value=$(cfg "$stage/Makefile" "$key")
            [ -n "$value" ] || continue
            resolved=$(canonical "$stage/$value")
            case "$resolved/" in "$revision/"*|"$reply/"*) fail "${stage##*/}/Makefile $key depends on round $round";; esac
        done
    done
}

# Archives are durable source data, never registered as disposable TASK_TEMPS.
transfer_active=0
created_archive=
from_revision= from_reply= to_revision= to_reply=
finish_transfer() {
    local rc=$? source destination index
    if [ "$rc" != 0 ] && [ "$transfer_active" = 1 ]; then
        for index in reply revision; do
            if [ "$index" = reply ]; then source=$from_reply; destination=$to_reply
            else source=$from_revision; destination=$to_revision; fi
            if [ -e "$destination" ] || [ -L "$destination" ]; then
                if [ ! -e "$source" ] && [ ! -L "$source" ]; then
                    if ! mv -- "$destination" "$source"; then
                        printf 'Rollback failed; recovery data remains at %s. Do not overwrite it.\n' "$destination" >&2
                    fi
                else
                    printf 'Transfer failed; retaining both %s and %s for recovery.\n' "$source" "$destination" >&2
                fi
            fi
        done
    fi
    if [ "$rc" != 0 ] && [ -n "$created_archive" ]; then rmdir -- "$created_archive" 2>/dev/null || :; fi
    cleanup
    exit "$rc"
}
trap finish_transfer EXIT
lock "$TEMPLATE_ROOT"
active_rounds
if [ "$command" = remove-round ]; then
    [ "$round" = "$latest" ] || fail "Only the latest active round ($latest) can be removed"
    check_dependencies
    lock "$revision"; lock "$reply"
    validate_pair "$revision" "$reply" "$round"
    check_dependencies
    mkdir -p -- "$archive_root"
    created_archive=$(mktemp -d "$archive_root/round$round-XXXXXX")
    archive=$created_archive
    from_revision=$revision; from_reply=$reply
    to_revision=$archive/revised$round; to_reply=$archive/reply$round
else
    [ ! -e "$revision" ] && [ ! -L "$revision" ] && [ ! -e "$reply" ] && [ ! -L "$reply" ] || fail "Refusing to overwrite revised$round or reply$round"
    [ "$round" = "$((latest + 1))" ] || fail "Restore the next round ($((latest + 1))) before later archived rounds"
    [ -d "$archive_root" ] || fail "No archives for round $round"
    if [ -z "$archive_name" ]; then
        candidates=()
        for archive in "$archive_root/round$round-"*; do
            [ -e "$archive" ] || [ -L "$archive" ] || continue
            candidates+=("${archive##*/}")
        done
        [ "${#candidates[@]}" != 0 ] || fail "No archives for round $round"
        if [ "${#candidates[@]}" != 1 ]; then
            printf 'Several archives match round %s:\n' "$round" >&2
            printf '  %s\n' "${candidates[@]}" >&2
            fail "Select one with make restore-round ROUND=$round ARCHIVE=<archive-name>"
        fi
        archive_name=${candidates[0]}
    fi
    archive=$archive_root/$archive_name
    [ -d "$archive" ] && [ ! -L "$archive" ] || fail "Missing or symlinked archive: $archive_name"
    from_revision=$archive/revised$round; from_reply=$archive/reply$round
    to_revision=$revision; to_reply=$reply
    validate_pair "$from_revision" "$from_reply" "$round"
    lock "$from_revision"; lock "$from_reply"
    validate_pair "$from_revision" "$from_reply" "$round"
fi
[ ! -e "$to_revision" ] && [ ! -L "$to_revision" ] && [ ! -e "$to_reply" ] && [ ! -L "$to_reply" ] || fail 'Transfer destinations must be free'
# Register future lock paths before moving, including for interrupt cleanup.
TASK_LOCKS+=("$to_revision/.template-lock" "$to_reply/.template-lock")
transfer_active=1
mv -- "$from_revision" "$to_revision"
mv -- "$from_reply" "$to_reply"
transfer_active=0
if [ "$command" = remove-round ]; then
    printf 'Archived round %s at %s\nRestore with: make restore-round ROUND=%s ARCHIVE=%s\n' "$round" "$archive" "$round" "${archive##*/}"
else
    rmdir -- "$archive" 2>/dev/null || :
    printf 'Restored revised%s and reply%s from %s.\n' "$round" "$round" "$archive_name"
    [ ! -d "$archive" ] || printf 'Unrelated archive files remain at %s.\n' "$archive"
fi

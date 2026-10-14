#!/usr/bin/env bash
# Shared Bash 3.2-compatible utilities. Source this file; do not execute it.
set -e -o pipefail
TEMPLATE_SUPPORT=$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE_ROOT=$(CDPATH= cd -P -- "$TEMPLATE_SUPPORT/.." && pwd)
TASK_LOCKS=()
TASK_TEMPS=()
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
require() { local name; for name in "$@"; do command -v "$name" >/dev/null 2>&1 || fail "Missing tool: $name. See README.md."; done; }
cleanup() {
    local path owner
    for path in "${TASK_TEMPS[@]}"; do [ ! -e "$path" ] || rm -rf -- "$path"; done
    for path in "${TASK_LOCKS[@]}"; do
        owner=$(cat "$path/owner" 2>/dev/null || :)
        if [ "$owner" = "$$" ]; then rm -f -- "$path/owner"; rmdir -- "$path" 2>/dev/null || :; fi
    done
}
setup_traps() { trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM; }
make_temp() { TASK_TEMP=$(mktemp -d "${1:-${TMPDIR:-/tmp}}/.paper-template.XXXXXX"); TASK_TEMPS+=("$TASK_TEMP"); }
lock() {
    local directory=$1 path=$1/.template-lock owner tries=0
    [ -d "$directory" ] || fail "Directory not found: $directory"
    while ! mkdir -- "$path" 2>/dev/null; do
        [ -d "$directory" ] || fail "Stage moved or removed while waiting for its lock: $directory"
        owner=$(cat "$path/owner" 2>/dev/null || :)
        if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
            fail "Stale lock at $path (PID $owner). Confirm no build is active before removing that lock directory."
        fi
        tries=$((tries + 1)); [ "$tries" -le 60 ] || fail "Timed out waiting for $path"
        sleep 1
    done
    printf '%s\n' "$$" > "$path/owner"
    TASK_LOCKS+=("$path")
}
unlock() { rm -f -- "$1/.template-lock/owner"; rmdir -- "$1/.template-lock"; }
# Resolve existing directory symlinks and normalize . and .. without GNU realpath.
canonical() {
    local input=$1 part result=/
    local components=()
    case "$input" in /*) ;; *) input=$PWD/$input;; esac
    IFS=/ read -r -a components <<< "$input"
    for part in "${components[@]}"; do
        case "$part" in ''|.) ;; ..) result=${result%/*}; [ -n "$result" ] || result=/;;
            *) result=${result%/}/$part
               if [ -d "$result" ]; then result=$(CDPATH= cd -P -- "$result" && pwd); fi;;
        esac
    done
    printf '%s\n' "$result"
}
cfg() {
    local file=$1 key=$2 fallback=${3:-}
    awk -v key="$key" -v fallback="$fallback" '
      $0 ~ "^[[:space:]]*" key "[[:space:]]*[:?]?=" {
        value=$0; sub(/^[^=]*=[[:space:]]*/, "", value); sub(/[[:space:]]*#.*/, "", value)
        sub(/[[:space:]]*$/, "", value); print value; found=1; exit
      } END {if (!found) print fallback}' "$file"
}
positive() { [[ "$1" =~ ^[1-9][0-9]*$ ]] || fail "Expected a positive integer, got: $1"; }
require_publication() {
    local role=
    # Read the root file itself: Make arguments and environment overrides cannot
    # grant permission, and calling from a reply folder uses the same policy.
    if [ -f "$TEMPLATE_ROOT/Makefile" ] && [ -r "$TEMPLATE_ROOT/Makefile" ]; then
        role=$(cfg "$TEMPLATE_ROOT/Makefile" PROJECT_ROLE)
    fi
    [ "$role" = publication ] || fail "$1 requires an initialized publication project. This folder is protected: its root Makefile must declare PROJECT_ROLE := publication. Create a project with make init-project DEST=../my-paper and run the command there."
}
load_reviewers() {
    local directory=$1 value id seen=' '
    value=$(cfg "$directory/Makefile" REVIEWERS '1 2')
    REVIEWER_IDS=()
    for id in $value; do
        positive "$id"
        case "$seen" in *" $id "*) fail "Duplicate reviewer $id in $directory/Makefile";; esac
        seen="$seen$id "; REVIEWER_IDS+=("$id")
    done
}
validate_reply() {
    local directory=$1 id
    [ -f "$directory/responses.tex" ] || fail "Not a reply stage: $directory"
    load_reviewers "$directory"
    [ -f "$directory/editor.tex" ] && [ -f "$directory/editor-comments.tex" ] || fail "Missing editor files in $directory"
    for id in "${REVIEWER_IDS[@]}"; do
        [ -f "$directory/reviewer$id.tex" ] && [ -f "$directory/reviewer$id-comments.tex" ] || fail "Missing files for reviewer $id in $directory"
    done
}
set_cfg() {
    local file=$1 key=$2 value=$3 temp=$1.tmp
    awk -v key="$key" -v value="$value" '
      $0 ~ "^[[:space:]]*" key "[[:space:]]*[:?]?=" {print key " := " value; found=1; next}
      /^include / && !found {print key " := " value; found=1}
      {print} END {if (!found) print key " := " value}' "$file" > "$temp"
    mv -- "$temp" "$file"
}
update_file() {
    if [ -f "$2" ] && cmp -s -- "$1" "$2"; then rm -f -- "$1"; else mv -- "$1" "$2"; fi
}
generated_pdf() {
    local stage=$1 relative=$2
    case "$relative" in */*) return 1;; esac
    if [ -f "$stage/paper.tex" ]; then case "$relative" in paper.pdf|paper-diff.pdf) return 0;; esac; fi
    if [ -f "$stage/responses.tex" ]; then
        case "$relative" in responses.pdf|responses-with-diff.pdf|editor.pdf|editor-with-diff.pdf) return 0;; esac
        if [[ "$relative" =~ ^reviewer([1-9][0-9]*)(-with-diff)?\.pdf$ ]]; then
            [ -f "$stage/reviewer${BASH_REMATCH[1]}.tex" ] && return 0
        fi
    fi
    return 1
}
generated_auxiliary() {
    local directory=$1 relative=$2 stem
    case "$relative" in */*) return 1;; esac
    case "$relative" in
        *.aux|*.bbl|*.blg|*.log|*.out|*.toc|*.lof|*.lot|*.lol|*.loa|*.fls|*.fdb_latexmk|*.bcf|*.run.xml|\
        *.idx|*.ilg|*.ind|*.acn|*.acr|*.alg|*.glg|*.glo|*.gls|*.glsdefs|*.slg|*.slo|*.sls|*.sbl|*.sym|\
        *.nlg|*.nlo|*.nls|*.nav|*.snm|*.vrb|*.brf|*.sta|*.tdo|*.dpth|*.auxlock|*.glog|*.ptc|*.xwm|\
        *.dvi|*.xdv|*.pdfsync|*.synctex*) ;;
        *) return 1;;
    esac
    stem=${relative%%.*}
    if [ -f "$directory/paper.tex" ]; then
        case "$stem" in paper|paper-diff) return 0;; esac
    fi
    if [ -f "$directory/responses.tex" ]; then
        case "$stem" in responses|responses-with-diff|editor|editor-with-diff|rebuttal-cover) return 0;; esac
        [[ "$stem" =~ ^reviewer[1-9][0-9]*(-with-diff)?$ ]] && return 0
    fi
    return 1
}
generated_archive() {
    local directory=$1 relative=$2
    [ -f "$directory/paper.tex" ] || return 1
    case "$relative" in paper.zip|"paper-${directory##*/}.zip") return 0;; esac
    return 1
}
copy_sources() {
    local source=$1 destination=$2 file relative
    mkdir -p -- "$destination"
    while IFS= read -r -d '' file; do
        relative=${file#"$source"/}
        case "/$relative/" in */build/*|*/.git/*|*/__pycache__/*|*/.template-lock/*) continue;; esac
        [ ! -L "$file" ] || fail "Source symlinks are not supported: $file"
        case "$relative" in *.aux|*.log|*.bbl|*.blg|*.fls|*.fdb_latexmk|*.synctex|*.synctex.gz|*.pyc|*~) continue;; esac
        if [ -f "$file" ]; then
            generated_pdf "$(dirname -- "$file")" "$(basename -- "$file")" && continue
            generated_archive "$(dirname -- "$file")" "$(basename -- "$file")" && continue
            mkdir -p -- "$destination/$(dirname -- "$relative")"
            cp -p -- "$file" "$destination/$relative"
        fi
    done < <(find "$source" \( -type f -o -type l \) -print0)
}
reviewer_wrapper() {
    sed "s/@@ID@@/$1/g" "$TEMPLATE_SUPPORT/reviewer-wrapper.tex" > "$2"
}
scaffold() {
    local identity=$1 style=$2 heading
    if [ "$identity" = editor ]; then heading='Responses to the Editor comments'; else heading="Responses to the comments of reviewer ${identity#reviewer}"; fi
    sed -e "s/@@HEADING@@/$heading/g" -e "s/@@IDENTITY@@/$identity/g" -e "s/@@LIST@@/$style/g" "$TEMPLATE_SUPPORT/comment-scaffold.tex" > "$3"
}
record_baseline() {
    local stage=$1 id=$2
    mkdir -p -- "$stage/.reviewer-scaffolds"
    cp -p -- "$stage/reviewer$id.tex" "$stage/.reviewer-scaffolds/reviewer$id.tex"
    cp -p -- "$stage/reviewer$id-comments.tex" "$stage/.reviewer-scaffolds/reviewer$id-comments.tex"
}
reply_inputs() {
    local stage=$1 revision=$2 id audience='all the reviewers'
    validate_reply "$stage"
    [ -n "$revision" ] || revision=$(cfg "$stage/Makefile" REVISION)
    [ -n "$revision" ] || fail "Set REVISION in $stage/Makefile"
    case "$revision" in *'{'*|*'}'*|*\\*|*'$'*|*'%'*) fail "Unsupported TeX characters in REVISION";; esac
    mkdir -p -- "$stage/build"
    [ "${#REVIEWER_IDS[@]}" -gt 0 ] || audience='the editor'
    {
        printf '\\def\\ReplyBibliography{%s/paper}\n' "$revision"
        printf '\\def\\CombinedReplyAudience{%s}\n' "$audience"
    } > "$stage/build/reply-config.tex.tmp"
    update_file "$stage/build/reply-config.tex.tmp" "$stage/build/reply-config.tex"
    : > "$stage/build/reviewer-inputs.tex.tmp"
    for id in "${REVIEWER_IDS[@]}"; do printf '\\input{reviewer%s-comments.tex}\n' "$id" >> "$stage/build/reviewer-inputs.tex.tmp"; done
    update_file "$stage/build/reviewer-inputs.tex.tmp" "$stage/build/reviewer-inputs.tex"
}

# Discover paired active rounds numerically and reject structurally invalid stages.
active_rounds() {
    local directory name id baseline revision
    ACTIVE_ROUNDS=(); LATEST_ROUND=0
    [ -f "$TEMPLATE_ROOT/original/paper.tex" ] || fail 'Missing original/paper.tex'
    [ ! -L "$TEMPLATE_ROOT/original" ] || fail 'Stage symlinks are not supported: original'
    for directory in "$TEMPLATE_ROOT"/revised* "$TEMPLATE_ROOT"/reply*; do
        [ -e "$directory" ] || [ -L "$directory" ] || continue
        name=${directory##*/}
        [[ "$name" =~ ^(revised|reply)([1-9][0-9]*)$ ]] || continue
        id=${BASH_REMATCH[2]}
        [ -d "$directory" ] && [ ! -L "$directory" ] || fail "Invalid stage directory: $name"
        [ -d "$TEMPLATE_ROOT/revised$id" ] && [ -d "$TEMPLATE_ROOT/reply$id" ] || fail "Unpaired stage: $name"
        [ -f "$TEMPLATE_ROOT/revised$id/paper.tex" ] || fail "Missing revised$id/paper.tex"
        [ -f "$TEMPLATE_ROOT/revised$id/Makefile" ] && [ -f "$TEMPLATE_ROOT/reply$id/Makefile" ] || fail "Missing Makefile in round $id"
        baseline=$(cfg "$TEMPLATE_ROOT/revised$id/Makefile" BASELINE)
        revision=$(cfg "$TEMPLATE_ROOT/reply$id/Makefile" REVISION)
        [ -n "$baseline" ] && [ -f "$(canonical "$TEMPLATE_ROOT/revised$id/$baseline")/paper.tex" ] || fail "Missing baseline for revised$id"
        [ -n "$revision" ] && [ "$(canonical "$TEMPLATE_ROOT/reply$id/$revision")" = "$TEMPLATE_ROOT/revised$id" ] || fail "Invalid REVISION for reply$id"
    done
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        ACTIVE_ROUNDS+=("$id"); LATEST_ROUND=$id
    done < <(for directory in "$TEMPLATE_ROOT"/revised*; do
        [ -d "$directory" ] || continue; name=${directory##*/}
        [[ "$name" =~ ^revised([1-9][0-9]*)$ ]] && printf '%s\n' "${BASH_REMATCH[1]}"
    done | sort -n)
}

#!/usr/bin/env bash
# Run from the incoming template, including when invoked by an older publication.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
source "$TEMPLATE_SUPPORT/managed.sh" || exit 1
setup_traps
destination= apply=0
while [ "$#" -gt 0 ]; do
    option=$1; [ "$#" -ge 2 ] || fail "Missing value for $option"
    case "$option" in --dest) destination=$2;; --apply) apply=$2;; *) fail "Unknown option: $option";; esac
    shift 2
done
[[ "$apply" = 0 || "$apply" = 1 ]] || fail 'APPLY must be 0 or 1'
[ "$(cfg "$TEMPLATE_ROOT/Makefile" PROJECT_ROLE)" = template ] || fail 'Updates must come from a template checkout (PROJECT_ROLE := template)'
[ -n "$destination" ] || fail 'Set DEST=/path/to/publication-project'
[ -d "$destination" ] && [ ! -L "$destination" ] || fail 'DEST must be a real publication-project directory'
destination=$(canonical "$destination")
case "$destination/" in "$TEMPLATE_ROOT/"* ) fail 'The update destination must be outside the template checkout';; esac
case "$TEMPLATE_ROOT/" in "$destination/"*) fail 'The template checkout must be outside the destination project';; esac
[ "$(cfg "$destination/Makefile" PROJECT_ROLE)" = publication ] || fail 'Updates require an initialized publication project; the template clone is protected'
require cksum awk sort cp mv find cmp mktemp date
safe_path() {
    local root=$1 relative=$2 part current=$1
    case "$relative" in ''|/*|*..*|*$'\n'*|*$'\t'*) fail "Invalid managed path: $relative";; esac
    local components=()
    IFS=/ read -r -a components <<< "$relative"
    for part in "${components[@]}"; do
        current=$current/$part
        [ ! -L "$current" ] || fail "Refusing managed symlink: $current"
    done
}
for path in Makefile README.md HOWTO.md support tests .gitignore .template-update .template-update/manifest .template-update/backups; do
    safe_path "$destination" "$path"
done
if [ "$apply" = 1 ]; then
    lock "$destination"
    # Folder-level builds also take these locks, so no helper is replaced mid-build.
    for stage in "$destination/original" "$destination"/revised* "$destination"/reply*; do
        [ -d "$stage" ] || continue
        name=${stage##*/}; [[ "$name" = original || "$name" =~ ^(revised|reply)[1-9][0-9]*$ ]] || continue
        [ ! -L "$stage" ] || fail "Stage symlink: $stage"
        lock "$stage"
    done
fi
make_temp; transaction=$TASK_TEMP
incoming=$transaction/incoming; mkdir -- "$incoming"
managed_paths "$TEMPLATE_ROOT" | sort > "$transaction/paths"
# Check source paths before copying; never execute code from the destination.
while IFS= read -r relative; do
    safe_path "$TEMPLATE_ROOT" "$relative"
    mkdir -p -- "$incoming/$(dirname -- "$relative")"
    cp -p -- "$TEMPLATE_ROOT/$relative" "$incoming/$relative"
done < "$transaction/paths"
set_cfg "$incoming/Makefile" PROJECT_ROLE publication
publication_readme "$incoming/README.md"
record_managed "$incoming"
legacy=0
if [ -f "$destination/.template-update/manifest" ]; then baseline=$destination/.template-update/manifest
else legacy=1; baseline=$TEMPLATE_SUPPORT/update-legacy.tsv; printf 'Legacy project: using the baseline for template commit 6f956cd.\n'; fi
[ -f "$baseline" ] || fail 'No recognized managed-file baseline; update this project manually'
# Validate manifest fields before using any paths, including removals.
awk -F '\t' 'NF!=3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ || seen[$3]++ {bad=1} END {exit bad}' "$baseline" || fail 'Malformed managed-file manifest'
while IFS=$'\t' read -r crc size relative; do
    case "$relative" in Makefile|README.md|HOWTO.md|support/*|tests/*) ;; *) fail "Unsupported managed path: $relative";; esac
    safe_path "$destination" "$relative"
done < "$baseline"
previous_signature() { awk -F '\t' -v path="$1" '$3==path {print $1 "\t" $2; exit}' "$baseline"; }
# Additional exact upstream versions are accepted only for pre-manifest projects.
# A recorded baseline still protects all subsequent author customizations.
recognized_legacy_version() {
    [ "$legacy" = 1 ] && [ -n "$2" ] || return 1
    local match
    match=$(awk -F '\t' -v path="$1" -v signature="$2" '
      $3==path && ($1 "\t" $2)==signature {print $4; exit}' "$TEMPLATE_SUPPORT/update-legacy-variants.tsv")
    [ -n "$match" ] || return 1
    printf '%s' "$match"
}
changes=(); actions=(); preserved=(); conflicts=0
printf 'Update preview for %s\n' "$destination"
while IFS=$'\t' read -r crc size relative; do
    safe_path "$destination" "$relative"
    safe_path "$destination" "$relative.template-update.tmp"
    [ ! -e "$destination/$relative.template-update.tmp" ] || fail "Reserved update temporary path already exists: $relative.template-update.tmp"
    source_signature=$crc$'\t'$size
    old_signature=$(previous_signature "$relative")
    local_signature=
    if [ -e "$destination/$relative" ]; then
        [ -f "$destination/$relative" ] || fail "Managed path is not a file: $relative"
        local_signature=$(file_signature "$destination/$relative")
    fi
    [ "$local_signature" != "$source_signature" ] || continue
    if { [ -z "$old_signature" ] && [ -z "$local_signature" ]; } || { [ -n "$old_signature" ] && [ "$local_signature" = "$old_signature" ]; }; then
        changes+=("$relative"); actions+=(replace); printf '  replace %s\n' "$relative"
    elif version=$(recognized_legacy_version "$relative" "$local_signature"); then
        changes+=("$relative"); actions+=(replace)
        printf '  replace recognized legacy %s (template commit %s)\n' "$relative" "$version"
    else
        case "$relative" in
            README.md|HOWTO.md) preserved+=("$relative"); printf '  preserve customized %s (incoming copy available after APPLY=1)\n' "$relative";;
            *) printf '  CONFLICT %s: customized, removed, or unrecognized\n' "$relative"; conflicts=$((conflicts + 1));;
        esac
    fi
done < "$incoming/.template-update/manifest"
while IFS=$'\t' read -r crc size relative; do
    [ ! -f "$incoming/$relative" ] || continue
    if [ -f "$destination/$relative" ]; then
        if [ "$(file_signature "$destination/$relative")" = "$crc"$'\t'"$size" ]; then
            changes+=("$relative"); actions+=(remove); printf '  remove obsolete managed file %s\n' "$relative"
        else printf '  CONFLICT obsolete customized file %s\n' "$relative"; conflicts=$((conflicts + 1)); fi
    fi
done < "$baseline"
[ "$conflicts" = 0 ] || fail "$conflicts managed-file conflicts. Reconcile them manually and preview again; nothing was replaced."
printf '  %s replacements/removals; %s customized guides retained.\n' "${#changes[@]}" "${#preserved[@]}"
printf '  preserve manuscript stages, response sources, LICENSE, and existing ignore rules\n'
if [ "$apply" = 0 ]; then
    printf 'Preview only; no project files changed. Apply with APPLY=1.\n'
    exit 0
fi
if [ "${#changes[@]}" = 0 ] && [ "${#preserved[@]}" = 0 ] && [ -f "$destination/.template-update/manifest" ] && cmp -s "$destination/.template-update/manifest" "$incoming/.template-update/manifest" && grep -Fxq '/.template-update/backups/' "$destination/.gitignore"; then
    printf 'Infrastructure already matches this template; no backup or replacement needed.\n'
    exit 0
fi
# State, docs, ignore rules, and replacements are all part of one rollback unit.
backup_parent=$destination/.template-update/backups
mkdir -p -- "$backup_parent"
backup=$(mktemp -d "$backup_parent/update-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX")
mkdir -- "$backup/old" "$backup/incoming"
: > "$backup/actions.tsv"
for relative in "${changes[@]}" .gitignore .template-update/manifest; do
    if [ -f "$destination/$relative" ]; then
        mkdir -p -- "$backup/old/$(dirname -- "$relative")"
        cp -p -- "$destination/$relative" "$backup/old/$relative"
        printf 'restore\t%s\n' "$relative" >> "$backup/actions.tsv"
    else printf 'delete\t%s\n' "$relative" >> "$backup/actions.tsv"; fi
done
for relative in "${preserved[@]}"; do cp -p -- "$incoming/$relative" "$backup/incoming/$relative"; done
rollback_update() {
    local rc=$? action relative
    trap - EXIT INT TERM
    if [ "$rc" != 0 ]; then
        for relative in "${changes[@]}"; do rm -f -- "$destination/$relative.template-update.tmp" || :; done
        while IFS=$'\t' read -r action relative; do
            if [ "$action" = restore ]; then cp -p -- "$backup/old/$relative" "$destination/$relative" || :
            else rm -f -- "$destination/$relative" || :; fi
        done < "$backup/actions.tsv"
        printf 'Update failed; replacements rolled back. Backup: %s\n' "$backup" >&2
    fi
    cleanup
    exit "$rc"
}
trap rollback_update EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
index=0
for relative in "${changes[@]}"; do
    if [ "${actions[$index]}" = remove ]; then rm -- "$destination/$relative"
    else
        mkdir -p -- "$destination/$(dirname -- "$relative")"
        # Temporary file and rename keep each replacement complete.
        cp -p -- "$incoming/$relative" "$destination/$relative.template-update.tmp"
        mv -- "$destination/$relative.template-update.tmp" "$destination/$relative"
    fi
    index=$((index + 1))
done
if ! grep -Fxq '/.template-update/backups/' "$destination/.gitignore" 2>/dev/null; then
    printf '\n# Local template-update backups.\n/.template-update/backups/\n' >> "$destination/.gitignore"
fi
cp -p -- "$incoming/.template-update/manifest" "$destination/.template-update/manifest"
printf 'Update complete. Backup: %s\n' "$backup"
[ "${#preserved[@]}" = 0 ] || printf 'Customized guides retained; compare incoming guides under %s/incoming/.\n' "$backup"
printf 'Existing ignore rules were retained; compare the template .gitignore for other new exclusions.\nRun make status and make current, then review and commit the infrastructure changes if you use Git.\n'

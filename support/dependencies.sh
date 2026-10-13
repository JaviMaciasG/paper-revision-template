#!/usr/bin/env bash
# Source after common.sh. Read latexmk's documented dependency export, not its
# private database. Its none-escaped format puts one filename on each line.
dependency_lexical_path() {
    local input=$1 part result=/
    local components=()
    case "$input" in /*) ;; *) input=$PWD/$input;; esac
    IFS=/ read -r -a components <<< "$input"
    for part in "${components[@]}"; do
        case "$part" in ''|.) ;; ..) result=${result%/*}; [ -n "$result" ] || result=/;;
            *) result=${result%/}/$part;; esac
    done
    printf '%s\n' "$result"
}
copy_manuscript_dependencies() {
    local source=$1 destination=$2 manifest=$1/build/paper.deps file path relative part current root installed
    local preserve_bibliography=${3:-1}
    case "$preserve_bibliography" in 0|1) ;; *) fail 'Invalid bibliography preservation policy';; esac
    local tex_roots=() tex_configs=() components=()
    require kpsewhich
    [ -f "$manifest" ] || fail "Missing manuscript dependency export: $manifest"
    grep -Fqx '#===Dependents, and related info, for paper.tex:' "$manifest" &&
        grep -Fqx '#===End dependents for paper.tex:' "$manifest" || fail "Incomplete latexmk dependency export: $manifest"
    [ ! -e "$destination" ] && [ ! -L "$destination" ] || fail "Dependency destination already exists: $destination"
    IFS=: read -r -a components <<< "$(kpsewhich -expand-path='$TEXMF')"
    for root in "${components[@]}"; do
        root=${root#'!!'}
        [ -n "$root" ] && [ -d "$root" ] || continue
        tex_roots+=("$(canonical "$root")")
    done
    # TeX Live can keep texmf.cnf above its TEXMF trees (notably on macOS).
    # Admit only the exact configuration files registered with Kpathsea.
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        tex_configs+=("$(canonical "$file")")
    done < <(kpsewhich -all texmf.cnf)
    # Normalize and classify before resolving any local directory symlinks.
    mkdir -p -- "$destination"
    while IFS= read -r file; do
        case "$file" in /*) path=$(dependency_lexical_path "$file");; *) path=$(dependency_lexical_path "$source/$file");; esac
        case "$path" in
            "$source/"*)
                relative=${path#"$source"/}
                case "/$relative/" in */build/*|*/.git/*|*/__pycache__/*|*/.template-lock/*)
                    fail "Required source dependency is in a generated/transient directory: $relative";; esac
                current=$source
                IFS=/ read -r -a components <<< "$relative"
                for part in "${components[@]}"; do
                    current=$current/$part
                    [ ! -L "$current" ] || fail "Source symlinks are not supported: $current"
                done
                [ -f "$path" ] || fail "Missing manuscript dependency: $path"
                mkdir -p -- "$destination/$(dirname -- "$relative")"
                cp -p -- "$path" "$destination/$relative";;
            *)
                case "$path" in "$TEMPLATE_ROOT/"*) fail "Manuscript dependencies must be stage-local: $path";; esac
                installed=0
                for root in "${tex_roots[@]}"; do
                    case "$path" in "$root/"*) installed=1; break;; esac
                done
                if [ "$installed" = 0 ]; then
                    path=$(canonical "$path")
                    for root in "${tex_roots[@]}"; do
                        case "$path" in "$root/"*) installed=1; break;; esac
                    done
                fi
                if [ "$installed" = 0 ]; then
                    for file in "${tex_configs[@]}"; do
                        [ "$path" != "$file" ] || { installed=1; break; }
                    done
                fi
                [ "$installed" = 1 ] || fail "Required dependency is outside the manuscript stage and TeX installation: $path";;
        esac
    done < <(awk '/^    / {line=substr($0,5); sub(/\\$/, "", line); print line}' "$manifest")
    [ -f "$destination/paper.tex" ] || fail 'latexmk did not report paper.tex as a source dependency'
    # Revision snapshots keep the shared database; ZIPs select only compilation dependencies.
    if [ "$preserve_bibliography" = 1 ] && { [ -e "$source/paper.bib" ] || [ -L "$source/paper.bib" ]; }; then
        [ ! -L "$source/paper.bib" ] || fail "Source symlinks are not supported: $source/paper.bib"
        [ -f "$source/paper.bib" ] || fail 'paper.bib must be a regular file'
        cp -p -- "$source/paper.bib" "$destination/paper.bib"
    fi
}

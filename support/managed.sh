#!/usr/bin/env bash
# Managed infrastructure bookkeeping; role authorization remains in Makefile.
publication_readme() {
    local file=$1
    awk '
      tolower($0) ~ /^# (ieee|generic) manuscript and rebuttal template$/ {print "# Manuscript Project"; next}
      /^A reusable paper project/ || /^The repo contains a reusable template/ {
        print "This initialized author project starts with a minimal IEEE manuscript in original/. Replace original/paper.tex and original/paper.bib with your real manuscript and bibliography. There are no active revisions yet; make new-round creates round one. The guided HOWTO.md, example assets, and independent test fixtures are included for reference."; next}
      {print}' "$file" > "$file.tmp"
    mv -- "$file.tmp" "$file"
}
managed_paths() {
    local root=$1 file relative
    printf '%s\n' Makefile README.md HOWTO.md
    [ -d "$root/support" ] && [ ! -L "$root/support" ] && [ -d "$root/tests" ] && [ ! -L "$root/tests" ] || fail 'Managed support/tests directories must be real directories'
    find "$root/support" "$root/tests" \( -type f -o -type l \) -print0 | while IFS= read -r -d '' file; do
        relative=${file#"$root"/}
        case "/$relative/" in */build/*|*/.git/*|*/.template-lock/*|*/.paper-template.*/*|*/__pycache__/*) continue;; esac
        case "$relative" in *$'\n'*|*$'\t'*) fail 'Managed paths cannot contain tabs or newlines';; esac
        [ ! -L "$file" ] || fail "Managed source symlink: $file"
        case "$relative" in *.aux|*.log|*.bbl|*.blg|*.fls|*.fdb_latexmk|*.synctex|*.synctex.gz|*.pyc|*~) continue;; esac
        generated_pdf "$(dirname -- "$file")" "${file##*/}" && continue
        generated_archive "$(dirname -- "$file")" "${file##*/}" && continue
        printf '%s\n' "$relative"
    done
}
file_signature() { cksum < "$1" | awk '{print $1 "\t" $2}'; }
record_managed() {
    local root=$1 relative
    require cksum
    mkdir -p -- "$root/.template-update"
    managed_paths "$root" | sort > "$root/.template-update/paths.tmp"
    : > "$root/.template-update/manifest.tmp"
    while IFS= read -r relative; do
        printf '%s\t%s\n' "$(file_signature "$root/$relative")" "$relative" >> "$root/.template-update/manifest.tmp"
    done < "$root/.template-update/paths.tmp"
    rm -- "$root/.template-update/paths.tmp"
    mv -- "$root/.template-update/manifest.tmp" "$root/.template-update/manifest"
}

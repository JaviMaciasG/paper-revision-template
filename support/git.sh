#!/usr/bin/env bash
# Optional Git/GitHub setup. No authentication tokens or global Git config are written.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" || exit 1
setup_traps
command=${1:-}
case "$command" in git-init|github-init) ;; *) fail "Unknown Git setup command: $command";; esac
[ "$#" = 1 ] || fail "Use make $command with REPO/VISIBILITY variables; unexpected helper arguments"
require_publication "$command"
[ "$(pwd -P)" = "$TEMPLATE_ROOT" ] || fail 'Run Git setup targets from the publication root'
require git
# Explicit Git directory/index overrides could address a different repository.
for name in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_NAMESPACE; do
    [ -z "${!name}" ] || fail "Unset $name before running Git setup"
done
[ ! -L "$TEMPLATE_ROOT/.git" ] || fail 'Git metadata must not be a symlink'
project_git_root() {
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    [ "$(canonical "$root")" = "$TEMPLATE_ROOT" ]
}
if [ "$command" = git-init ]; then
    lock "$TEMPLATE_ROOT"
    created=0
    if ! project_git_root; then
        [ ! -e "$TEMPLATE_ROOT/.git" ] || fail 'Existing Git metadata does not identify this publication root'
        git init -q .
        git symbolic-ref HEAD refs/heads/main
        created=1
    fi
    project_git_root || fail 'Refusing to stage or commit files outside this publication repository'
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
        printf 'Git history already exists; no files staged and no commit created.\nNext: make github-init (optional REPO=owner/name VISIBILITY=public).\n'
        exit 0
    fi
    if [ "$created" = 1 ]; then
        git config --local push.default simple
        git config --local pull.ff only
    fi
    if ! git var GIT_AUTHOR_IDENT >/dev/null 2>&1 || ! git var GIT_COMMITTER_IDENT >/dev/null 2>&1; then
        printf '%s\n' 'Configure your commit identity in this project, then rerun make git-init:' \
          '  git config --local user.name "Your Name"' \
          '  git config --local user.email "you@example.org"' >&2
        fail 'Missing Git commit identity; no files staged'
    fi
    printf 'Files to add for the initial commit (Git ignore rules apply):\n'
    git add --all --dry-run -- .
    if [ -n "$(git ls-files --cached)" ]; then
        printf 'Files already in the index, also included in the initial commit:\n'
        git ls-files --cached
    fi
    printf 'Proceed with staging and the initial commit? [y/N] '
    answer=
    if ! IFS= read -r answer; then answer=; fi
    case "$answer" in
        y|Y) ;;
        *) printf '\nCancelled; the index and commit history are unchanged.\n'; exit 0;;
    esac
    git add --all -- .
    printf 'Files staged for the initial commit (Git ignore rules apply):\n'
    git --no-pager diff --cached --stat
    git commit -m 'chore: initialize manuscript project'
    printf 'Local repository ready. Next: make github-init (optional REPO=owner/name VISIBILITY=public).\n'
    exit 0
fi
project_git_root || fail 'No independent publication Git repository; run make git-init first'
git rev-parse --verify HEAD >/dev/null 2>&1 || fail 'No local commit; run make git-init first'
branch=$(git symbolic-ref --quiet --short HEAD) || fail 'Detached HEAD; switch to the branch you want to publish'
visibility=${TEMPLATE_GIT_VISIBILITY:-private}
case "$visibility" in private|public) ;; *) fail 'VISIBILITY must be private or public';; esac
require gh ssh
export GH_HOST=github.com
lock "$TEMPLATE_ROOT"
gh auth status --hostname github.com >/dev/null 2>&1 || fail 'GitHub CLI is not authenticated. Run gh auth login --hostname github.com --git-protocol ssh, then retry'
repo=${TEMPLATE_GIT_REPO:-}
if [ -z "$repo" ]; then repo=${TEMPLATE_ROOT##*/}; fi
case "$repo" in */*) ;; *)
    owner=$(gh api --hostname github.com user --jq .login) || fail 'Unable to determine the authenticated GitHub user'
    repo=$owner/$repo;;
esac
[[ "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+$ ]] || fail 'Invalid GitHub repository name. Set REPO=owner/name (required if the folder name contains spaces)'
owner=${repo%%/*}; repo_name=${repo#*/}
[ "$repo_name" != . ] && [ "$repo_name" != .. ] || fail 'Invalid GitHub repository name'
ssh_url=git@github.com:$repo.git
origin=$(git remote get-url --all origin 2>/dev/null || :)
origin_push=$(git remote get-url --push --all origin 2>/dev/null || :)
repo_from_url() {
    local value=$1
    case "$value" in
        git@github.com:*) value=${value#git@github.com:};;
        ssh://git@github.com/*) value=${value#ssh://git@github.com/};;
        https://github.com/*) value=${value#https://github.com/};;
        *) return 1;;
    esac
    value=${value%.git}; value=${value%/}
    printf '%s' "$value" | tr '[:upper:]' '[:lower:]'
}
requested=$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]')
while IFS= read -r value; do
    [ -z "$value" ] || [ "$(repo_from_url "$value" || :)" = "$requested" ] || fail 'Existing origin points elsewhere; it was not changed. Set REPO to its GitHub repository or reconcile origin manually'
done <<< "$origin
$origin_push"
# GitHub intentionally returns status 1 after a successful SSH authentication.
ssh_status=0
ssh_result=$(ssh -o BatchMode=yes -o ConnectTimeout=10 -T git@github.com 2>&1) || ssh_status=$?
if [ "$ssh_status" != 1 ] || ! printf '%s\n' "$ssh_result" | grep -Fq 'successfully authenticated'; then
    printf '%s\n' "$ssh_result" >&2
    fail 'SSH authentication failed. Configure your GitHub SSH key/agent and test ssh -T git@github.com, then retry'
fi
metadata_query='.nameWithOwner, .visibility, .isEmpty'
metadata=$(gh repo view "$repo" --json nameWithOwner,visibility,isEmpty --jq "$metadata_query" 2>/dev/null) || metadata=
if [ -z "$metadata" ]; then
    # Creation uses explicit visibility and does not inject remote-only source files.
    # If creation fails (including a concurrent creator), query again before resuming.
    if ! gh repo create "$repo" "--$visibility"; then
        printf 'Repository creation failed; checking whether the requested repository already exists.\n' >&2
    fi
    metadata=$(gh repo view "$repo" --json nameWithOwner,visibility,isEmpty --jq "$metadata_query") || fail 'Unable to access the requested repository; check authentication, permissions, and connectivity'
fi
canonical_repo=$(printf '%s\n' "$metadata" | sed -n '1p')
remote_visibility=$(printf '%s\n' "$metadata" | sed -n '2p' | tr '[:upper:]' '[:lower:]')
is_empty=$(printf '%s\n' "$metadata" | sed -n '3p')
[ "$(printf '%s' "$canonical_repo" | tr '[:upper:]' '[:lower:]')" = "$requested" ] || fail 'GitHub returned an unexpected repository identity'
case "$remote_visibility:$is_empty" in private:true|private:false|public:true|public:false|internal:true|internal:false) ;; *) fail 'Unable to read repository visibility and history';; esac
if [ "$visibility" != "$remote_visibility" ]; then
    fail 'Existing repository visibility differs from VISIBILITY; choose the matching visibility explicitly or change it manually before retrying'
fi
# Verify history before changing origin. Fetching by URL updates objects and
# FETCH_HEAD, without changing existing origin tracking refs or working files.
if [ "$is_empty" = false ]; then
    make_temp
    git ls-remote --exit-code "$ssh_url" "refs/heads/$branch" > "$TASK_TEMP/remote-head" || fail "Nonempty repository has no matching branch $branch; reconcile the branches manually"
    git fetch --no-tags "$ssh_url" "refs/heads/$branch" || fail 'Unable to fetch remote history; origin was not changed'
    remote_head=$(git rev-parse FETCH_HEAD)
    git merge-base HEAD "$remote_head" >/dev/null 2>&1 || fail 'Remote branch has unrelated history; origin was not changed'
fi
if [ -z "$origin" ]; then git remote add origin "$ssh_url"
else
    git config --local --replace-all remote.origin.url "$ssh_url"
fi
# Explicitly use SSH for pushes too, after checking all existing push URLs.
git config --local --replace-all remote.origin.pushurl "$ssh_url"
if ! git push --set-upstream origin "$branch"; then
    printf 'Remote retained: https://github.com/%s\n' "$canonical_repo" >&2
    printf 'No commits or repository were deleted. Resolve SSH/access errors, or fetch and inspect divergent history; then rerun make github-init REPO=%s VISIBILITY=%s.\n' "$canonical_repo" "$visibility" >&2
    fail 'Initial push failed; no force push was attempted'
fi
printf 'GitHub repository ready: https://github.com/%s\nVisibility: %s\nBranch: %s; upstream: origin/%s\nUse git push and git pull for subsequent synchronization. Commit further edits before pushing.\n' "$canonical_repo" "$visibility" "$branch" "$branch"

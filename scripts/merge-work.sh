#!/usr/bin/env bash
# Merge an agent's worktree branch back into the main branch.
# Usage: merge-work.sh <branch-name> [--delete]
# Example: merge-work.sh agent/executor/add-auth
# Example: merge-work.sh agent/executor/add-auth --delete
#
# --delete: also remove the worktree and branch after merging.
#
# Security notes:
#   - Branch and worktree paths are validated before being used in git
#     commands.
#   - Worktree paths are looked up via `git worktree list --porcelain`
#     parsed with awk, not grep+sed, to avoid regex meta-character bugs.
#   - The working tree is required to be clean before checkout to prevent
#     accidental data loss.

set -euo pipefail

if [ $# -lt 1 ]; then
  printf 'Usage: %s <branch-name> [--delete]\n' "$0" >&2
  printf 'Example: %s agent/executor/add-auth\n' "$0" >&2
  exit 1
fi

BRANCH_NAME="$1"
DELETE_AFTER="${2:-}"

# Validate the branch name. Allow only the documented format
# `agent/<role>/<task-id>` plus the underlying allowed character set.
if ! [[ "$BRANCH_NAME" =~ ^agent/[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*$ ]]; then
  printf 'Error: branch name must match agent/<role>/<task-id> with [a-z0-9-] segments\n' >&2
  printf '  (rejected: %q)\n' "$BRANCH_NAME" >&2
  exit 1
fi
if ! git check-ref-format --branch "$BRANCH_NAME" >/dev/null 2>&1; then
  printf 'Error: git rejected branch name: %q\n' "$BRANCH_NAME" >&2
  exit 1
fi

# Detect main branch
MAIN_BRANCH="${MAIN_BRANCH:-}"
if [ -z "$MAIN_BRANCH" ]; then
  if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    MAIN_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    MAIN_BRANCH="master"
  else
    MAIN_BRANCH=$(git branch --show-current)
  fi
fi

if ! git check-ref-format --branch "$MAIN_BRANCH" >/dev/null 2>&1; then
  printf 'Error: invalid main branch: %q\n' "$MAIN_BRANCH" >&2
  exit 1
fi

# Verify the branch exists
if ! git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}" 2>/dev/null; then
  printf 'Error: branch does not exist: %q\n' "$BRANCH_NAME" >&2
  exit 1
fi

# Refuse to merge if the working tree has uncommitted changes — checkout
# would either fail or carry them onto the target branch silently.
if ! git diff --quiet || ! git diff --cached --quiet; then
  printf 'Error: working tree has uncommitted changes. Commit or stash first.\n' >&2
  exit 1
fi

printf 'Merging %s into %s\n\n' "$BRANCH_NAME" "$MAIN_BRANCH"

# Show what will be merged
printf 'Changes to merge:\n'
git log --oneline "${MAIN_BRANCH}..${BRANCH_NAME}" 2>/dev/null || printf '  (no commits)\n'
printf '\n'
git diff --stat "${MAIN_BRANCH}...${BRANCH_NAME}" 2>/dev/null || printf '  (no file changes)\n'
printf '\n'

# Ensure we're on main
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
  printf 'Switching to %s...\n' "$MAIN_BRANCH"
  git checkout -- "$MAIN_BRANCH"
fi

# Merge with a descriptive message. Split title and body across two `-m`
# flags so a future loosening of the branch-name regex cannot inject
# newlines into the commit metadata.
git merge --no-ff \
  -m "Merge ${BRANCH_NAME} into ${MAIN_BRANCH}" \
  -m "Agent team merge — automated by agent-team skill." \
  "$BRANCH_NAME"

printf '\nMerge successful.\n'

# Clean up if requested
if [ "$DELETE_AFTER" = "--delete" ]; then
  printf '\nCleaning up...\n'

  # Find the worktree path for the branch via porcelain output, parsed with
  # awk so branch-name regex meta-characters cannot mis-target a removal.
  WORKTREE_PATH=$(
    git worktree list --porcelain | awk -v target="refs/heads/${BRANCH_NAME}" '
      /^worktree / { wt = substr($0, 10) }
      /^branch /   { if (substr($0, 8) == target) { print wt; exit } }
    '
  )

  if [ -n "$WORKTREE_PATH" ] && [ "$WORKTREE_PATH" != "$(pwd)" ]; then
    if git worktree remove -- "$WORKTREE_PATH" 2>/dev/null; then
      printf '  Removed worktree: %s\n' "$WORKTREE_PATH"
    else
      printf '  Worktree could not be removed (already gone or in use): %s\n' "$WORKTREE_PATH"
    fi
  fi

  # Delete the branch
  if git branch -d -- "$BRANCH_NAME" 2>/dev/null; then
    printf '  Deleted branch: %s\n' "$BRANCH_NAME"
  else
    printf '  Branch could not be deleted (not fully merged or already gone): %s\n' "$BRANCH_NAME"
  fi
fi

printf '\nDone. Current branch: %s\n' "$(git branch --show-current)"

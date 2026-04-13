#!/usr/bin/env bash
# Merge an agent's worktree branch back to the main branch.
# Usage: merge-work.sh <branch-name> [--delete]
# Example: merge-work.sh agent/executor/add-auth
# Example: merge-work.sh agent/executor/add-auth --delete
#
# --delete: also remove the worktree and branch after merging

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <branch-name> [--delete]"
  echo "Example: $0 agent/executor/add-auth"
  exit 1
fi

BRANCH_NAME="$1"
DELETE_AFTER="${2:-}"

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

# Verify the branch exists
if ! git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}" 2>/dev/null; then
  echo "Error: branch '${BRANCH_NAME}' does not exist"
  exit 1
fi

echo "Merging ${BRANCH_NAME} into ${MAIN_BRANCH}"

# Show what will be merged
echo ""
echo "Changes to merge:"
git log --oneline "${MAIN_BRANCH}..${BRANCH_NAME}" 2>/dev/null || echo "  (no commits)"
echo ""
git diff --stat "${MAIN_BRANCH}...${BRANCH_NAME}" 2>/dev/null || echo "  (no file changes)"
echo ""

# Ensure we're on main
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
  echo "Switching to ${MAIN_BRANCH}..."
  git checkout "${MAIN_BRANCH}"
fi

# Merge with a descriptive message
git merge "${BRANCH_NAME}" --no-ff -m "Merge ${BRANCH_NAME} into ${MAIN_BRANCH}

Agent team merge — automated by agent-team skill."

echo ""
echo "Merge successful."

# Clean up if requested
if [ "$DELETE_AFTER" = "--delete" ]; then
  echo ""
  echo "Cleaning up..."

  # Find and remove the worktree
  WORKTREE_PATH=$(git worktree list --porcelain | grep -B1 "branch refs/heads/${BRANCH_NAME}" | head -1 | sed 's/worktree //')
  if [ -n "$WORKTREE_PATH" ] && [ "$WORKTREE_PATH" != "$(pwd)" ]; then
    git worktree remove "$WORKTREE_PATH" 2>/dev/null || echo "  Worktree already removed"
    echo "  Removed worktree: ${WORKTREE_PATH}"
  fi

  # Delete the branch
  git branch -d "${BRANCH_NAME}" 2>/dev/null || echo "  Branch already deleted"
  echo "  Deleted branch: ${BRANCH_NAME}"
fi

echo ""
echo "Done. Current branch: $(git branch --show-current)"

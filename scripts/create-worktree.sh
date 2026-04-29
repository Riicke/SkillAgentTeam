#!/usr/bin/env bash
# Create a git worktree for an agent.
# Usage: create-worktree.sh <agent-name> <task-id>
# Example: create-worktree.sh executor add-auth
#
# Creates: .worktrees/agent-<name>-<task-id>/
# Branch:  agent/<name>/<task-id>
#
# Security notes:
#   - Both arguments are validated against ^[a-z0-9][a-z0-9-]*$ to prevent
#     path traversal, branch-ref abuse, or argument injection into git.
#   - Git invocations use `--` separators where supported.
#   - .team/ is preferred linked (Unix) or copied with symlinks preserved
#     (Windows fallback) — `cp -r` would otherwise dereference symlinks
#     and could exfiltrate files outside .team/.

set -euo pipefail

if [ $# -lt 2 ]; then
  printf 'Usage: %s <agent-name> <task-id>\n' "$0" >&2
  printf 'Example: %s executor add-auth\n' "$0" >&2
  exit 1
fi

AGENT_NAME="$1"
TASK_ID="$2"

# Validate identifiers — reject anything that could traverse the filesystem,
# inject git flags, or build a malformed branch name.
validate_id() {
  local val="$1" name="$2"
  if ! [[ "$val" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    printf 'Error: %s must match ^[a-z0-9][a-z0-9-]*$ (got: %q)\n' "$name" "$val" >&2
    exit 1
  fi
}
validate_id "$AGENT_NAME" "agent-name"
validate_id "$TASK_ID"    "task-id"

WORKTREE_DIR="${WORKTREE_DIR:-.worktrees}"
BRANCH_NAME="agent/${AGENT_NAME}/${TASK_ID}"
WORKTREE_PATH="${WORKTREE_DIR}/agent-${AGENT_NAME}-${TASK_ID}"

# Defence in depth: also let git verify the branch name is well-formed.
if ! git check-ref-format --branch "$BRANCH_NAME" >/dev/null 2>&1; then
  printf 'Error: invalid branch name: %s\n' "$BRANCH_NAME" >&2
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

# Validate MAIN_BRANCH too — it can come from env.
if ! git check-ref-format --branch "$MAIN_BRANCH" >/dev/null 2>&1; then
  printf 'Error: invalid main branch: %s\n' "$MAIN_BRANCH" >&2
  exit 1
fi

printf 'Creating worktree for agent: %s\n' "$AGENT_NAME"
printf '  Branch: %s\n' "$BRANCH_NAME"
printf '  Path:   %s\n' "$WORKTREE_PATH"
printf '  Base:   %s\n' "$MAIN_BRANCH"

# Create worktree directory
mkdir -p -- "$WORKTREE_DIR"

# Check if branch already exists
if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}" 2>/dev/null; then
  printf '  Branch %s already exists, reusing...\n' "$BRANCH_NAME"
  if [ -d "$WORKTREE_PATH" ]; then
    printf '  Worktree already exists at %s\n' "$WORKTREE_PATH"
  else
    git worktree add -- "$WORKTREE_PATH" "$BRANCH_NAME"
  fi
else
  # Create new worktree with new branch from main
  git worktree add -b "$BRANCH_NAME" -- "$WORKTREE_PATH" "$MAIN_BRANCH"
fi

# Make .team/ available inside the worktree.
#
# We prefer a symlink so the worktree shares state with the main checkout
# (single source of truth, no drift). On Windows we copy with -P to keep
# any symlinks inside .team/ as symlinks (rather than dereferencing them
# and copying their targets, which could pull in files from outside .team/).
if [ -d ".team" ] && [ ! -e "${WORKTREE_PATH}/.team" ]; then
  if [ "${OS:-}" = "Windows_NT" ]; then
    cp -rP .team "${WORKTREE_PATH}/.team"
    printf '  Copied .team/ to worktree (Windows fallback)\n'
  else
    ln -s "$(cd .team && pwd)" "${WORKTREE_PATH}/.team"
    printf '  Linked .team/ into worktree\n'
  fi
fi

# Add worktrees dir to gitignore if needed
if [ -f ".gitignore" ]; then
  if ! grep -qxF ".worktrees/" ".gitignore"; then
    printf '\n.worktrees/\n' >> ".gitignore"
  fi
fi

printf '\nWorktree ready. Agent can work in: %s\n' "$WORKTREE_PATH"
printf 'To switch: cd %s\n' "$WORKTREE_PATH"

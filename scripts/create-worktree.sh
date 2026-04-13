#!/usr/bin/env bash
# Create a git worktree for an agent.
# Usage: create-worktree.sh <agent-name> <task-id>
# Example: create-worktree.sh executor add-auth
#
# Creates: .worktrees/agent-<name>-<task-id>/
# Branch:  agent/<name>/<task-id>

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <agent-name> <task-id>"
  echo "Example: $0 executor add-auth"
  exit 1
fi

AGENT_NAME="$1"
TASK_ID="$2"
WORKTREE_DIR="${WORKTREE_DIR:-.worktrees}"
BRANCH_NAME="agent/${AGENT_NAME}/${TASK_ID}"
WORKTREE_PATH="${WORKTREE_DIR}/agent-${AGENT_NAME}-${TASK_ID}"

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

echo "Creating worktree for agent: ${AGENT_NAME}"
echo "  Branch: ${BRANCH_NAME}"
echo "  Path:   ${WORKTREE_PATH}"
echo "  Base:   ${MAIN_BRANCH}"

# Create worktree directory
mkdir -p "${WORKTREE_DIR}"

# Check if branch already exists
if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}" 2>/dev/null; then
  echo "  Branch ${BRANCH_NAME} already exists, reusing..."
  if [ -d "${WORKTREE_PATH}" ]; then
    echo "  Worktree already exists at ${WORKTREE_PATH}"
  else
    git worktree add "${WORKTREE_PATH}" "${BRANCH_NAME}"
  fi
else
  # Create new worktree with new branch from main
  git worktree add -b "${BRANCH_NAME}" "${WORKTREE_PATH}" "${MAIN_BRANCH}"
fi

# Copy .team/ to worktree so agent has access to communication files
if [ -d ".team" ] && [ ! -d "${WORKTREE_PATH}/.team" ]; then
  cp -r .team "${WORKTREE_PATH}/.team"
  echo "  Copied .team/ to worktree"
fi

# Add worktrees dir to gitignore if needed
if [ -f ".gitignore" ]; then
  if ! grep -q "^\.worktrees/" ".gitignore" 2>/dev/null; then
    echo ".worktrees/" >> ".gitignore"
  fi
fi

echo ""
echo "Worktree ready. Agent can work in: ${WORKTREE_PATH}"
echo "To switch: cd ${WORKTREE_PATH}"

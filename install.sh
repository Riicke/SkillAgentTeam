#!/usr/bin/env bash
# Install Agent Team skill into the current project.
#
# Usage (from your project root):
#   bash install.sh                  Install both (Claude Code + Codex)
#   bash install.sh --claude         Install only Claude Code
#   bash install.sh --codex          Install only Codex CLI
#   bash install.sh --both           Install both (same as no flag)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
MODE="${1:-both}"

# Normalize flags
case "$MODE" in
  --claude|claude)  MODE="claude" ;;
  --codex|codex)    MODE="codex" ;;
  --both|both|"")   MODE="both" ;;
  --help|-h)
    echo "Usage: bash install.sh [--claude | --codex | --both]"
    echo ""
    echo "  --claude   Install only for Claude Code (.claude/skills/)"
    echo "  --codex    Install only for Codex CLI (.codex-agents/ + AGENTS.md)"
    echo "  --both     Install both (default)"
    exit 0
    ;;
  *)
    echo "Unknown option: $MODE"
    echo "Usage: bash install.sh [--claude | --codex | --both]"
    exit 1
    ;;
esac

echo ""
echo "  Agent Team Installer"
echo "  ====================="
echo "  Source:  $SCRIPT_DIR"
echo "  Target:  $PROJECT_DIR"
echo "  Mode:    $MODE"
echo ""

# --- Claude Code ---
if [ "$MODE" = "claude" ] || [ "$MODE" = "both" ]; then
  mkdir -p "${PROJECT_DIR}/.claude/skills"
  cp -r "${SCRIPT_DIR}" "${PROJECT_DIR}/.claude/skills/agent-team"
  # Remove git artifacts and non-skill files from the installed copy
  rm -rf "${PROJECT_DIR}/.claude/skills/agent-team/.git"
  rm -f "${PROJECT_DIR}/.claude/skills/agent-team/.gitignore"
  rm -f "${PROJECT_DIR}/.claude/skills/agent-team/install.sh"
  rm -f "${PROJECT_DIR}/.claude/skills/agent-team/README.md"
  rm -f "${PROJECT_DIR}/.claude/skills/agent-team/LICENSE"
  echo "  [ok] Claude Code skill  -> .claude/skills/agent-team/"
fi

# --- Codex CLI ---
if [ "$MODE" = "codex" ] || [ "$MODE" = "both" ]; then
  cp -r "${SCRIPT_DIR}/agents" "${PROJECT_DIR}/.codex-agents"
  echo "  [ok] Codex CLI agents   -> .codex-agents/"

  if [ ! -f "${PROJECT_DIR}/AGENTS.md" ]; then
    cp "${SCRIPT_DIR}/AGENTS.md" "${PROJECT_DIR}/AGENTS.md"
    echo "  [ok] AGENTS.md created"
  else
    echo "  [skip] AGENTS.md already exists"
  fi

  # Copy pipeline script for easy access
  mkdir -p "${PROJECT_DIR}/scripts"
  cp "${SCRIPT_DIR}/scripts/run-codex-pipeline.sh" "${PROJECT_DIR}/scripts/run-codex-pipeline.sh"
  echo "  [ok] Pipeline script    -> scripts/run-codex-pipeline.sh"
fi

# --- Initialize .team/ workspace (always) ---
# Find init script in whichever location was installed
INIT_SCRIPT=""
if [ -f "${PROJECT_DIR}/.claude/skills/agent-team/scripts/init-team.sh" ]; then
  INIT_SCRIPT="${PROJECT_DIR}/.claude/skills/agent-team/scripts/init-team.sh"
elif [ -f "${SCRIPT_DIR}/scripts/init-team.sh" ]; then
  INIT_SCRIPT="${SCRIPT_DIR}/scripts/init-team.sh"
fi

if [ -n "$INIT_SCRIPT" ]; then
  bash "$INIT_SCRIPT"
fi

echo ""
echo "  Done!"
echo ""
if [ "$MODE" = "claude" ] || [ "$MODE" = "both" ]; then
  echo "  Claude Code:  just say \"Equipe, ...\" in your project"
fi
if [ "$MODE" = "codex" ] || [ "$MODE" = "both" ]; then
  echo "  Codex CLI:    bash scripts/run-codex-pipeline.sh feature \"your task\""
fi
echo "  Obsidian:     open .team/vault/ as a vault"
echo ""

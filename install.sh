#!/usr/bin/env bash
# Install Agent Team skill into the current project.
#
# Usage (from your project root):
#   bash install.sh                  Install both (Claude Code + Codex)
#   bash install.sh --claude         Install only Claude Code
#   bash install.sh --codex          Install only Codex CLI
#   bash install.sh --both           Install both (same as no flag)
#
# Environment:
#   FORCE=1   Overwrite an existing installation. Without it, the script
#             aborts when target paths already exist to protect local edits.
#
# Security notes:
#   - Refuses to overwrite existing installations unless FORCE=1.
#   - Copies only the skill payload (SKILL.md, agents/, references/, scripts/),
#     not the entire repo (no `.git/` round-trip).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
MODE="${1:-both}"
FORCE="${FORCE:-0}"

# Normalize flags
case "$MODE" in
  --claude|claude)  MODE="claude" ;;
  --codex|codex)    MODE="codex" ;;
  --both|both|"")   MODE="both" ;;
  --help|-h)
    cat <<'HELP'
Usage: bash install.sh [--claude | --codex | --both]

  --claude   Install only for Claude Code (.claude/skills/)
  --codex    Install only for Codex CLI (.codex-agents/ + AGENTS.md)
  --both     Install both (default)

Environment:
  FORCE=1    Overwrite an existing installation.
HELP
    exit 0
    ;;
  *)
    printf 'Unknown option: %q\n' "$MODE" >&2
    printf 'Usage: bash install.sh [--claude | --codex | --both]\n' >&2
    exit 1
    ;;
esac

printf '\n  Agent Team Installer\n'
printf '  =====================\n'
printf '  Source:  %s\n' "$SCRIPT_DIR"
printf '  Target:  %s\n' "$PROJECT_DIR"
printf '  Mode:    %s\n\n' "$MODE"

# Helper: copy the skill payload to the destination, refusing to overwrite
# unless FORCE=1. Copies only known-good paths instead of the whole repo
# followed by `rm` of unwanted files (which silently overrides local edits).
install_claude() {
  local dest="${PROJECT_DIR}/.claude/skills/agent-team"
  if [ -d "$dest" ] && [ "$FORCE" != "1" ]; then
    printf '  Error: %s already exists. Re-run with FORCE=1 to overwrite.\n' "$dest" >&2
    exit 1
  fi
  mkdir -p "$dest"

  # Copy specific subtrees, not the whole repo.
  cp "${SCRIPT_DIR}/SKILL.md"    "${dest}/SKILL.md"
  cp "${SCRIPT_DIR}/AGENTS.md"   "${dest}/AGENTS.md"
  cp "${SCRIPT_DIR}/VERSION"     "${dest}/VERSION"
  cp "${SCRIPT_DIR}/TUTORIAL.md" "${dest}/TUTORIAL.md" 2>/dev/null || true
  cp -r "${SCRIPT_DIR}/agents"     "${dest}/agents"
  cp -r "${SCRIPT_DIR}/references" "${dest}/references"
  cp -r "${SCRIPT_DIR}/scripts"    "${dest}/scripts"

  printf '  [ok] Claude Code skill  -> .claude/skills/agent-team/\n'
}

install_codex() {
  local dest="${PROJECT_DIR}/.codex-agents"
  if [ -d "$dest" ] && [ "$FORCE" != "1" ]; then
    printf '  Error: %s already exists. Re-run with FORCE=1 to overwrite.\n' "$dest" >&2
    exit 1
  fi
  cp -r "${SCRIPT_DIR}/agents" "$dest"
  printf '  [ok] Codex CLI agents   -> .codex-agents/\n'

  if [ ! -f "${PROJECT_DIR}/AGENTS.md" ]; then
    cp "${SCRIPT_DIR}/AGENTS.md" "${PROJECT_DIR}/AGENTS.md"
    printf '  [ok] AGENTS.md created\n'
  else
    printf '  [skip] AGENTS.md already exists\n'
  fi

  # Copy pipeline script — but never overwrite a customized one without FORCE.
  local pipeline_dest="${PROJECT_DIR}/scripts/run-codex-pipeline.sh"
  if [ -f "$pipeline_dest" ] && [ "$FORCE" != "1" ]; then
    printf '  [skip] %s already exists (FORCE=1 to overwrite)\n' "scripts/run-codex-pipeline.sh"
  else
    mkdir -p "${PROJECT_DIR}/scripts"
    cp "${SCRIPT_DIR}/scripts/run-codex-pipeline.sh" "$pipeline_dest"
    printf '  [ok] Pipeline script    -> scripts/run-codex-pipeline.sh\n'
  fi
}

# --- Claude Code ---
if [ "$MODE" = "claude" ] || [ "$MODE" = "both" ]; then
  install_claude
fi

# --- Codex CLI ---
if [ "$MODE" = "codex" ] || [ "$MODE" = "both" ]; then
  install_codex
fi

# --- Initialize .team/ workspace (always) ---
INIT_SCRIPT=""
if [ -f "${PROJECT_DIR}/.claude/skills/agent-team/scripts/init-team.sh" ]; then
  INIT_SCRIPT="${PROJECT_DIR}/.claude/skills/agent-team/scripts/init-team.sh"
elif [ -f "${SCRIPT_DIR}/scripts/init-team.sh" ]; then
  INIT_SCRIPT="${SCRIPT_DIR}/scripts/init-team.sh"
fi

if [ -n "$INIT_SCRIPT" ]; then
  bash "$INIT_SCRIPT"
fi

printf '\n  Done!\n\n'
if [ "$MODE" = "claude" ] || [ "$MODE" = "both" ]; then
  printf '  Claude Code:  just say "Team, ..." in your project\n'
fi
if [ "$MODE" = "codex" ] || [ "$MODE" = "both" ]; then
  printf '  Codex CLI:    bash scripts/run-codex-pipeline.sh feature "your task"\n'
fi
printf '  Obsidian:     open .team/vault/ as a vault\n\n'

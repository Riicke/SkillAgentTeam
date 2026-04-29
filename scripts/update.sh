#!/usr/bin/env bash
# Interactively update the Agent Team skill to the latest released version.
#
# Runs check-updates.sh first; if there is something to update, shows the
# changelog URL, asks for confirmation, and re-runs install.sh with FORCE=1.
#
# Usage:
#   update.sh             Check, prompt, apply
#   update.sh --yes       Skip the y/N prompt (still respects FORCE=1)
#   update.sh --check     Run the check only, do not apply
#
# Exit codes:
#   0 = up to date, or update applied successfully
#   1 = update available but the user declined
#   2 = check or apply failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_OWNER="Riicke"
REPO_NAME="SkillAgentTeam"

ASSUME_YES=0
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)   ASSUME_YES=1 ;;
    --check)    CHECK_ONLY=1 ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

# Run the check (force a fresh API call so the user gets current state).
status=0
"${SCRIPT_DIR}/check-updates.sh" --force || status=$?

case "$status" in
  0)
    printf '\nNothing to do. You are on the latest version.\n'
    exit 0
    ;;
  1) ;;  # update available, continue
  *)
    printf 'Update check failed (exit %d). Try again later.\n' "$status" >&2
    exit 2
    ;;
esac

if [ "$CHECK_ONLY" = "1" ]; then
  exit 1
fi

printf '\nThis will overwrite the installed skill with the latest release.\n'
printf 'Local edits to agent prompts under .claude/skills/agent-team/\n'
printf 'or .codex-agents/ will be lost. Copy them out first if needed.\n\n'
printf 'Release notes: https://github.com/%s/%s/releases\n\n' "$REPO_OWNER" "$REPO_NAME"

if [ "$ASSUME_YES" != "1" ]; then
  printf 'Update Agent Team now? [y/N] '
  read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES) ;;
    *)
      printf 'Cancelled.\n'
      exit 1
      ;;
  esac
fi

# Need git + a writable temp dir.
if ! command -v git >/dev/null 2>&1; then
  printf 'Error: git is required to update.\n' >&2
  exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

printf '\nFetching latest release...\n'
if ! git clone --depth 1 "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" "$TMP" >/dev/null 2>&1; then
  printf 'Error: failed to clone the repository.\n' >&2
  exit 2
fi

if [ ! -f "${TMP}/install.sh" ]; then
  printf 'Error: install.sh missing in fetched repo.\n' >&2
  exit 2
fi

printf 'Re-running install.sh with FORCE=1...\n\n'
FORCE=1 bash "${TMP}/install.sh"

# Bust the cache so the next check reflects the new version immediately.
rm -f -- "${TEAM_DIR:-.team}/.last-update-check" 2>/dev/null || true

printf '\nUpdate complete.\n'

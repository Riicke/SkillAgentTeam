#!/usr/bin/env bash
# Check whether a newer version of the Agent Team skill is available.
#
# Non-interactive. Caches the GitHub API response for 24 hours so the
# rate limit isn't hit on every Orchestrator invocation. Fails silently
# (exit 0, no stderr noise) when curl is missing or there is no network,
# so it never blocks the user.
#
# Usage:
#   check-updates.sh                Print status and exit
#   check-updates.sh --force        Skip cache, always hit the API
#   check-updates.sh --quiet        Print nothing when up to date
#
# Exit codes:
#   0 = up to date OR check skipped (no network / no curl)
#   1 = update available
#   2 = local environment problem (e.g., missing VERSION file)

set -euo pipefail

REPO_OWNER="Riicke"
REPO_NAME="SkillAgentTeam"
GITHUB_RELEASES_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
GITHUB_TAGS_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/tags"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="${SKILL_DIR}/VERSION"
TEAM_DIR="${TEAM_DIR:-.team}"
CACHE_FILE="${TEAM_DIR}/.last-update-check"
CACHE_TTL_SECONDS=$((24 * 60 * 60))

FORCE=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --quiet) QUIET=1 ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

# Honor an opt-out: SKIP_UPDATE_CHECK=1 means "do nothing".
if [ "${SKIP_UPDATE_CHECK:-0}" = "1" ]; then
  exit 0
fi

say() {
  [ "$QUIET" = "1" ] && return 0
  printf '%s\n' "$*"
}

# --- Read local version ----------------------------------------------------
if [ ! -f "$VERSION_FILE" ]; then
  printf 'check-updates: VERSION file not found at %s\n' "$VERSION_FILE" >&2
  exit 2
fi
LOCAL_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")

# --- Honor cache unless --force -------------------------------------------
file_mtime() {
  # GNU stat first (Linux, Git Bash on Windows), BSD stat fallback (macOS).
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

if [ "$FORCE" != "1" ] && [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(file_mtime "$CACHE_FILE") ))
  if [ "$cache_age" -ge 0 ] && [ "$cache_age" -lt "$CACHE_TTL_SECONDS" ]; then
    cached=$(cat "$CACHE_FILE" 2>/dev/null || echo "")
    case "$cached" in
      "up-to-date "*)
        say "Agent Team is up to date (v${LOCAL_VERSION}, cached)."
        exit 0
        ;;
      "update-available "*)
        latest="${cached#update-available }"
        printf 'Agent Team update available: v%s -> v%s\n' "$LOCAL_VERSION" "$latest"
        printf '  Release notes: https://github.com/%s/%s/releases\n' "$REPO_OWNER" "$REPO_NAME"
        printf '  Apply with:    bash %s/update.sh\n' "$SCRIPT_DIR"
        exit 1
        ;;
    esac
  fi
fi

# --- Need curl + network --------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
  say "check-updates: curl not found, skipping."
  exit 0
fi

# Fetch the latest released version. If no GitHub release exists yet,
# fall back to the most recent tag.
extract_version() {
  # Match the first "tag_name" or "name" field and strip a leading "v".
  grep -m1 -E '"(tag_name|name)"' \
    | sed -E 's/.*"(tag_name|name)": *"v?([^"]+)".*/\2/'
}

LATEST=$(curl -fsSL --max-time 5 "$GITHUB_RELEASES_API" 2>/dev/null | extract_version || true)
if [ -z "${LATEST:-}" ]; then
  LATEST=$(curl -fsSL --max-time 5 "$GITHUB_TAGS_API" 2>/dev/null | extract_version || true)
fi

if [ -z "${LATEST:-}" ]; then
  # No network, GitHub down, or no release/tag — fail silently so the
  # Orchestrator can keep working.
  say "check-updates: could not reach GitHub, skipping."
  exit 0
fi

# --- Compare and cache ----------------------------------------------------
write_cache() {
  mkdir -p "$TEAM_DIR" 2>/dev/null || return 0
  printf '%s\n' "$1" > "$CACHE_FILE" 2>/dev/null || true
}

# Use sort -V (version sort) when available; fall back to literal compare.
version_gt() {
  # Returns 0 when $1 > $2.
  if [ "$1" = "$2" ]; then return 1; fi
  if printf '%s\n%s\n' "$1" "$2" | sort -V >/dev/null 2>&1; then
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
  else
    [ "$1" \> "$2" ]
  fi
}

if [ "$LATEST" = "$LOCAL_VERSION" ]; then
  write_cache "up-to-date $LATEST"
  say "Agent Team is up to date (v${LOCAL_VERSION})."
  exit 0
fi

if version_gt "$LATEST" "$LOCAL_VERSION"; then
  write_cache "update-available $LATEST"
  printf 'Agent Team update available: v%s -> v%s\n' "$LOCAL_VERSION" "$LATEST"
  printf '  Release notes: https://github.com/%s/%s/releases\n' "$REPO_OWNER" "$REPO_NAME"
  printf '  Apply with:    bash %s/update.sh\n' "$SCRIPT_DIR"
  exit 1
fi

# Local is somehow ahead of remote (development checkout).
write_cache "up-to-date $LATEST"
say "Agent Team is at v${LOCAL_VERSION} (latest released: v${LATEST})."
exit 0

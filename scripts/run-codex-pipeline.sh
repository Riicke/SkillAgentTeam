#!/usr/bin/env bash
# Run the agent-team pipeline using Codex CLI.
#
# Usage:
#   ./run-codex-pipeline.sh "feature"  "Add notification system"
#   ./run-codex-pipeline.sh "bugfix"   "Login button does not respond"
#   ./run-codex-pipeline.sh "security" "Review runtime security"
#   ./run-codex-pipeline.sh "refactor" "Split BigComponent.tsx"
#   ./run-codex-pipeline.sh "plan"     "Plan a plugin system"
#   ./run-codex-pipeline.sh "agent"    "security-agent" "Audit the API"
#
# Requires: codex CLI installed and authenticated.
#
# Security notes:
#   - Task descriptions are passed to codex via STDIN, never via shell-expanded
#     argv, to prevent command injection from the input string.
#   - Agent names are validated against a strict allowlist.
#   - Task type is validated against a fixed set of subcommands.

set -euo pipefail

TASK_TYPE="${1:-}"
TASK_DESC="${2:-}"
AGENT_NAME="${3:-}"

if [ -z "$TASK_TYPE" ] || [ -z "$TASK_DESC" ]; then
  cat <<'USAGE'
Usage:
  $0 feature   "description"            Full pipeline
  $0 bugfix    "description"            Executor + QA
  $0 security  "description"            Security Agent
  $0 refactor  "description"            Architect + Executor + QA
  $0 plan      "description"            Planner + Architect
  $0 agent     "agent-name" "task"      Single agent

Agents: planner, architect, ux-agent, executor, qa-agent,
        security-agent, infra-agent, compliance-agent, context-steward
USAGE
  exit 1
fi

# Validate task type against allowlist (defence in depth — the case statement
# below would also reject unknown values).
case "$TASK_TYPE" in
  feature|bugfix|security|refactor|plan|agent) ;;
  *)
    printf 'Error: unknown task type. Allowed: feature, bugfix, security, refactor, plan, agent\n' >&2
    exit 1
    ;;
esac

AGENTS_DIR=".codex-agents"
TEAM_DIR=".team"

# Verify setup
if [ ! -d "$AGENTS_DIR" ]; then
  printf 'Error: %s not found. Run:\n' "$AGENTS_DIR" >&2
  printf '  cp -r .claude/skills/agent-team/agents %s\n' "$AGENTS_DIR" >&2
  exit 1
fi

if [ ! -d "$TEAM_DIR" ]; then
  printf 'Error: %s not found. Run:\n' "$TEAM_DIR" >&2
  printf '  bash .claude/skills/agent-team/scripts/init-team.sh\n' >&2
  exit 1
fi

# Allowlist of valid agent role names. Used both for the explicit "agent"
# subcommand and as defence in depth inside run_agent.
is_valid_agent() {
  case "$1" in
    planner|architect|ux-agent|executor|qa-agent|security-agent|infra-agent|compliance-agent|context-steward)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# run_agent <role> <context>
#
# Builds the codex prompt on STDIN so the task description and context can
# never be re-evaluated by the shell. Falls back to a temp file when codex
# does not read from STDIN.
run_agent() {
  local role="$1"
  local context="$2"

  if ! is_valid_agent "$role"; then
    printf 'Error: refusing to run unknown agent: %s\n' "$role" >&2
    exit 1
  fi

  # Map "<role>-agent" to its directory under .team/agents/<role-dir>/
  # using parameter expansion (no subshell, no shell injection surface).
  local role_dir="${role%-agent}"

  printf '\n==========================================\n'
  printf '  Running: %s\n' "$role"
  printf '==========================================\n\n'

  local prompt_file
  prompt_file="$(mktemp)"

  # Layer EXIT on top of RETURN so the temp file is removed even if codex
  # exits non-zero and `set -e` aborts the script before the function returns.
  # shellcheck disable=SC2064
  trap "rm -f -- '$prompt_file'" EXIT RETURN

  {
    printf 'Read %s/%s.md and follow its protocol exactly.\n\n' "$AGENTS_DIR" "$role"
    printf 'Task: %s\n\n' "$TASK_DESC"
    printf 'Context: %s\n\n' "$context"
    printf 'Important:\n'
    printf -- '- Write outputs to %s/agents/%s/\n' "$TEAM_DIR" "$role_dir"
    printf -- '- Create Obsidian vault files in %s/vault/\n' "$TEAM_DIR"
    printf -- '- Update %s/board.md with your status\n' "$TEAM_DIR"
    printf -- '- Read prior agent outputs in %s/agents/ before starting\n' "$TEAM_DIR"
  } > "$prompt_file"

  # Pipe the prompt through STDIN. codex's argv stays free of user content.
  codex < "$prompt_file"

  rm -f -- "$prompt_file"
  trap - EXIT RETURN
}

case "$TASK_TYPE" in
  feature)
    printf 'Pipeline: FEATURE (full)\n'
    printf 'Task: %s\n\n' "$TASK_DESC"

    # Phase 1: Planning
    printf '=== PHASE 1: PLANNING ===\n'
    run_agent "planner" "This is a new feature. Define requirements and acceptance criteria."
    run_agent "architect" "This is a new feature. Read ${TEAM_DIR}/agents/planner/requirements.md for requirements. Define technical design."

    # Phase 2: Design
    printf '=== PHASE 2: DESIGN ===\n'
    run_agent "ux-agent" "Read ${TEAM_DIR}/agents/planner/ and ${TEAM_DIR}/agents/architect/ for context. Define UX spec."

    # Phase 3: Implementation
    printf '=== PHASE 3: IMPLEMENTATION ===\n'
    run_agent "executor" "Read ALL prior outputs in ${TEAM_DIR}/agents/planner/, ${TEAM_DIR}/agents/architect/, ${TEAM_DIR}/agents/ux/. Implement the feature."

    # Phase 4: Validation
    printf '=== PHASE 4: VALIDATION ===\n'
    run_agent "qa-agent" "Read ${TEAM_DIR}/agents/planner/requirements.md for what to test. Read ${TEAM_DIR}/agents/executor/ for what was built. Test and validate."

    # Phase 5: Documentation
    printf '=== PHASE 5: DOCUMENTATION ===\n'
    run_agent "context-steward" "Read ALL agent outputs in ${TEAM_DIR}/agents/. Update vault MOC pages and project context."

    printf '\nPipeline complete. Check %s/vault/ for Obsidian docs.\n' "$TEAM_DIR"
    ;;

  bugfix)
    printf 'Pipeline: BUG FIX (short)\n'
    printf 'Task: %s\n' "$TASK_DESC"

    run_agent "executor" "This is a bug fix. Investigate the code, diagnose the issue, and propose a fix."
    run_agent "qa-agent" "Read ${TEAM_DIR}/agents/executor/ for the diagnosis. Define verification steps for the fix."

    printf '\nPipeline complete.\n'
    ;;

  security)
    printf 'Pipeline: SECURITY REVIEW\n'
    printf 'Task: %s\n' "$TASK_DESC"

    run_agent "security-agent" "Do a full security review. Check for OWASP Top 10, hardcoded secrets, injection risks, auth issues."

    printf '\nReview complete. Check %s/agents/security/ and %s/vault/\n' "$TEAM_DIR" "$TEAM_DIR"
    ;;

  refactor)
    printf 'Pipeline: REFACTOR\n'
    printf 'Task: %s\n' "$TASK_DESC"

    run_agent "architect" "This is a refactoring task. Define how to restructure the code."
    run_agent "executor" "Read ${TEAM_DIR}/agents/architect/design.md. Implement the refactoring."
    run_agent "qa-agent" "Read ${TEAM_DIR}/agents/executor/. Verify no regressions."

    printf '\nPipeline complete.\n'
    ;;

  plan)
    printf 'Pipeline: PLANNING ONLY\n'
    printf 'Task: %s\n' "$TASK_DESC"

    run_agent "planner" "Define requirements and acceptance criteria. DO NOT implement."
    run_agent "architect" "Read ${TEAM_DIR}/agents/planner/requirements.md. Define technical design. DO NOT implement."

    printf '\nPlanning complete. Review %s/agents/planner/ and %s/agents/architect/\n' "$TEAM_DIR" "$TEAM_DIR"
    ;;

  agent)
    # Single agent mode: argv was (agent, <agent-name>, <task>)
    # so positional 2 is the agent name, positional 3 is the task.
    if [ -z "$AGENT_NAME" ]; then
      printf 'Usage: %s agent <agent-name> "task description"\n' "$0" >&2
      exit 1
    fi
    SINGLE_AGENT="$TASK_DESC"
    TASK_DESC="$AGENT_NAME"

    if ! is_valid_agent "$SINGLE_AGENT"; then
      printf 'Error: unknown agent: %s\n' "$SINGLE_AGENT" >&2
      printf 'Available: planner, architect, ux-agent, executor, qa-agent, security-agent, infra-agent, compliance-agent, context-steward\n' >&2
      exit 1
    fi

    if [ ! -f "${AGENTS_DIR}/${SINGLE_AGENT}.md" ]; then
      printf 'Error: agent file not found: %s/%s.md\n' "$AGENTS_DIR" "$SINGLE_AGENT" >&2
      exit 1
    fi

    printf 'Pipeline: SINGLE AGENT (%s)\n' "$SINGLE_AGENT"
    printf 'Task: %s\n' "$TASK_DESC"

    run_agent "$SINGLE_AGENT" "You were called directly by the user. Focus on your specific role."

    printf '\nDone.\n'
    ;;
esac

#!/usr/bin/env bash
# Run the agent-team pipeline using Codex CLI.
#
# Usage:
#   ./run-codex-pipeline.sh "feature" "Adicionar sistema de notificações"
#   ./run-codex-pipeline.sh "bugfix"  "O botão de fala não responde"
#   ./run-codex-pipeline.sh "security" "Revisar segurança do runtime"
#   ./run-codex-pipeline.sh "plan"    "Planejar sistema de plugins"
#   ./run-codex-pipeline.sh "agent"   "security" "Revisar o runtime"
#
# Requires: codex CLI installed and authenticated

set -euo pipefail

TASK_TYPE="${1:-}"
TASK_DESC="${2:-}"
AGENT_NAME="${3:-}"

if [ -z "$TASK_TYPE" ] || [ -z "$TASK_DESC" ]; then
  echo "Usage:"
  echo "  $0 feature  \"description\"          Full pipeline"
  echo "  $0 bugfix   \"description\"          Executor + QA"
  echo "  $0 security \"description\"          Security Agent"
  echo "  $0 refactor \"description\"          Architect + Executor + QA"
  echo "  $0 plan     \"description\"          Planner + Architect"
  echo "  $0 agent    \"agent-name\" \"task\"    Single agent"
  echo ""
  echo "Agents: planner, architect, ux-agent, executor, qa-agent,"
  echo "        security-agent, infra-agent, compliance-agent, context-steward"
  exit 1
fi

AGENTS_DIR=".codex-agents"
TEAM_DIR=".team"

# Verify setup
if [ ! -d "$AGENTS_DIR" ]; then
  echo "Error: $AGENTS_DIR not found. Run:"
  echo "  cp -r .claude/skills/agent-team/agents .codex-agents"
  exit 1
fi

if [ ! -d "$TEAM_DIR" ]; then
  echo "Error: $TEAM_DIR not found. Run:"
  echo "  bash .claude/skills/agent-team/scripts/init-team.sh"
  exit 1
fi

run_agent() {
  local role="$1"
  local context="$2"
  echo ""
  echo "=========================================="
  echo "  Running: $role"
  echo "=========================================="
  echo ""
  codex "Read ${AGENTS_DIR}/${role}.md and follow its protocol exactly.

Task: ${TASK_DESC}

Context: ${context}

Important:
- Write outputs to ${TEAM_DIR}/agents/$(echo $role | sed 's/-agent//')/
- Create Obsidian vault files in ${TEAM_DIR}/vault/
- Update ${TEAM_DIR}/board.md with your status
- Read prior agent outputs in ${TEAM_DIR}/agents/ before starting"
}

case "$TASK_TYPE" in
  feature)
    echo "Pipeline: FEATURE (full)"
    echo "Task: $TASK_DESC"
    echo ""

    # Phase 1: Planning
    echo "═══ PHASE 1: PLANNING ═══"
    run_agent "planner" "This is a new feature. Define requirements and acceptance criteria."
    run_agent "architect" "This is a new feature. Read ${TEAM_DIR}/agents/planner/requirements.md for requirements. Define technical design."

    # Phase 2: Design
    echo "═══ PHASE 2: DESIGN ═══"
    run_agent "ux-agent" "Read ${TEAM_DIR}/agents/planner/ and ${TEAM_DIR}/agents/architect/ for context. Define UX spec."

    # Phase 3: Implementation
    echo "═══ PHASE 3: IMPLEMENTATION ═══"
    run_agent "executor" "Read ALL prior outputs in ${TEAM_DIR}/agents/planner/, ${TEAM_DIR}/agents/architect/, ${TEAM_DIR}/agents/ux/. Implement the feature."

    # Phase 4: Validation
    echo "═══ PHASE 4: VALIDATION ═══"
    run_agent "qa-agent" "Read ${TEAM_DIR}/agents/planner/requirements.md for what to test. Read ${TEAM_DIR}/agents/executor/ for what was built. Test and validate."

    # Phase 5: Documentation
    echo "═══ PHASE 5: DOCUMENTATION ═══"
    run_agent "context-steward" "Read ALL agent outputs in ${TEAM_DIR}/agents/. Update vault MOC pages and project context."

    echo ""
    echo "Pipeline complete. Check ${TEAM_DIR}/vault/ for Obsidian docs."
    ;;

  bugfix)
    echo "Pipeline: BUG FIX (short)"
    echo "Task: $TASK_DESC"

    run_agent "executor" "This is a bug fix. Investigate the code, diagnose the issue, and propose a fix."
    run_agent "qa-agent" "Read ${TEAM_DIR}/agents/executor/ for the diagnosis. Define verification steps for the fix."

    echo ""
    echo "Pipeline complete."
    ;;

  security)
    echo "Pipeline: SECURITY REVIEW"
    echo "Task: $TASK_DESC"

    run_agent "security-agent" "Do a full security review. Check for OWASP Top 10, hardcoded secrets, injection risks, auth issues."

    echo ""
    echo "Review complete. Check ${TEAM_DIR}/agents/security/ and ${TEAM_DIR}/vault/"
    ;;

  refactor)
    echo "Pipeline: REFACTOR"
    echo "Task: $TASK_DESC"

    run_agent "architect" "This is a refactoring task. Define how to restructure the code."
    run_agent "executor" "Read ${TEAM_DIR}/agents/architect/design.md. Implement the refactoring."
    run_agent "qa-agent" "Read ${TEAM_DIR}/agents/executor/. Verify no regressions."

    echo ""
    echo "Pipeline complete."
    ;;

  plan)
    echo "Pipeline: PLANNING ONLY"
    echo "Task: $TASK_DESC"

    run_agent "planner" "Define requirements and acceptance criteria. DO NOT implement."
    run_agent "architect" "Read ${TEAM_DIR}/agents/planner/requirements.md. Define technical design. DO NOT implement."

    echo ""
    echo "Planning complete. Review ${TEAM_DIR}/agents/planner/ and ${TEAM_DIR}/agents/architect/"
    ;;

  agent)
    # Single agent mode: $TASK_DESC is actually the agent name, $AGENT_NAME is the task
    if [ -z "$AGENT_NAME" ]; then
      echo "Usage: $0 agent <agent-name> \"task description\""
      exit 1
    fi
    SINGLE_AGENT="$TASK_DESC"
    TASK_DESC="$AGENT_NAME"

    if [ ! -f "${AGENTS_DIR}/${SINGLE_AGENT}.md" ]; then
      echo "Error: agent '${SINGLE_AGENT}' not found in ${AGENTS_DIR}/"
      echo "Available: $(ls ${AGENTS_DIR}/ | sed 's/\.md$//' | tr '\n' ', ')"
      exit 1
    fi

    echo "Pipeline: SINGLE AGENT (${SINGLE_AGENT})"
    echo "Task: $TASK_DESC"

    run_agent "$SINGLE_AGENT" "You were called directly by the user. Focus on your specific role."

    echo ""
    echo "Done."
    ;;

  *)
    echo "Unknown task type: $TASK_TYPE"
    echo "Options: feature, bugfix, security, refactor, plan, agent"
    exit 1
    ;;
esac

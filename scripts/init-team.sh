#!/usr/bin/env bash
# Initialize the .team/ directory for agent communication.
# Safe to run multiple times — existing files are preserved.

set -euo pipefail

TEAM_DIR="${TEAM_DIR:-.team}"

echo "Initializing team workspace at ${TEAM_DIR}/"

# Create directory structure
dirs=(
  "${TEAM_DIR}/agents/planner"
  "${TEAM_DIR}/agents/architect"
  "${TEAM_DIR}/agents/ux"
  "${TEAM_DIR}/agents/executor"
  "${TEAM_DIR}/agents/qa"
  "${TEAM_DIR}/agents/security"
  "${TEAM_DIR}/agents/infra"
  "${TEAM_DIR}/agents/compliance"
  "${TEAM_DIR}/agents/context-steward"
  "${TEAM_DIR}/archive"
  "${TEAM_DIR}/vault"
)

for dir in "${dirs[@]}"; do
  mkdir -p "$dir"
done

# Create board.md if it doesn't exist
if [ ! -f "${TEAM_DIR}/board.md" ]; then
  cat > "${TEAM_DIR}/board.md" << 'EOF'
# Team Board

## Current Task
- **ID**: —
- **Description**: No active task
- **Status**: idle
- **Created**: —
- **Updated**: —

## Agent Status
| Agent      | Status  | Branch | Output | Notes |
|------------|---------|--------|--------|-------|
| planner    | idle    | —      | —      | —     |
| architect  | idle    | —      | —      | —     |
| ux         | idle    | —      | —      | —     |
| executor   | idle    | —      | —      | —     |
| qa         | idle    | —      | —      | —     |
| security   | idle    | —      | —      | —     |
| infra      | idle    | —      | —      | —     |
| compliance | idle    | —      | —      | —     |
| context-steward | idle | —   | —      | —     |

## History
EOF
  echo "  Created ${TEAM_DIR}/board.md"
fi

# Create context.md if it doesn't exist
if [ ! -f "${TEAM_DIR}/context.md" ]; then
  # Auto-detect project info
  PROJECT_NAME=$(basename "$(pwd)")

  cat > "${TEAM_DIR}/context.md" << EOF
# Project Context

## Overview
Project: ${PROJECT_NAME}

## Tech Stack
(To be filled by Context Steward after first task)

## Key Patterns
(To be filled by Context Steward)

## Recent Changes
(No changes yet)

## Glossary
| Term | Meaning |
|------|---------|

## Known Issues / Tech Debt
(None recorded yet)
EOF
  echo "  Created ${TEAM_DIR}/context.md"
fi

# Create decisions.md if it doesn't exist
if [ ! -f "${TEAM_DIR}/decisions.md" ]; then
  cat > "${TEAM_DIR}/decisions.md" << 'EOF'
# Decision Log

Append-only log of architectural and project decisions.
Never edit or delete existing entries.

---
EOF
  echo "  Created ${TEAM_DIR}/decisions.md"
fi

# Create Obsidian vault seed files if vault is empty
if [ ! -f "${TEAM_DIR}/vault/MOC-projects.md" ]; then
  # Sanitize: lowercase, collapse non-alnum runs to a single dash,
  # trim leading/trailing dashes, fall back to "project" if empty.
  PROJECT_SLUG=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  [ -z "$PROJECT_SLUG" ] && PROJECT_SLUG="project"

  cat > "${TEAM_DIR}/vault/MOC-projects.md" << EOF
---
type: moc
tags:
  - type/moc
  - nav/root
---

# Projects

## [[MOC-${PROJECT_SLUG}|${PROJECT_SLUG}]]
- Status: active
- Created: $(date +%Y-%m-%d)
EOF

  cat > "${TEAM_DIR}/vault/MOC-${PROJECT_SLUG}.md" << EOF
---
type: moc
project: ${PROJECT_SLUG}
tags:
  - type/moc
  - project/${PROJECT_SLUG}
---

# ${PROJECT_SLUG} — Map of Content

## Tasks
(No tasks yet)

## Architecture Decisions
(No ADRs yet)

## Bugs
(No bugs yet)

## Security
(No findings yet)

## Infrastructure
(No infra changes yet)
EOF

  cat > "${TEAM_DIR}/vault/MOC-agents.md" << 'EOF'
---
type: moc
tags:
  - type/moc
  - nav/agents
---

# Agent Activity

| Agent           | Log                                   | Last Active | Tasks |
|-----------------|---------------------------------------|-------------|-------|
| Planner         | [[LOG-planner\|Changelog]]            | —           | 0     |
| Architect       | [[LOG-architect\|Changelog]]          | —           | 0     |
| UX Agent        | [[LOG-ux\|Changelog]]                 | —           | 0     |
| Executor        | [[LOG-executor\|Changelog]]           | —           | 0     |
| QA Agent        | [[LOG-qa\|Changelog]]                 | —           | 0     |
| Security Agent  | [[LOG-security\|Changelog]]           | —           | 0     |
| Infra Agent     | [[LOG-infra\|Changelog]]              | —           | 0     |
| Compliance      | [[LOG-compliance\|Changelog]]         | —           | 0     |
| Context Steward | [[LOG-context-steward\|Changelog]]    | —           | 0     |
| Orchestrator    | [[LOG-orchestrator\|Changelog]]       | —           | 0     |
EOF

  cat > "${TEAM_DIR}/vault/MOC-decisions.md" << 'EOF'
---
type: moc
tags:
  - type/moc
  - nav/decisions
---

# Architecture Decisions

All ADRs (Architecture Decision Records) across projects.

(No decisions yet)
EOF

  # Create empty LOG files for each agent
  for agent in planner architect ux executor qa security infra compliance context-steward orchestrator; do
    if [ ! -f "${TEAM_DIR}/vault/LOG-${agent}.md" ]; then
      cat > "${TEAM_DIR}/vault/LOG-${agent}.md" << EOF
---
agent: ${agent}
type: changelog
tags:
  - agent/${agent}
  - type/changelog
---

# ${agent} — Changelog

(No entries yet)
EOF
    fi
  done

  echo "  Created Obsidian vault with MOC pages and agent logs"
fi

# Add .team to .gitignore if not already there. Use -F (fixed-string) and -x
# (whole-line match) so the existing-line test is exact and not regex-based.
# Prepend a newline when appending so we never glue onto a final line that
# was missing its trailing newline.
if [ -f ".gitignore" ]; then
  if ! grep -qxF ".team/" ".gitignore"; then
    printf '\n.team/\n' >> ".gitignore"
    echo "  Added .team/ to .gitignore"
  fi
else
  printf '.team/\n' > ".gitignore"
  echo "  Created .gitignore with .team/"
fi

echo "Team workspace ready."

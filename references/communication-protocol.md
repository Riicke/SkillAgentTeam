# Communication Protocol

This document defines how agents communicate through the `.team/` directory.

## Directory Structure

```
.team/
├── board.md              # Task kanban — status of all agents
├── context.md            # Project knowledge (maintained by Context Steward)
├── decisions.md          # Append-only decision log
└── agents/
    ├── planner/          # Planner outputs
    │   └── requirements.md
    ├── architect/        # Architect outputs
    │   └── design.md
    ├── ux/               # UX Agent outputs
    │   └── ux-spec.md
    ├── executor/         # Executor outputs
    │   └── implementation-notes.md
    ├── qa/               # QA Agent outputs
    │   └── test-report.md
    ├── security/         # Security Agent outputs
    │   └── security-report.md
    ├── infra/            # Infra Agent outputs
    │   └── infra-report.md
    ├── compliance/       # Compliance Agent outputs
    │   └── compliance-report.md
    └── context-steward/  # Context Steward notes
```

## Board Format

The board (`.team/board.md`) is the central coordination point.

```markdown
# Team Board

## Current Task
- **ID**: TASK-XXX
- **Description**: [what needs to be done]
- **Status**: planning | designing | implementing | validating | merging | complete
- **Created**: [date]
- **Updated**: [date]

## Agent Status
| Agent      | Status     | Branch                      | Output                              | Notes      |
|------------|------------|-----------------------------|-------------------------------------|------------|
| planner    | done       | —                           | .team/agents/planner/requirements.md | 5 reqs     |
| architect  | done       | —                           | .team/agents/architect/design.md     | 3 ADRs     |
| executor   | working    | agent/executor/task-xxx     | —                                   | in progress|
| qa         | waiting    | —                           | —                                   | needs impl |

## History
### TASK-YYY (completed [date])
- Result: [brief summary]
- Branch: merged to main
```

## Rules

### 1. Read Before Write
Every agent must read the board and relevant prior outputs before starting work.
This prevents duplicate work and conflicting decisions.

### 2. Own Directory Only
Agents write **only** to their own directory under `.team/agents/<role>/`.
The Orchestrator and Context Steward are exceptions — they update the
shared files (`board.md`, `context.md`, `decisions.md`).

### 3. Board Updates
After completing work, every agent appends their status to the board.
Format: `| <role> | <status> | <branch-or-dash> | <output-path> | <notes> |`

### 4. No Cross-Writes
An agent must never modify another agent's files. If an agent disagrees
with another's output, it writes its concern in its own report and the
Orchestrator resolves it.

### 5. Decisions Are Append-Only
The decision log (`.team/decisions.md`) is append-only. To supersede a
decision, add a new entry that references the old one. Never edit or
delete existing entries.

### 6. Task Scoping
Each task gets a clean set of agent outputs. When starting a new task:
1. Archive the previous task's outputs (move to `.team/archive/TASK-XXX/`)
2. Create fresh agent directories
3. Update the board with the new task

### 7. Conflict Resolution
When agents produce conflicting outputs:
1. Both outputs are preserved
2. The conflict is noted on the board
3. The Orchestrator reads both and makes a decision
4. The decision is logged in `.team/decisions.md`
5. The losing agent is notified if they need to adjust

## File Naming Conventions

- Agent outputs: descriptive names in kebab-case (`security-report.md`, `test-report.md`)
- Task IDs: `TASK-001`, `TASK-002`, etc. (auto-incremented)
- Branches: `agent/<role>/<task-id>` (e.g., `agent/executor/task-001`)
- Archives: `.team/archive/TASK-XXX/` preserves the full agent output structure

# Tutorial — Agent Team

## How it works (overview)

You have a **team of 10 AI agents**. Each one has a specialized role,
just like a real software company:

```
  YOU (project owner)
    │
    ▼
  ORCHESTRATOR (Tech Lead)  ← the "manager"; runs automatically
    │
    ├──► Planner (PM)        — defines WHAT to build
    ├──► Architect (Staff)   — defines HOW to build it
    ├──► UX Agent (Designer) — defines how the USER interacts
    ├──► Executor (Dev)      — WRITES the code
    ├──► QA Agent (Tester)   — TESTS the code
    ├──► Security (SecEng)   — REVIEWS security
    ├──► Infra (DevOps)      — handles DEPLOY
    ├──► Compliance (Legal)  — verifies DATA and rules
    └──► Context Steward     — DOCUMENTS everything in Obsidian
```

---

## Do they run simultaneously?

**Yes and no.** It depends on the phase:

```
PHASE 1 ─ PLANNING
  ┌─────────────┐   ┌──────────────┐
  │   Planner   │   │  Architect   │   ← run IN PARALLEL
  │  (the what) │   │  (the how)   │
  └──────┬──────┘   └──────┬───────┘
         │                 │
         └────────┬────────┘
                  ▼
PHASE 2 ─ DESIGN
  ┌─────────────┐
  │  UX Agent   │   ← runs ALONE (needs Phase 1 output)
  └──────┬──────┘
         ▼
PHASE 3 ─ IMPLEMENTATION
  ┌─────────────┐
  │  Executor   │   ← runs ALONE in an isolated git worktree
  │   (code)    │
  └──────┬──────┘
         ▼
PHASE 4 ─ VALIDATION
  ┌──────────┐  ┌──────────┐  ┌────────────┐
  │ QA Agent │  │ Security │  │ Compliance │  ← run IN PARALLEL
  └────┬─────┘  └────┬─────┘  └─────┬──────┘
       │              │              │
       └──────────────┼──────────────┘
                      ▼
PHASE 5 ─ MERGE
  ┌──────────────┐   ┌─────────────────┐
  │ Orchestrator │   │ Context Steward │   ← finalize
  │   (merge)    │   │  (documentation)│
  └──────────────┘   └─────────────────┘
```

**Rule**: same phase = parallel. Between phases = sequential.

Each agent **reads the output of the previous ones** and **writes its own**
for the next.

---

## Do they hand off to each other?

Yes. It is a **chain**. Each agent produces a document the next one consumes:

```
Planner writes → requirements.md
                      │
Architect reads requirements, writes → design.md
                                          │
UX Agent reads requirements + design, writes → ux-spec.md
                                                  │
Executor reads ALL the above, writes → CODE + implementation-notes.md
                                                         │
QA Agent reads requirements + code, writes → test-report.md
                                                      │
Security reads code, writes → security-report.md
                                          │
Orchestrator reads ALL reports → decides merge or fix
                                          │
Context Steward reads everything → updates Obsidian vault
```

All communication happens through **files in the `.team/` folder**:

```
.team/
├── board.md           ← Kanban (who is doing what)
├── agents/
│   ├── planner/requirements.md       ← Planner output
│   ├── architect/design.md           ← Architect output
│   ├── ux/ux-spec.md                 ← UX output
│   ├── executor/implementation.md    ← Executor output
│   ├── qa/test-report.md             ← QA output
│   └── security/security-report.md   ← Security output
└── vault/                            ← Obsidian vault (permanent docs)
```

---

## Step-by-step start

### Step 1 — Initialize the workspace (first time only)

```bash
bash .claude/skills/agent-team/scripts/init-team.sh
```

This creates the `.team/` folder with the board, Obsidian vault, and a
log file for each agent.

### Step 2 — Ask Claude something

Open Claude Code in your project and talk normally. The Orchestrator
activates automatically when it detects certain phrases.

### Step 3 — Track progress in Obsidian

Open `.team/vault/` as a vault in Obsidian and watch the graph grow.

---

## 6 ways to use the team

### Mode 1: Full pipeline (new feature)

**When to use**: a new, complex feature with UI.

```
You say:
  "Team, I need a notification system. The dashboard should
   show a badge when a new message arrives."

What happens:
  1. Orchestrator analyzes → classifies as "New Feature"
  2. Phase 1: Planner + Architect run in parallel
  3. Phase 2: UX Agent defines the interface
  4. Phase 3: Executor implements in an isolated branch
  5. Phase 4: QA + Security validate in parallel
  6. Phase 5: Merge + Context Steward documents

Result:
  - Code implemented in a separate branch
  - 6+ documents in the Obsidian vault
  - Everything linked and traceable
```

### Mode 2: Short pipeline (bug fix)

**When to use**: something is broken and needs fixing.

```
You say:
  "The login button does not respond to clicks."

What happens:
  1. Orchestrator analyzes → classifies as "Bug Fix"
  2. SKIPS Phase 1 and 2 (no need to plan a bug fix)
  3. Phase 3: Executor investigates and fixes
  4. Phase 4: QA validates the fix
  5. Phase 5: Merge

Result:
  - Bug diagnosed and fixed
  - BUG-xxx.md + QA-xxx.md in the vault
```

### Mode 3: Direct agent (shortcut)

**When to use**: you know exactly which agent you want.

```
You say:                          What runs:
  "Run the Security Agent"        → Security only
  "Run QA on this code"           → QA only
  "Run the Architect for cache"   → Architect only
  "Review security"               → Security only
  "Plan the auth system"          → Planner + Architect only
```

### Mode 4: Refactor

**When to use**: code works but needs improvement.

```
You say:
  "Refactor BigComponent.tsx — it is too large."

What happens:
  1. Architect defines how to split it
  2. Executor implements the refactor
  3. QA ensures nothing broke
```

### Mode 5: Security review

**When to use**: before deploy or audit.

```
You say:
  "Team, review the security of the entire runtime."

What happens:
  1. Security does a full scan
  2. Compliance checks data and regulations
  3. (optional) QA tests the fixes
```

### Mode 6: Planning only

**When to use**: think before building.

```
You say:
  "Plan a plugin system. Do not implement yet, just the plan."

What happens:
  1. Planner defines requirements
  2. Architect defines architecture
  3. STOP. Nobody implements.

Result:
  - TASK-xxx.md + ADR-xxx.md in the vault
  - Ready for you to review before approving execution
```

---

## Isolation: how they avoid stepping on each other

### Agents that DO NOT write code
Planner, Architect, UX, Security, Compliance, Context Steward

They only read code and write documents under `.team/`.
Each one writes **only in its own folder**. They never touch
project source files.

### Agents that DO write code
Executor, QA, Infra

They work in **git worktrees** (isolated copies of the repo):

```
Main project (main)
  │
  ├── .worktrees/
  │   ├── agent-executor-task-001/    ← Executor works here
  │   │   └── (full repo copy on branch agent/executor/task-001)
  │   │
  │   └── agent-qa-task-001/          ← QA works here
  │       └── (full repo copy on branch agent/qa/task-001)
  │
  └── src/ (untouched until final merge)
```

When everything is validated, the Orchestrator merges the branches.

---

## Phrases that trigger the skill

| Phrase                                   | Action                         |
|------------------------------------------|--------------------------------|
| "Team, ..."                              | Full pipeline                  |
| "We need ..."                            | Full pipeline                  |
| "Create / Add / Implement [feature]"     | Full pipeline                  |
| "Fix [bug]"                              | Short pipeline (Executor + QA) |
| "Run the [agent name]"                   | Direct agent                   |
| "Review security"                        | Security direct                |
| "Plan [something]"                       | Planner + Architect            |
| "Refactor [something]"                   | Architect + Executor + QA      |
| "Deploy ..."                             | Infra + Executor               |
| "Compliance review of ..."               | Compliance + Security          |

---

## What each agent produces in Obsidian

After each task, the vault gains new files:

```
vault/
├── SPRINT-001-onboarding.md          ← Orchestrator (task overview)
├── TASK-001-onboarding.md            ← Planner (requirements)
├── ADR-001-state-store.md            ← Architect (technical decision)
├── UX-001-onboarding-flow.md         ← UX Agent (interface spec)
├── IMPL-001-state-store-impl.md      ← Executor (what was built)
├── QA-001-onboarding-tests.md        ← QA (test report)
├── SEC-001-input-validation.md       ← Security (findings)
├── LOG-planner.md                    ← Planner changelog (updated)
├── LOG-executor.md                   ← Executor changelog (updated)
├── MOC-example-app.md                ← Context Steward (project index)
└── ...
```

In Obsidian Graph View this looks like:

```
         MOC-example-app
        ╱      │      ╲
  TASK-001   BUG-001   SEC-001
   ╱  │  ╲              │
ADR  UX  IMPL         LOG-security
         │
       QA-001
         │
    LOG-executor ─── MOC-agents
```

Every node is clickable. Every link is traceable.

---

## Quick FAQ

| Question                              | Answer                                       |
|---------------------------------------|----------------------------------------------|
| Do they run simultaneously?           | Yes, within the same phase                   |
| Do they hand off to each other?       | Yes, via files in `.team/`                   |
| Do they need git?                     | Yes, for worktrees (the agents that code)    |
| Can I run a single agent?             | Yes, just ask for it by name                 |
| Can I run on Codex too?               | Yes, see `references/codex-adapter.md`       |
| Where do I see everything?            | Obsidian vault at `.team/vault/`             |
| Do they touch my code directly?       | No, they work on isolated branches           |
| Who decides the merge?                | The Orchestrator, after QA approves          |

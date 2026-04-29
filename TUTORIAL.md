# Tutorial — Agent Team

This tutorial takes you from zero to a working multi-agent pipeline. By the
end you will have:

1. Installed the skill in a sample project.
2. Run a full feature pipeline and inspected every output.
3. Read the resulting Obsidian vault as a knowledge graph.
4. Used short pipelines (bug fix, single agent, planning-only) for everyday
   work.
5. Customized one agent for a domain-specific need.

If you only want a 30-second overview, read the [README](README.md) instead.
This document assumes you are willing to spend an hour learning the model.

---

## Table of contents

1. [Mental model](#1-mental-model)
2. [Prerequisites](#2-prerequisites)
3. [First-time setup](#3-first-time-setup)
4. [Walkthrough — your first feature](#4-walkthrough--your-first-feature)
5. [The five phases in detail](#5-the-five-phases-in-detail)
6. [Six ways to use the team](#6-six-ways-to-use-the-team)
7. [Anatomy of `.team/`](#7-anatomy-of-team)
8. [Reading the Obsidian vault](#8-reading-the-obsidian-vault)
9. [Customizing agents](#9-customizing-agents)
10. [Working with non-Claude frameworks](#10-working-with-non-claude-frameworks)
11. [Troubleshooting](#11-troubleshooting)
12. [FAQ](#12-faq)

---

## 1. Mental model

Think of Agent Team as a small software company in a box. Each role is
played by an LLM agent that has been given a focused prompt describing
its identity, responsibilities, and limits. The Orchestrator is the
"manager" — it reads what you want, decides which agents are needed,
spawns them in the right order, and merges their work.

```
  YOU (project owner)
    │
    ▼
  ORCHESTRATOR (Tech Lead)        ← runs automatically when triggered
    │
    ├──► Planner (PM)             — defines WHAT to build
    ├──► Architect (Staff)        — defines HOW to build it
    ├──► UX Agent (Designer)      — defines how the USER interacts
    ├──► Executor (Engineer)      — WRITES the code
    ├──► QA Agent (Test Engineer) — TESTS the code
    ├──► Security (SecEng)        — REVIEWS for vulnerabilities
    ├──► Infra (DevOps / SRE)     — handles DEPLOY and observability
    ├──► Compliance (DPO)         — verifies DATA handling
    └──► Context Steward          — DOCUMENTS everything in Obsidian
```

The two key invariants of the system:

- **Within a phase, agents run in parallel.** Between phases, work is
  sequential — each phase reads what the previous one produced.
- **Agents communicate through files in `.team/`, not directly.** This
  makes every decision auditable and resumable across sessions.

---

## 2. Prerequisites

Confirm these before starting:

| Tool | Minimum version | Why |
|------|-----------------|-----|
| Git | 2.20 | Worktree support (Executor / QA / Infra need this) |
| Bash | 4.0 | Pipeline scripts target Bash; on Windows use Git Bash or WSL |
| Claude Code | 1.0 (any recent) | Or Codex CLI, or any framework that can spawn subprocesses with a system prompt |
| Obsidian | optional | Only needed if you want to navigate `.team/vault/` as a graph |

Confirm git is recent enough:

```bash
git --version    # should print 2.20 or higher
```

If you're on Windows, run all `bash <path>` commands from Git Bash, WSL,
or PowerShell with `bash.exe` available. Native `cmd.exe` will not work
with the pipeline scripts.

---

## 3. First-time setup

For this tutorial we'll use a fresh project. If you already have one,
skip to step 2.

### Step 1 — Create or pick a project

```bash
mkdir my-project && cd my-project
git init
echo "# My Project" > README.md
git add README.md && git commit -m "Initial commit"
```

### Step 2 — Install the skill

From your project root:

```bash
git clone https://github.com/Riicke/SkillAgentTeam.git .agent-team \
  && bash .agent-team/install.sh \
  && rm -rf .agent-team
```

That installs the skill for both Claude Code and Codex CLI, and runs
`init-team.sh` which creates the `.team/` workspace.

You should now see:

```
my-project/
├── .claude/skills/agent-team/    ← skill (Claude Code)
├── .codex-agents/                ← agent prompts (Codex CLI)
├── AGENTS.md                     ← Codex configuration
├── .team/                        ← team workspace
└── README.md                     ← your existing files
```

### Step 3 — Verify the workspace

```bash
ls .team/
```

Expected output:

```
agents  archive  board.md  context.md  decisions.md  vault
```

Open `.team/board.md` — it should show all agents in `idle` status.

### Step 4 — Seed `.team/context.md`

The Context Steward will populate this file automatically as the team
works, but seeding it manually with project basics speeds up the first
run.

```markdown
# Project Context

## Overview
A short description of what this project is.

## Tech Stack
- Language: (e.g., TypeScript)
- Framework: (e.g., Express)
- Database: (e.g., PostgreSQL)
- Deploy target: (e.g., AWS Lambda)

## Conventions
- (Any project-specific conventions to surface to agents)
```

You're now ready to run the team.

---

## 4. Walkthrough — your first feature

Let's add a simple feature end-to-end. The walkthrough below uses
Claude Code; the equivalent Codex CLI invocation is at the bottom of
this section.

**With Claude Code** — open Claude Code in your project and type:

```
Team, add a /health endpoint that returns { status: "ok" } as JSON.
Include a test.
```

Here is what happens behind the scenes (the same flow applies to
Codex CLI; only how the Orchestrator invokes the agents differs):

### Phase 0 — Orchestrator analysis

The Orchestrator (host LLM) reads `SKILL.md` and starts. It identifies:

- **Ambiguities**: Which framework? What HTTP library? What test
  framework? It will read the codebase first to answer these from
  context, and ask only if it cannot.
- **Task type**: New feature → full pipeline.
- **Agents needed**: Planner, Architect, Executor, QA. UX is skipped
  (no UI). Security and Compliance optional (the endpoint is trivial).

Output: `.team/agents/orchestrator/analysis.md`.

### Phase 1 — Planning (parallel)

**Planner** writes `.team/agents/planner/requirements.md`:

```markdown
# Requirements — Health endpoint

## Objective
Provide a lightweight liveness probe at GET /health.

## Requirements
### REQ-1: GET /health returns 200 with JSON body
- Acceptance: response body is `{"status":"ok"}`, content-type is application/json
- Priority: P0

### REQ-2: Endpoint is unauthenticated
- Acceptance: works without any auth header
- Priority: P0
```

**Architect** writes `.team/agents/architect/design.md`:

```markdown
# Technical Design — Health endpoint

## Approach
Add a single route handler. Use existing HTTP framework conventions.

## Components Affected
| File | Change |
|------|--------|
| src/routes/health.ts | create |
| src/app.ts | modify (register route) |

## ADR-1: Skip authentication
- Decision: this route is unauthenticated
- Rationale: liveness probes must not depend on auth subsystems
```

### Phase 3 — Implementation

**Executor** creates a worktree:

```bash
.worktrees/agent-executor-health-endpoint/
   └── (full repo on branch agent/executor/health-endpoint)
```

It writes the code in that worktree, then writes
`.team/agents/executor/implementation-notes.md`:

```markdown
# Implementation Notes — Health endpoint

## Changes Made
| File | Change | Reason |
|------|--------|--------|
| src/routes/health.ts | created | Per design |
| src/app.ts | modified | Registered new route |
| tests/health.test.ts | created | Required by Planner REQ-1 |

## How to Verify
1. Run the test suite
2. curl http://localhost:3000/health → expect 200, {"status":"ok"}
```

### Phase 4 — Validation

**QA Agent** runs the tests in its own worktree, writes
`.team/agents/qa/test-report.md` with verdict PASS.

### Phase 5 — Close

The Orchestrator merges `agent/executor/health-endpoint` into your main
branch:

```bash
bash .claude/skills/agent-team/scripts/merge-work.sh agent/executor/health-endpoint --delete
```

The **Context Steward** updates the Obsidian vault:

- Creates `.team/vault/SPRINT-001-health-endpoint.md`
- Creates `.team/vault/TASK-001-health-endpoint.md`
- Creates `.team/vault/ADR-001-skip-auth.md`
- Creates `.team/vault/IMPL-001-health-endpoint.md`
- Creates `.team/vault/QA-001-health-endpoint.md`
- Updates the project's `MOC-<project>.md` index
- Appends entries to `LOG-planner.md`, `LOG-architect.md`, etc.

You can now commit:

```bash
git add . && git commit -m "Add /health endpoint"
```

The pipeline took five files of agent output, one merged branch, and
roughly a dozen Obsidian notes for what would have been a one-liner
without the team. For a `/health` endpoint that's overkill — it's an
illustration. For a real feature like authentication or notifications,
the audit trail is invaluable.

### Same task on Codex CLI

The flow above is identical with Codex CLI; only the entry point
changes. From your project root:

```bash
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh feature \
  "Add a /health endpoint that returns { status: 'ok' } as JSON. Include a test."
```

`run-codex-pipeline.sh` runs each phase as a sequential `codex`
invocation (Codex CLI does not support parallel agents within a phase,
so Phase 1's Planner and Architect run one after the other instead of
side by side). All other behaviors — worktrees, `.team/` outputs,
Obsidian vault writes, the merge step — are identical.

For a single-agent run on Codex, use the `agent` subcommand:

```bash
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh agent \
  security-agent "Audit the API surface"
```

---

## 5. The five phases in detail

### Phase 1 — Planning (parallel)

```
  ┌─────────────┐   ┌──────────────┐
  │   Planner   │   │  Architect   │   ← run IN PARALLEL
  │  (the WHAT) │   │  (the HOW)   │
  └──────┬──────┘   └──────┬───────┘
         │                 │
         └────────┬────────┘
                  ▼
```

**Planner** translates the user's intent into testable requirements with
explicit acceptance criteria, priorities (P0/P1/P2), and unhappy paths
for each requirement.

**Architect** reads the codebase, proposes a design, and records
architecture decisions (ADRs). For every significant decision the
Architect presents at least two options with trade-offs.

### Phase 2 — Design (UI only)

```
  ┌─────────────┐
  │  UX Agent   │   ← reads Phase 1 output, runs alone
  │ (the LOOK)  │
  └──────┬──────┘
         ▼
```

**UX Agent** defines user flows, states (default, loading, error, empty,
success), accessibility requirements (WCAG 2.1 AA), and i18n
considerations. Skipped entirely for non-UI tasks.

### Phase 3 — Implementation

```
  ┌─────────────┐
  │  Executor   │   ← runs alone in an isolated git worktree
  │   (CODE)    │
  └──────┬──────┘
         ▼
```

**Executor** creates a worktree, implements the feature per the design,
writes tests, runs the linter and formatter, and documents what was
built. The main branch is never touched.

If infrastructure changes are needed, **Infra Agent** runs alongside
the Executor in its own worktree.

### Phase 4 — Validation (parallel)

```
  ┌──────────┐  ┌──────────┐  ┌────────────┐
  │ QA Agent │  │ Security │  │ Compliance │   ← run IN PARALLEL
  └────┬─────┘  └────┬─────┘  └─────┬──────┘
       │              │              │
       └──────────────┼──────────────┘
                      ▼
```

**QA** runs the test suite, validates against requirements, and probes
edge cases. **Security** does an OWASP / STRIDE review on the diff.
**Compliance** checks PII handling, data retention, and consent
patterns.

If any agent reports critical findings, the pipeline loops back to the
Executor before merging.

### Phase 5 — Close

```
  ┌──────────────┐   ┌─────────────────┐
  │ Orchestrator │   │ Context Steward │   ← finalize
  │   (merge)    │   │ (documentation) │
  └──────────────┘   └─────────────────┘
```

The Orchestrator merges the Executor's branch (after Validation
passes), the Context Steward updates `.team/context.md` and the
Obsidian Maps of Content, and the task is archived.

---

## 6. Six ways to use the team

Not every request needs the full pipeline. Pick the mode that matches
your task. Each mode below shows how to invoke it from both Claude Code
(natural language) and Codex CLI (the wrapper script).

### Mode 1 — Full pipeline (new feature)

**When**: a new, complex feature with UI.

| Path | Invocation |
|------|------------|
| Claude Code | `Team, I need a notification system. The dashboard should show a badge when a new message arrives.` |
| Codex CLI | `bash scripts/run-codex-pipeline.sh feature "Notification system with dashboard badge"` |

```
What runs:
  Phase 1: Planner + Architect
  Phase 2: UX Agent
  Phase 3: Executor (worktree)
  Phase 4: QA + Security + Compliance
  Phase 5: Merge + Context Steward

Result:
  - Code in a separate branch ready to review
  - 7+ documents in .team/vault/
  - Everything cross-linked in Obsidian
```

### Mode 2 — Short pipeline (bug fix)

**When**: something is broken and needs fixing.

| Path | Invocation |
|------|------------|
| Claude Code | `The login button does not respond to clicks.` |
| Codex CLI | `bash scripts/run-codex-pipeline.sh bugfix "Login button does not respond to clicks"` |

```
What runs:
  Phase 3: Executor (investigates and fixes)
  Phase 4: QA (validates the fix)
  Phase 5: Merge

Result:
  - BUG-NNN.md in the vault with diagnosis, root cause, and fix
  - QA-NNN.md confirming verification
```

### Mode 3 — Direct agent (shortcut)

**When**: you know exactly which agent you want.

**Claude Code** — name the agent in plain English:

```
"Run the Security Agent"        → Security only
"Run QA on this code"           → QA only
"Run the Architect for cache"   → Architect only
"Review security"               → Security only
"Plan the auth system"          → Planner + Architect only
```

**Codex CLI** — use the `agent` subcommand:

```bash
bash scripts/run-codex-pipeline.sh agent security-agent "Audit the API"
bash scripts/run-codex-pipeline.sh agent qa-agent       "Validate the auth flow"
bash scripts/run-codex-pipeline.sh agent architect      "Design the cache layer"
```

Valid agent names: `planner`, `architect`, `ux-agent`, `executor`,
`qa-agent`, `security-agent`, `infra-agent`, `compliance-agent`,
`context-steward`.

### Mode 4 — Refactor

**When**: code works but needs improvement.

| Path | Invocation |
|------|------------|
| Claude Code | `Refactor BigComponent.tsx — it is too large.` |
| Codex CLI | `bash scripts/run-codex-pipeline.sh refactor "Split BigComponent.tsx — it is too large"` |

```
What runs:
  Architect (defines the split)
  Executor  (implements)
  QA        (ensures no regression)
```

### Mode 5 — Security review

**When**: before deploy, before audit, or after a CVE drops.

| Path | Invocation |
|------|------------|
| Claude Code | `Team, review the security of the entire runtime.` |
| Codex CLI | `bash scripts/run-codex-pipeline.sh security "Review the security of the entire runtime"` |

```
What runs:
  Security  (full STRIDE walkthrough on the diff or the whole repo)
  Compliance (data and regulation check)
  QA (optional — tests any fixes)
```

### Mode 6 — Planning only

**When**: think before building.

| Path | Invocation |
|------|------------|
| Claude Code | `Plan a plugin system. Don't implement yet.` |
| Codex CLI | `bash scripts/run-codex-pipeline.sh plan "Design a plugin system"` |

```
What runs:
  Planner   (requirements)
  Architect (architecture)
  STOP. Nobody implements.

Result:
  - TASK-NNN.md and ADR-NNN.md ready for your review
  - You decide whether to proceed to Implementation
```

---

## 7. Anatomy of `.team/`

```
.team/
├── board.md              ← Kanban (current task, agent statuses, history)
├── context.md            ← Project knowledge (Context Steward maintains)
├── decisions.md          ← Append-only architecture decision log
├── archive/              ← Past task outputs (preserved indefinitely)
├── agents/               ← Per-agent outputs for the CURRENT task
│   ├── planner/
│   ├── architect/
│   ├── ux/
│   ├── executor/
│   ├── qa/
│   ├── security/
│   ├── infra/
│   ├── compliance/
│   └── context-steward/
└── vault/                ← Obsidian-compatible knowledge graph
    ├── MOC-*.md          ← Maps of Content (navigation hubs)
    ├── LOG-*.md          ← Per-agent changelogs
    ├── TASK-*.md         ← Requirements (Planner)
    ├── ADR-*.md          ← Decisions (Architect)
    ├── UX-*.md           ← UX specs (UX Agent)
    ├── IMPL-*.md         ← Implementation notes (Executor, features)
    ├── BUG-*.md          ← Bug fix records (Executor, fixes)
    ├── QA-*.md           ← Test reports (QA)
    ├── SEC-*.md          ← Security findings (Security)
    ├── COMP-*.md         ← Compliance reports (Compliance)
    ├── INFRA-*.md        ← Infra changes (Infra)
    ├── CTX-*.md          ← Context notes (Context Steward)
    └── SPRINT-*.md       ← Per-task overview pages (Orchestrator)
```

Two important properties:

1. **`.team/agents/<role>/` holds the CURRENT task's working notes.**
   When a new task starts, prior outputs are archived to
   `.team/archive/TASK-NNN/`. The current state never accumulates
   indefinitely.
2. **`.team/vault/` is permanent and grows over time.** It is the
   long-term memory of the project. Don't archive it.

---

## 8. Reading the Obsidian vault

Open `.team/vault/` as a vault in Obsidian:

1. Launch Obsidian
2. *Open folder as vault*
3. Navigate to `your-project/.team/vault/`
4. Open the **Graph view** (Ctrl/Cmd + G)

You'll see something like:

```
              MOC-project
              /    │    \
        TASK-001  BUG-001  SEC-001
         /  │  \             │
       ADR  UX  IMPL      LOG-security
              │
            QA-001
              │
         LOG-executor ─── MOC-agents
```

Each node is a Markdown file. Each edge is a `[[wiki-link]]`. Useful
entry points:

- **`MOC-<project>.md`** — top-level project hub. Lists all tasks, ADRs,
  bugs, security findings.
- **`MOC-agents.md`** — per-agent activity overview with links to each
  agent's changelog.
- **`MOC-decisions.md`** — every architecture decision across the
  project.
- **`LOG-<role>.md`** — chronological history of what each agent did,
  newest first.

The vault grows by ~5–10 files per task. After a few weeks of work it
becomes the most useful project memory you have — searchable, linkable,
and human-readable.

---

## 9. Customizing agents

Every agent is a plain Markdown file under `.claude/skills/agent-team/agents/`
(and `.codex-agents/` for Codex CLI). To change a behavior, edit the file.

### Common customizations

**Add a project-specific check** to the Security Agent:

Edit `.claude/skills/agent-team/agents/security-agent.md`. Find the
"API Security Checklist" section and add a checkbox:

```markdown
- [ ] Internal API keys never logged at INFO level (project-specific)
```

**Add a glossary term** to the Context Steward:

Edit `.team/context.md` directly:

```markdown
## Glossary
| Term | Meaning in This Project |
|------|------------------------|
| Tenant | A customer organization with isolated data |
```

**Skip an agent** for your project (e.g., you don't have UI):

You don't need to delete the UX Agent — the Orchestrator already skips
it for non-UI tasks. If you want to disable it entirely, remove the row
from the `Task Routing` table in `SKILL.md`.

**Tighten a regex or limit** in a script:

The scripts under `scripts/` are intentionally short. Edit them in
place if a project-specific constraint applies. After a re-install
remember `FORCE=1` to overwrite, or your customizations will block
the install.

### Adding a new agent

If your project needs a role we don't ship (Data Engineer, ML
Specialist, Localization Lead, etc.):

1. Copy an existing agent file as a template:
   ```bash
   cp .claude/skills/agent-team/agents/qa-agent.md .claude/skills/agent-team/agents/data-agent.md
   ```
2. Edit Identity, Responsibilities, Boundaries, Input, Output, Rigor
   Protocol, Working Style, domain section, and Escalation Triggers.
3. Add the new role to:
   - `SKILL.md` Agent Roster table
   - `AGENTS.md` Agent Roles table
   - `references/communication-protocol.md` directory layout
   - `init-team.sh` (add `.team/agents/data/` to the `dirs` array)
   - `references/obsidian-vault.md` filename prefix table
4. Pick an Obsidian filename prefix (e.g., `DATA-`).
5. Decide whether the agent writes code (worktree) or only documents.

---

## 10. Working with non-Claude frameworks

The agent prompts are framework-agnostic Markdown. To run them under
another harness:

### Codex CLI

The skill ships with `scripts/run-codex-pipeline.sh` which orchestrates
the full pipeline. See [`AGENTS.md`](AGENTS.md) for the protocol Codex
follows.

### LangGraph / CrewAI / AutoGen

Each agent prompt becomes the system prompt of one node in your graph.
Define the phase pipeline (Planning → Design → Implementation →
Validation → Close), and use `.team/` as the shared state.

A minimal Python pseudocode:

```python
from your_framework import Agent

with open("agents/executor.md") as f:
    executor_prompt = f.read()

executor = Agent(
    system_prompt=executor_prompt,
    tools=["read_file", "write_file", "run_shell", "git"],
    cwd="path/to/project",
)

result = executor.run(
    "Task: implement /health. Read .team/agents/architect/design.md."
)
```

The full integration guide is in
[`references/codex-adapter.md`](references/codex-adapter.md).

---

## 11. Troubleshooting

### Claude Code

**The skill isn't triggering on "team, ...".**
Confirm `.claude/skills/agent-team/SKILL.md` exists and the frontmatter
contains `name: agent-team`. The trigger phrases are listed in the
`description` field. If the description doesn't appear in your message,
invoke explicitly:

```
/agent-team add user authentication
```

**Sub-agents aren't running in parallel.**
The Orchestrator uses Claude Code's `Agent` tool with `isolation:
"worktree"`. Confirm your Claude Code version supports the `Agent`
tool with isolation modes (1.0+). Older versions will run the pipeline
sequentially — still correct, just slower.

**Tool permission prompts on every agent spawn.**
Whitelist the `Agent` tool and `Bash(bash <skill>/scripts/*)` in your
Claude Code settings, or run trusted projects in `--auto-permissions`
mode.

### Codex CLI

**`run-codex-pipeline.sh` reports a prompt error.**
Older `codex` versions read prompts only from `argv`, while the
pipeline script uses stdin for security. Check `codex --help`. If your
version doesn't support stdin, edit `run-codex-pipeline.sh` line 119 to
use `codex - < "$prompt_file"`, or upgrade `codex`.

**Pipeline halts after the Planner.**
Each phase reads the previous one's output. Confirm `AGENTS.md` is in
the project root and `.codex-agents/` exists. Codex reads both before
each role to know how to behave.

**Agents run but never write to `.team/`.**
Codex needs filesystem access in the project root. Confirm you launched
`codex` from the project directory and that `.team/` is writable.

### Both / common

**`init-team.sh` fails with "Permission denied".**
Run with `bash <path>` rather than executing directly:

```bash
bash .claude/skills/agent-team/scripts/init-team.sh
```

**`create-worktree.sh` rejects an agent name or task ID.**
Names must be lowercase, alphanumeric, and dash-separated (regex
`^[a-z0-9][a-z0-9-]*$`). Enforced to prevent path traversal.

**`merge-work.sh` says the working tree is dirty.**
Intentional. `git checkout` on a dirty tree can lose work. Either
`git commit` or `git stash` before re-running.

**An agent keeps producing identical output.**
The agent reads stale state from `.team/`. Either:

```bash
# Archive prior task and start fresh
mkdir -p .team/archive/$(date +%Y%m%d)
mv .team/agents/*/* .team/archive/$(date +%Y%m%d)/

# Or run init-team.sh — it preserves files but resets the board
bash .claude/skills/agent-team/scripts/init-team.sh
```

**Obsidian graph view shows isolated nodes.**
You probably opened the project root, not the vault. Open
`<your-project>/.team/vault/` as the vault.

**A re-install warns about an existing target.**
Set `FORCE=1`:

```bash
FORCE=1 bash .agent-team/install.sh
```

This is a safety guard against silently overwriting customized agent
prompts. If you've made local edits, copy them out before re-installing.

---

## 12. FAQ

**Do agents run simultaneously?**
Yes within the same phase, no between phases. Each phase reads the
output of the previous one.

**Do they hand off to each other?**
Yes — through files in `.team/`. Agents never call each other directly.

**Do I need git?**
Yes. Code-writing agents (Executor, QA, Infra) use `git worktree` for
isolation.

**Can I run only one agent?**
Yes. Ask for it by name ("Run the Security Agent") or pass it to
`run-codex-pipeline.sh agent <agent-name> "<task>"`.

**Can I run on Codex CLI?**
Yes. See [`AGENTS.md`](AGENTS.md) and
[`references/codex-adapter.md`](references/codex-adapter.md).

**Where do I see what was done?**
`.team/board.md` for current state, `.team/vault/` for the long-term
knowledge graph.

**Do agents touch my code directly?**
No. Code-writing agents work on isolated branches (`agent/<role>/<task-id>`)
in `.worktrees/`. The Orchestrator merges only after validation passes.

**Who decides the merge?**
The Orchestrator, after QA / Security / Compliance approve.

**What if QA rejects?**
The Orchestrator routes the failure back to the Executor with the QA
report. The Executor fixes; QA re-validates; loop until pass or until
the Orchestrator escalates to you.

**What if two agents disagree?**
The Orchestrator reads both outputs, decides based on project
priorities and the Architect's constraints, records the resolution in
`.team/decisions.md`, and notifies the affected agents.

**Can I add my own agents?**
Yes. See section 9 (Customizing agents).

**Will this work for a non-software project?**
The structure is generic but the agents (Architect, QA, Security,
Compliance, Infra) are tuned for software. For other domains you would
need to swap several agents — at that point a custom skill is probably
cleaner than adapting this one.

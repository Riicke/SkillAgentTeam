# Agent Team

> **A multi-agent orchestration skill that turns Claude Code or Codex CLI into a complete development team.**
>
> Nine specialized AI agents — Planner, Architect, UX, Executor, QA, Security, Infra, Compliance, and Context Steward — coordinate through a shared filesystem to plan, design, implement, test, and document software changes. Each agent owns a clearly defined slice of the development lifecycle and runs in isolation via git worktrees, so the work is auditable and never silently overwrites your code.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Claude Code](https://img.shields.io/badge/Claude_Code-supported-success.svg)
![Codex CLI](https://img.shields.io/badge/Codex_CLI-supported-success.svg)
![Framework agnostic](https://img.shields.io/badge/framework-agnostic-informational.svg)

---

## Table of contents

- [Why this exists](#why-this-exists)
- [How it works at a glance](#how-it-works-at-a-glance)
- [The team](#the-team)
- [Quick start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Security model](#security-model)
- [Obsidian integration](#obsidian-integration)
- [Repository layout](#repository-layout)
- [Compatibility](#compatibility)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Why this exists

Single-agent AI assistants are powerful but prone to two failure modes when working on real software:

1. **They skip phases.** A request to "build feature X" often jumps straight to code — no requirements analysis, no architecture trade-offs, no test plan, no security review. Mistakes that would have surfaced during planning land in your codebase instead.
2. **They lose context.** Without a structured place to record decisions, every new conversation starts fresh and slowly drifts away from prior choices. By month three, the assistant contradicts decisions it helped make in month one.

Agent Team addresses both problems:

- It enforces an explicit pipeline (Planning → Design → Implementation → Validation → Close) where each phase is owned by a specialized agent with a documented contract.
- All agents communicate through versioned files under `.team/`, so no decision, requirement, or finding is ever lost.
- The `.team/vault/` directory doubles as a fully functional Obsidian vault, giving you a navigable knowledge graph of everything the team has worked on.

The result is more deliberate work, clearer audit trails, and a memory that survives conversations.

---

## How it works at a glance

```
       You: "Team, build an authentication system"
        │
        ▼
    Orchestrator (Tech Lead)
        │
        ├─► Planner    ─► requirements.md   ┐
        ├─► Architect  ─► design.md         │ Phase 1: Planning (parallel)
        │                                   ┘
        ├─► UX Agent   ─► ux-spec.md          Phase 2: Design (if UI involved)
        │
        ├─► Executor   ─► code (in worktree)  Phase 3: Implementation
        │
        ├─► QA Agent   ─► test-report.md    ┐
        ├─► Security   ─► sec-report.md     │ Phase 4: Validation (parallel)
        ├─► Compliance ─► compliance.md     ┘
        │
        ├─► Orchestrator   ─► merge           Phase 5: Close
        └─► Context Steward ─► vault/*.md
```

Within a phase, agents run **in parallel**. Between phases, work is **sequential** — each phase reads what the previous one produced. The Orchestrator skips phases that don't apply (a bug fix goes straight to Implementation; a planning-only request stops after Phase 1).

---

## The team

| # | Agent | Industry role | Owns | Writes code? |
|---|-------|---------------|------|:------------:|
| 1 | **Planner** | Product Manager | Requirements, acceptance criteria, priorities | No |
| 2 | **Architect** | Staff Engineer | Technical design, ADRs, performance budgets | No |
| 3 | **UX Agent** | Product Designer | User flows, accessibility (WCAG 2.1), i18n | No |
| 4 | **Executor** | Software Engineer | Implementation in a git worktree | **Yes** |
| 5 | **QA Agent** | Test Engineer | Tests, regressions, edge cases | **Yes** (tests only) |
| 6 | **Security Agent** | Security Engineer | OWASP / STRIDE review, supply chain, secrets | No |
| 7 | **Infra Agent** | SRE / DevOps | CI/CD, observability, deploy & rollback | **Yes** (config only) |
| 8 | **Compliance Agent** | Data Governance | GDPR / LGPD, PII, retention, consent | No |
| 9 | **Context Steward** | Knowledge Manager | Project memory, Obsidian vault | No |

The Orchestrator is not a separate agent — it is the role the host LLM plays when it reads `SKILL.md`. Every other agent has a dedicated prompt under [`agents/`](agents/) that defines its identity, responsibilities, boundaries, input/output contract, rigor protocol, domain checklist, and escalation triggers.

---

## Quick start

From the root of an existing project:

```bash
git clone https://github.com/Riicke/SkillAgentTeam.git .agent-team \
  && bash .agent-team/install.sh \
  && rm -rf .agent-team
```

That installs the skill for **both** Claude Code and Codex CLI and initializes `.team/` in your project. Then run a task using whichever assistant you prefer.

**With Claude Code** — talk to it naturally:

```
Team, add user authentication with email and password.
```

**With Codex CLI** — invoke the pipeline script:

```bash
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh feature "Add user authentication with email and password"
```

Either path routes the task through the appropriate phases and writes all outputs to `.team/`. Open `.team/vault/` in Obsidian to navigate the resulting knowledge graph.

---

## Installation

### Prerequisites

- **Git** ≥ 2.20 (for `git worktree` support)
- **Bash** (Linux / macOS native; on Windows use Git Bash, WSL, or PowerShell with `bash.exe` available)
- **Claude Code** ≥ 1.0, **Codex CLI**, or any agent framework that can spawn subprocesses with a system prompt
- *(optional)* **Obsidian** to view `.team/vault/` as a knowledge graph

### Install both (Claude Code + Codex CLI)

```bash
git clone https://github.com/Riicke/SkillAgentTeam.git .agent-team \
  && bash .agent-team/install.sh \
  && rm -rf .agent-team
```

### Install only Claude Code

```bash
git clone https://github.com/Riicke/SkillAgentTeam.git .agent-team \
  && bash .agent-team/install.sh --claude \
  && rm -rf .agent-team
```

### Install only Codex CLI

```bash
git clone https://github.com/Riicke/SkillAgentTeam.git .agent-team \
  && bash .agent-team/install.sh --codex \
  && rm -rf .agent-team
```

### Manual installation

```bash
# 1. Clone this repo
git clone https://github.com/Riicke/SkillAgentTeam.git

# 2. Copy the skill into your project (Claude Code)
mkdir -p your-project/.claude/skills
cp -r SkillAgentTeam your-project/.claude/skills/agent-team

# 3. (Optional) Copy agent prompts for Codex CLI
cp -r SkillAgentTeam/agents your-project/.codex-agents
cp SkillAgentTeam/AGENTS.md your-project/AGENTS.md

# 4. Initialize the workspace
cd your-project
bash .claude/skills/agent-team/scripts/init-team.sh
```

`install.sh` refuses to overwrite an existing installation unless you set `FORCE=1`. This protects local edits to agent prompts. To re-install over the top:

```bash
FORCE=1 bash .agent-team/install.sh
```

### What gets created

```
your-project/
├── .claude/skills/agent-team/    ← Skill (Claude Code reads this)
├── .codex-agents/                ← Agent prompts (Codex CLI)
├── AGENTS.md                     ← Codex configuration
└── .team/                        ← Team workspace
    ├── board.md                  ← Task kanban
    ├── context.md                ← Project knowledge
    ├── decisions.md              ← Append-only decision log
    ├── agents/                   ← Per-agent outputs (per task)
    └── vault/                    ← Obsidian vault
        ├── MOC-*.md              ← Maps of Content
        ├── LOG-*.md              ← Agent changelogs
        ├── TASK-*.md             ← Requirements (Planner)
        ├── ADR-*.md              ← Architecture decisions (Architect)
        ├── UX-*.md               ← UX specs (UX Agent)
        ├── IMPL-*.md             ← Code notes (Executor)
        ├── BUG-*.md              ← Bug fixes (Executor)
        ├── QA-*.md               ← Test reports (QA)
        ├── SEC-*.md              ← Security findings (Security)
        ├── COMP-*.md             ← Compliance reports (Compliance)
        ├── INFRA-*.md            ← Infra changes (Infra)
        ├── CTX-*.md              ← Context notes (Context Steward)
        └── SPRINT-*.md           ← Sprint overviews (Orchestrator)
```

`init-team.sh` is idempotent. Re-running it preserves anything already in `.team/`.

---

## Usage

The team can be driven by **Claude Code** (automatic orchestration) or by **Codex CLI** (scripted invocations). Both paths share the same `.team/` workspace, the same agent prompts, and the same Obsidian vault — you can mix them on the same project. Pick the one that fits your workflow.

### Path A — Claude Code (automatic)

Claude Code reads the skill manifest at `.claude/skills/agent-team/SKILL.md` and triggers the Orchestrator automatically when your message matches the skill's description. There is no script to run — the Orchestrator role is the conversation itself, and it spawns agents in parallel through Claude Code's native `Agent` tool with `isolation: "worktree"` for code-writing roles.

**Trigger keywords**: `"team"`, agent names (`"Run the QA Agent"`, `"Run the Architect"`), or task-type verbs (`"plan"`, `"refactor"`, `"fix"`, `"implement"`, `"review"`). The full keyword list is in the `description` field of the SKILL.md frontmatter.

**Examples** of natural phrasings that trigger automatically:

```
✓ Team, add authentication to the server      → full pipeline
✓ The login button isn't working              → bug fix (Executor + QA)
✓ Run the Security Agent on the runtime       → single agent
✓ Plan the cache system                       → Planner + Architect only
✓ Refactor BigComponent.tsx                   → Architect + Executor + QA
✓ Compliance review of the export endpoint    → Compliance + Security
```

**Explicit invocation**: if the skill doesn't trigger automatically (for example because your phrasing doesn't match any keyword), invoke it directly:

```
/agent-team add user authentication
```

**Monitoring progress**: agents stream their progress into the conversation as they complete each phase, and the durable record lives in:

- `.team/board.md` — current task state and per-agent status
- `.team/agents/<role>/` — per-agent outputs for the current task
- `.team/vault/` — long-term Obsidian-compatible documentation

**Stopping mid-pipeline**: send `stop` or press Escape. Outputs already written to `.team/` survive; the Orchestrator can resume by re-reading the board on the next turn.

**The full Claude Code orchestration protocol** — which agents the Orchestrator spawns, in what order, with what context, how it handles conflict resolution — is documented in [`SKILL.md`](SKILL.md).

### Path B — Codex CLI (scripted)

Codex CLI does not have native multi-agent orchestration, so the skill ships a wrapper script (`scripts/run-codex-pipeline.sh`) that runs the pipeline as a sequence of single-agent `codex` invocations. Prompts are written to a temp file and piped via stdin so that task descriptions cannot be shell-expanded.

**Pipelines** (run the full team for a task type):

```bash
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh feature  "Add an auth system"
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh bugfix   "Login button not working"
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh security "Audit the API surface"
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh refactor "Split BigComponent.tsx"
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh plan     "Design a plugin system"
```

**Single agent**:

```bash
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh agent security-agent "Audit the API"
```

**Direct invocation** (bypassing the pipeline script):

```bash
codex < <(printf 'Read .codex-agents/planner.md and follow its protocol.\nTask: Add notifications.\n')
```

**The full Codex CLI protocol** — the 9-step checklist Codex follows on each invocation, which files to read, where to write — is documented in [`AGENTS.md`](AGENTS.md). That file is also the entry point Codex itself reads when it starts in your project.

### Side-by-side comparison

| Capability | Claude Code | Codex CLI |
|------------|:-----------:|:---------:|
| Automatic skill triggering | ✅ via SKILL.md description | ⚠️ via the wrapper script |
| Parallel agents within a phase | ✅ native (`Agent` tool with `isolation: "worktree"`) | ❌ sequential within a phase |
| Worktree isolation | ✅ automatic | ✅ via `create-worktree.sh` |
| Conversation transcript | ✅ in-app | ⚠️ terminal scrollback |
| Project entry point | [`SKILL.md`](SKILL.md) | [`AGENTS.md`](AGENTS.md) |

### Path C — Other frameworks (LangGraph, CrewAI, AutoGen, …)

The agent prompts are plain Markdown. Any framework that supports loading a system prompt from a file and giving the agent filesystem access can run them. Each agent prompt becomes the system prompt of one node in your graph; use `.team/` as shared state. See [`references/codex-adapter.md`](references/codex-adapter.md) for a worked integration example.

---

## Architecture

### Phases

Work is split into five phases. The Orchestrator skips any phase that doesn't apply.

| Phase | Agents | Parallel? | Skipped when |
|-------|--------|:---------:|--------------|
| 1. Planning | Planner + Architect | Yes | Bug fix, or user already provided full specs |
| 2. Design | UX Agent | Solo | No UI involved |
| 3. Implementation | Executor (+ Infra if applicable) | Solo | Planning-only request |
| 4. Validation | QA + Security + Compliance | Yes | Planning-only request |
| 5. Close | Orchestrator + Context Steward | Yes | Never |

### Smart routing

The Orchestrator selects agents based on the task type rather than always running the full pipeline. This is matched against the table below before Phase 1 begins.

| Task type | Required agents | Optional |
|-----------|-----------------|----------|
| New feature | Planner, Architect, Executor, QA | UX, Security, Compliance |
| Bug fix | Executor, QA | Architect, Security |
| Refactor | Architect, Executor, QA | — |
| Security review | Security, Compliance | QA |
| UI / UX change | UX, Executor, QA | Architect |
| Infrastructure | Infra, Executor | Security, QA |
| Planning only | Planner, Architect | — |

### Communication

Agents never talk to each other directly. They exchange information through versioned files under `.team/`. Every agent reads the board and prior agent outputs before starting work, and writes its own output under `.team/agents/<own-role>/`.

```
Planner          ─► .team/agents/planner/requirements.md
                                ↓
Architect        ─► .team/agents/architect/design.md
                                ↓
UX Agent         ─► .team/agents/ux/ux-spec.md
                                ↓
Executor         ─► CODE (in a git worktree) + .team/agents/executor/notes.md
                                ↓
QA Agent         ─► .team/agents/qa/test-report.md
Security         ─► .team/agents/security/security-report.md
Compliance       ─► .team/agents/compliance/compliance-report.md
                                ↓
Context Steward  ─► .team/vault/*.md
```

This filesystem-backed protocol has three properties worth highlighting:

- **Auditable** — every decision and finding lives in a file, version-controlled with the rest of the project.
- **Resumable** — a task can be paused and picked up later (or in a new conversation) without losing context.
- **Framework-agnostic** — any agent that can read and write files can participate.

### Isolation

Code-writing agents (Executor, QA, Infra) work in **git worktrees** under `.worktrees/agent-<name>-<task-id>/`. Each worktree is a clean copy of the repo on its own branch (`agent/<name>/<task-id>`). Agents never modify your `main` branch directly — the Orchestrator merges only after Validation passes.

Non-code agents (Planner, Architect, UX, Security, Compliance, Context Steward) read the codebase and write only into `.team/`.

### Engineering principles

All agents share a common rigor protocol documented in [`references/engineering-principles.md`](references/engineering-principles.md). The 10 principles cover ambiguity surfacing, business-rule extraction, edge cases, bug methodology, legacy-code respect, trade-off presentation, going beyond the happy path, fact vs. inference vs. hypothesis labeling, auditable reasoning, and incremental-before-ideal solutions.

---

## Configuration

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `TEAM_DIR` | `.team` | Root of the team communication workspace |
| `WORKTREE_DIR` | `.worktrees` | Where Executor / QA / Infra worktrees live |
| `MAIN_BRANCH` | auto-detected (`main` → `master` → current) | Branch new worktrees branch off |
| `FORCE` | `0` | Set to `1` to allow `install.sh` to overwrite an existing installation |

### Project context

Project-specific context (tech stack, ports, conventions, glossary) lives in `.team/context.md`. The file is created by `init-team.sh` and maintained by the Context Steward as the project evolves. Agents read it before starting work; you can also edit it manually to seed initial context.

### Decision log

Architectural and project decisions are recorded append-only in `.team/decisions.md`. The log is never edited or deleted — to supersede a decision, add a new entry that links back to the old one. This preserves the historical reasoning that future maintainers (and agents) need.

---

## Security model

The scripts that an LLM agent invokes on your behalf were hardened to close common foot-guns:

- **No shell injection from task descriptions.** `run-codex-pipeline.sh` writes prompts to a temp file and pipes them to `codex` via stdin, so `argv` is never reachable from user input. Without this, a task description containing `$(...)` would be evaluated as a command before reaching the model.
- **Strict input validation.** `create-worktree.sh` and `merge-work.sh` validate agent names, task IDs, and branch names against `^[a-z0-9][a-z0-9-]*$` and `git check-ref-format` before passing them to git. Path traversal and branch-name flag injection (e.g., `--upload-pack=...`) are blocked.
- **Git invocations use `--` separators** wherever supported, so attacker-controlled positionals can never be reinterpreted as flags.
- **No silent overwrites.** `install.sh` aborts when a target installation exists unless `FORCE=1`. Local edits to agent prompts survive re-installs.
- **Symlink-safe state copy.** On Unix, `.team/` is symlinked into worktrees (single source of truth, no drift). On Windows, it's copied with `cp -rP` to preserve any internal symlinks rather than dereferencing them.
- **Dirty-tree guard on merge.** `merge-work.sh` refuses to switch branches if the working tree has uncommitted changes, preventing accidental data loss.

If you find a security issue, please open an issue with the label `security` or contact the maintainer privately.

---

## Obsidian integration

`.team/vault/` is a fully functional Obsidian vault. Every agent writes notes that follow a strict naming and frontmatter convention:

- **File naming**: `PREFIX-NNN-slug.md` (e.g., `TASK-001-auth.md`, `ADR-002-state-store.md`). IDs are global and auto-increment across the vault.
- **YAML frontmatter**: `id`, `agent`, `date`, `project`, `status`, hierarchical tags (`agent/planner`, `type/task`, `project/example-app`).
- **Wiki-links**: documents reference each other with `[[TASK-001-auth|Auth Requirements]]`. Every document links to its parent task, the agent's changelog, and any documents it depends on.
- **Agent changelogs**: each agent maintains `LOG-<role>.md` (newest first).
- **Maps of Content**: the Context Steward maintains `MOC-<project>.md`, `MOC-agents.md`, `MOC-decisions.md` as navigation hubs.

Open `.team/vault/` as a vault in Obsidian and the graph view connects every task, decision, implementation, and finding into one navigable knowledge brain:

```
         MOC-project
        ╱     │     ╲
  TASK-001  BUG-001  SEC-001
   ╱  │  ╲             │
ADR  UX  IMPL       LOG-security
         │
       QA-001
         │
    LOG-executor ─── MOC-agents
```

See [`references/obsidian-vault.md`](references/obsidian-vault.md) for the full convention.

---

## Repository layout

```
SkillAgentTeam/
├── SKILL.md                           # Main orchestrator (Claude Code entry point)
├── AGENTS.md                          # Codex CLI entry point
├── TUTORIAL.md                        # Step-by-step tutorial
├── README.md                          # This file
├── LICENSE                            # MIT
├── install.sh                         # One-command installer
├── agents/                            # Agent prompts (one per role)
│   ├── planner.md
│   ├── architect.md
│   ├── ux-agent.md
│   ├── executor.md
│   ├── qa-agent.md
│   ├── security-agent.md
│   ├── infra-agent.md
│   ├── compliance-agent.md
│   └── context-steward.md
├── references/
│   ├── engineering-principles.md      # The 10 shared principles
│   ├── communication-protocol.md      # How agents communicate
│   ├── obsidian-vault.md              # Vault conventions
│   └── codex-adapter.md               # Multi-framework adapter guide
└── scripts/
    ├── init-team.sh                   # Initialize .team/ workspace
    ├── create-worktree.sh             # Create isolated git worktree
    ├── merge-work.sh                  # Merge agent branch into main
    └── run-codex-pipeline.sh          # Automated Codex CLI pipeline
```

---

## Compatibility

| Platform | Status | How |
|----------|:------:|-----|
| Claude Code (CLI) | **Full** | Automatic skill orchestration |
| Claude Code (Desktop / VS Code) | **Full** | Same as CLI |
| Codex CLI (OpenAI) | **Scripted** | Via `run-codex-pipeline.sh` or direct `codex` calls |
| LangGraph / CrewAI / AutoGen | **Portable** | Load agent prompts as system prompts; share `.team/` as state |
| Any framework with file I/O | **Portable** | The filesystem protocol is framework-agnostic |

---

## Troubleshooting

### Claude Code

**The skill isn't triggering automatically.**
Confirm `.claude/skills/agent-team/SKILL.md` exists in your project and the frontmatter contains `name: agent-team`. Claude Code looks here for skill manifests; the `description` field contains the trigger keywords. If your phrasing doesn't match any keyword, invoke the skill explicitly:

```
/agent-team add user authentication
```

**Sub-agents aren't running in parallel.**
The Orchestrator uses Claude Code's `Agent` tool with `isolation: "worktree"`. Confirm your Claude Code version supports the `Agent` tool with isolation modes (1.0+). If you're on an older version, the pipeline will run sequentially — still correct, just slower.

**The conversation hits a tool-permission prompt for every agent spawn.**
Whitelist the `Agent` tool and `Bash(bash <skill>/scripts/*)` in your Claude Code settings, or run the project in `--auto-permissions` mode for trusted projects.

### Codex CLI

**`run-codex-pipeline.sh` reports a prompt error.**
The pipeline passes prompts via stdin (`codex < <prompt-file>`). Confirm your `codex` version reads from stdin (`codex --help`). Older versions may require `-` as an explicit argument; in that case, edit `run-codex-pipeline.sh` line 119 to read `codex - < "$prompt_file"`.

**Agents run but never write to `.team/`.**
Codex needs filesystem access in the project root. Confirm you launched `codex` from the project directory and that `.team/` is writable.

**Pipeline halts after the Planner — no Architect output.**
Each phase reads the previous one's output. If the Planner wrote to `.team/agents/planner/` but the Architect skipped reading it, check that `AGENTS.md` is in the project root and that `.codex-agents/` exists. Codex reads both before each role.

### Both / common

**`init-team.sh` reports "Permission denied".**
Run with `bash <path>` rather than executing directly:

```bash
bash .claude/skills/agent-team/scripts/init-team.sh
```

On Windows + Git Bash, use forward slashes in the path.

**`create-worktree.sh` rejects an agent name or task ID.**
Names must match `^[a-z0-9][a-z0-9-]*$` (lowercase alphanumerics and dashes, starting with a letter or digit). Enforced to prevent path traversal and branch-name flag injection.

**`merge-work.sh` says the working tree has uncommitted changes.**
Intentional — checking out a different branch with uncommitted work risks losing it. Either `git commit` or `git stash` first, then re-run.

**An agent keeps producing the same output across tasks.**
Stale state in `.team/`. Either archive the previous task (`mv .team/agents/<role>/* .team/archive/<task-id>/`) or re-run `init-team.sh` (it preserves files but resets the board).

**The Obsidian graph view isn't connecting documents.**
Open `.team/vault/` as the vault root, not your project root. Wiki-links resolve relative to the vault root.

**A re-install warns about an existing target.**
Set `FORCE=1` to overwrite. Local edits to agent prompts will be lost — copy them out first if you've customized.

---

## Contributing

PRs are welcome. A few guidelines:

1. **Open an issue first** for non-trivial changes — agreement on scope saves rework.
2. **Keep agent prompts concise.** Each agent file should fit comfortably under 250 lines. Verbosity is the enemy; the LLM has to re-read these every spawn.
3. **Match existing conventions.** Section ordering: Identity → Responsibilities → Boundaries → Input → Output → Obsidian Vault Output → Rigor Protocol → Working Style → *domain section* → Escalation Triggers. Tone: terse, present tense. Markdown only.
4. **Run a security review on any new shell script.** See [`scripts/`](scripts/) for the patterns we use: `set -euo pipefail`, strict input validation, `--` separators on git, prompts via stdin, no `eval`.
5. **No project-specific leakage.** All examples must be neutral and generic so the skill remains a usable template.

---

## License

[MIT](LICENSE) © Riicke ([@riickes](https://instagram.com/riickes))

# Agent Team — Codex CLI configuration

This file is the entry point Codex CLI reads when it starts in a project that
uses the Agent Team skill. It tells Codex how to behave: which agent role to
play for a given task, where to read prior context, where to write output, and
how to coordinate with the rest of the team through the `.team/` workspace.

If you are reading this in a browser and want a high-level overview, start
with the [README](README.md) instead. This document is operational — it
describes the protocol Codex must follow, not why the protocol exists.

---

## Purpose

Codex CLI lacks native multi-agent orchestration, so the Agent Team skill
runs the pipeline as a sequence of specialized single-agent invocations,
each driven by a role-specific prompt under `.codex-agents/`. Every
invocation is given:

1. A role to play (Planner, Architect, UX, Executor, QA, Security, Infra,
   Compliance, or Context Steward).
2. The task description.
3. Pointers to the files it must read before starting.
4. The directory it must write its output to.

This file is the contract Codex follows on every invocation.

---

## When given a development task

Before the checklist below, run a non-blocking update check:

```bash
bash .claude/skills/agent-team/scripts/check-updates.sh --quiet
```

The script is silent when up to date and prints a notice if a new release is
available. It caches for 24 hours and fails silently without network or
`curl`. If it prints an "update available" notice, surface it to the user
once at the top of your reply and offer
`bash .claude/skills/agent-team/scripts/update.sh`. Never run the update
yourself — it overwrites local edits and must be confirmed by the user.
Continue with the checklist regardless of the result.

Then follow this checklist before producing any output:

1. **Read the board.** Open `.team/board.md`. It is the kanban state for the
   current task — what is in progress, who has finished, what is blocking.
2. **Classify the task type.** Use the Task Routing table below to decide
   which agent roles are needed. Not every task needs every agent.
3. **Pick your role.** If the user invocation specified an agent (e.g., the
   `agent` subcommand of `run-codex-pipeline.sh`), play that role and only
   that role. If multiple roles are needed, run them sequentially in the
   order dictated by the Phase Pipeline.
4. **Read the role prompt.** For each role you must play, read
   `.codex-agents/<role>.md` first. That file is the authoritative
   description of the agent's identity, responsibilities, boundaries,
   input contract, output contract, rigor protocol, and escalation
   triggers. Follow it exactly.
5. **Read prior agent outputs.** Before starting your role, read every
   prior agent's output relevant to your phase (see the Phase Pipeline).
   Never proceed on silent assumptions about what previous agents
   decided.
6. **Read the project context.** `.team/context.md` holds tech stack,
   conventions, and prior decisions. `.team/decisions.md` is the
   append-only architecture decision log.
7. **Do the work.** Stay strictly within your role's boundaries.
8. **Write outputs to two places.**
   - **`.team/agents/<role-dir>/`** — the structured output for the next
     agent in the pipeline (see the role prompt for the exact filename).
   - **`.team/vault/`** — Obsidian-compatible documentation with YAML
     frontmatter and `[[wiki-links]]` (see the role prompt for naming).
9. **Update `.team/board.md`** with your status, the branch you used (if
   any), and a one-line summary of what you produced.

If at any step you discover information that contradicts the user's
request or a prior decision, stop and surface the contradiction. Do not
silently work around it.

---

## Task Routing

| Task type | Required agents | Optional agents |
|-----------|-----------------|-----------------|
| New feature | Planner → Architect → Executor → QA | UX, Security, Compliance |
| Bug fix | Executor → QA | Architect, Security |
| Refactor | Architect → Executor → QA | — |
| Security review | Security | Compliance, QA |
| UI / UX change | UX → Executor → QA | Architect |
| Infrastructure | Infra → Executor | Security, QA |
| Planning only | Planner → Architect | — |

Use judgment. Skip phases that don't apply. A simple typo fix needs the
Executor only, not the full pipeline.

---

## Phase Pipeline

When running multiple agents, sequence them strictly in this order. Within
the same phase, agents may run in parallel if your harness supports it; if
not, run them sequentially in the order listed.

| Phase | Agents | Reads | Writes |
|-------|--------|-------|--------|
| 1. Planning | Planner, Architect | `.team/board.md`, `.team/context.md`, project source | `.team/agents/planner/`, `.team/agents/architect/` |
| 2. Design | UX Agent | Phase 1 outputs, project UI source | `.team/agents/ux/` |
| 3. Implementation | Executor (+ Infra if applicable) | Phases 1–2, project source | code in worktree, `.team/agents/executor/` |
| 4. Validation | QA Agent, Security Agent, Compliance Agent | Phase 3 outputs and code | `.team/agents/qa/`, `.team/agents/security/`, `.team/agents/compliance/` |
| 5. Close | Orchestrator role, Context Steward | All prior outputs | `.team/board.md`, `.team/decisions.md`, `.team/vault/` |

The Orchestrator role here is the host LLM (you, when reading this file
without a more specific role assigned). It owns Phase 0 (analysis) and
Phase 5 (merge).

---

## Agent Roles

Every role is documented in its own prompt file. Read the file before
playing the role; do not improvise based on the table alone.

| Role | Prompt file | Owns | Writes code? |
|------|-------------|------|:------------:|
| Planner | `.codex-agents/planner.md` | Requirements, acceptance criteria, priorities | No |
| Architect | `.codex-agents/architect.md` | Technical design, ADRs, performance budgets | No |
| UX Agent | `.codex-agents/ux-agent.md` | User flows, accessibility, i18n | No |
| Executor | `.codex-agents/executor.md` | Implementation in a git worktree | **Yes** |
| QA Agent | `.codex-agents/qa-agent.md` | Tests, regressions, edge cases | **Yes** (tests only) |
| Security Agent | `.codex-agents/security-agent.md` | Vulnerability review, threat modeling, supply chain | No |
| Infra Agent | `.codex-agents/infra-agent.md` | CI/CD, deploy, observability, rollback | **Yes** (infra config only) |
| Compliance Agent | `.codex-agents/compliance-agent.md` | PII, retention, consent, regulations | No |
| Context Steward | `.codex-agents/context-steward.md` | Project memory, Obsidian vault | No |

---

## Communication protocol

All agents communicate exclusively through `.team/`. Strict rules:

1. **Read before write.** Every agent reads `.team/board.md` and the
   relevant prior agent outputs before starting.
2. **Own directory only.** An agent writes only under
   `.team/agents/<own-role>/`. Cross-writing is forbidden.
3. **Board updates.** After completing work, append a status row to
   `.team/board.md` with your role, status, branch (if any), and output
   path.
4. **Decisions are append-only.** `.team/decisions.md` is never edited
   or deleted. To supersede a decision, add a new entry that links back.
5. **Conflicts go to the Orchestrator.** If your output contradicts
   another agent's, write your concern in your own report and let the
   Orchestrator resolve it. Do not silently override.

The full specification is in [`references/communication-protocol.md`](references/communication-protocol.md).

---

## Worktree isolation (code-writing agents)

Executor, QA, and Infra work in isolated git worktrees so their changes
never touch the main branch directly.

To create a worktree before implementing:

```bash
bash .claude/skills/agent-team/scripts/create-worktree.sh <agent-name> <task-id>
# e.g., create-worktree.sh executor add-auth
```

This creates a worktree at `.worktrees/agent-<name>-<task-id>/` on a new
branch `agent/<name>/<task-id>`. The script validates `<agent-name>` and
`<task-id>` against `^[a-z0-9][a-z0-9-]*$` to prevent path traversal and
branch-name flag injection.

The Orchestrator merges the branch only after Phase 4 (Validation) passes:

```bash
bash .claude/skills/agent-team/scripts/merge-work.sh agent/<name>/<task-id>
# Add --delete to also remove the worktree and branch after merging.
```

`merge-work.sh` refuses to switch branches if the working tree has
uncommitted changes.

---

## Obsidian vault output

Every agent also writes Obsidian-compatible Markdown to `.team/vault/`
following the convention in [`references/obsidian-vault.md`](references/obsidian-vault.md):

- **Filename**: `PREFIX-NNN-slug.md` where PREFIX matches the agent
  (TASK for Planner, ADR for Architect, UX for UX Agent, IMPL for
  Executor features, BUG for Executor fixes, QA for QA, SEC for
  Security, COMP for Compliance, INFRA for Infra, CTX for Context
  Steward, SPRINT for Orchestrator).
- **Frontmatter**: YAML with `id`, `agent`, `date`, `project`,
  `status`, hierarchical `tags`, and `related` cross-references.
- **Wiki-links**: every document links to its parent task, the agent's
  changelog (`LOG-<role>.md`), and any documents it depends on or
  enables.
- **Changelog**: append a one-entry update at the top of
  `LOG-<role>.md` for every task you complete.

---

## Project context

`.team/context.md` holds project-specific information (tech stack,
ports, conventions, glossary, recent changes). It is created by
`init-team.sh` and maintained by the Context Steward as the project
evolves. Read it before starting any task.

If `.team/context.md` is empty or stale, populate it before doing
implementation work. The Context Steward owns long-term maintenance.

---

## Configuration

These environment variables affect script behavior:

| Variable | Default | Purpose |
|----------|---------|---------|
| `TEAM_DIR` | `.team` | Root of the team workspace |
| `WORKTREE_DIR` | `.worktrees` | Where worktrees live |
| `MAIN_BRANCH` | auto-detected | Branch new worktrees branch off |
| `FORCE` | `0` | Set to `1` to allow `install.sh` to overwrite an existing installation |

---

## Common patterns

**A user asks for a "feature".** Run the full pipeline. Skip Phase 2
(Design) only if the change has no UI surface.

**A user asks to "fix" or "investigate" something.** Treat as a bug fix.
Skip Phase 1 (Planning) and Phase 2 (Design). Go to Phase 3
(Implementation) and Phase 4 (Validation) directly.

**A user asks to "plan" or "design" something without implementing.**
Run Phase 1 only. Stop after Architect produces `design.md`.

**A user names a specific agent.** Run only that agent. Do not auto-spawn
the next phase.

**Mid-task, an agent finds a contradiction with a prior decision.** Stop.
Append a note to your own output explaining the contradiction. Do not
silently override the prior decision.

**A pipeline has a failure mid-phase.** Halt. Update `.team/board.md`
with the failure mode. Surface to the user before proceeding.

---

## Pointers to other documents

- [`SKILL.md`](SKILL.md) — Claude Code orchestrator entry point (more
  detailed than this file because Claude Code has native multi-agent
  spawning).
- [`README.md`](README.md) — public-facing overview, installation, and
  troubleshooting.
- [`TUTORIAL.md`](TUTORIAL.md) — step-by-step tutorial with worked
  examples.
- [`references/engineering-principles.md`](references/engineering-principles.md) — the 10 principles every agent follows.
- [`references/communication-protocol.md`](references/communication-protocol.md) — full specification of the `.team/` filesystem protocol.
- [`references/obsidian-vault.md`](references/obsidian-vault.md) — vault naming and frontmatter conventions.
- [`references/codex-adapter.md`](references/codex-adapter.md) — running the agents under frameworks other than Codex CLI.

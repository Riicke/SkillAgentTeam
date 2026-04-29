# Agent Team — Codex Configuration

This project uses a multi-agent development team. Each agent has a
specialized role and communicates through the `.team/` directory.

## When given a development task:

1. Read `.team/board.md` for current project state
2. Classify the task type (feature, bug fix, refactor, security review, etc.)
3. Determine which agent roles are needed:

| Task Type        | Agents Needed                          |
|------------------|----------------------------------------|
| New feature      | Planner → Architect → UX → Executor → QA |
| Bug fix          | Executor → QA                          |
| Refactor         | Architect → Executor → QA              |
| Security review  | Security (+ Compliance optional)       |
| UI/UX change     | UX → Executor → QA                    |
| Planning only    | Planner → Architect                    |

4. For each agent needed, read `.codex-agents/<role>.md` and follow its protocol
5. Write outputs to `.team/agents/<role>/` AND `.team/vault/` (Obsidian)
6. Update `.team/board.md` after completing

## Agent Roles

| Agent           | Prompt File                          | Purpose                |
|-----------------|--------------------------------------|------------------------|
| Planner         | `.codex-agents/planner.md`           | Define requirements    |
| Architect       | `.codex-agents/architect.md`         | Define technical design |
| UX Agent        | `.codex-agents/ux-agent.md`          | Define user experience |
| Executor        | `.codex-agents/executor.md`          | Write code             |
| QA Agent        | `.codex-agents/qa-agent.md`          | Test and validate      |
| Security        | `.codex-agents/security-agent.md`    | Security review        |
| Infra           | `.codex-agents/infra-agent.md`       | Deploy and ops         |
| Compliance      | `.codex-agents/compliance-agent.md`  | Data governance        |
| Context Steward | `.codex-agents/context-steward.md`   | Project memory         |

## Communication

All agents read/write through `.team/`. Each agent:
- Reads `.team/board.md` and prior agent outputs before starting
- Writes ONLY to `.team/agents/<own-role>/`
- Creates Obsidian-compatible `.md` files in `.team/vault/` with `[[wiki-links]]`
- Never modifies another agent's files

## Project Context

For project-specific context (tech stack, ports, language, conventions),
agents read `.team/context.md`. That file is created by `init-team.sh` and
maintained by the Context Steward.

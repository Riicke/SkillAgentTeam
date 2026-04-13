# Codex CLI & Multi-Framework Adapter

This guide explains how to use the Agent Team system with different AI agent
frameworks beyond Claude Code.

## Codex CLI (OpenAI)

Codex CLI reads `AGENTS.md` from the project root for agent instructions.

### Setup

1. Copy the agent prompts to your project:
```bash
cp -r skills/agent-team/agents/ .codex-agents/
```

2. Create an `AGENTS.md` in your project root:
```markdown
# Agent Team Configuration

This project uses a multi-agent development team. Each agent has a
specialized role and communicates through the `.team/` directory.

## How to Use

When given a development task:
1. Read `.team/board.md` for current state
2. Determine which agent role applies to your task
3. Read the corresponding prompt in `.codex-agents/<role>.md`
4. Follow that agent's protocol for input, output, and boundaries

## Agent Roles
- Planner: `.codex-agents/planner.md` — defines requirements
- Architect: `.codex-agents/architect.md` — defines technical design
- UX Agent: `.codex-agents/ux-agent.md` — defines user experience
- Executor: `.codex-agents/executor.md` — implements code
- QA Agent: `.codex-agents/qa-agent.md` — tests and validates
- Security: `.codex-agents/security-agent.md` — security review
- Infra: `.codex-agents/infra-agent.md` — deployment and ops
- Compliance: `.codex-agents/compliance-agent.md` — data governance
- Context Steward: `.codex-agents/context-steward.md` — project memory

## Communication
All agents read/write through `.team/`. See `.team/board.md` for status.
```

3. Initialize the team workspace:
```bash
bash skills/agent-team/scripts/init-team.sh
```

### Running Agents with Codex

Since Codex CLI doesn't have native multi-agent orchestration, you run
agents sequentially by giving Codex the role-specific prompt:

```bash
# Run the Planner
codex "Read .codex-agents/planner.md and follow its protocol. Task: Add user authentication"

# Run the Architect
codex "Read .codex-agents/architect.md and follow its protocol. Task: Add user authentication. Read .team/agents/planner/ for requirements."

# Run the Executor
codex "Read .codex-agents/executor.md and follow its protocol. Task: implement auth per the design in .team/agents/architect/design.md"
```

For worktree isolation with Codex, create the worktree manually first:
```bash
bash skills/agent-team/scripts/create-worktree.sh executor add-auth
cd .worktrees/agent-executor-add-auth
codex "Read .codex-agents/executor.md and follow its protocol. ..."
```

## Generic Agent Framework

The agent prompts are plain markdown files. Any agent framework can use them
if it supports:

1. **System prompt from file** — load `agents/<role>.md` as the agent's instructions
2. **Filesystem access** — agents need to read/write `.team/` and project files
3. **Git access** — for worktree-based isolation

### Minimal Integration

```python
# Pseudocode for any agent framework
import agent_framework

# Load agent prompt
with open("agents/executor.md") as f:
    system_prompt = f.read()

# Create agent with the prompt
agent = agent_framework.create_agent(
    system_prompt=system_prompt,
    tools=["file_read", "file_write", "bash", "git"],
    working_directory="path/to/project"
)

# Run the agent
result = agent.run(
    "Task: implement auth. Read .team/agents/architect/design.md for the plan."
)
```

### Multi-Agent Orchestration

If your framework supports multi-agent orchestration (e.g., LangGraph,
CrewAI, AutoGen):

1. Create one agent per role, each with its corresponding prompt
2. Define the phase pipeline: Planning → Design → Implementation → Validation
3. Use the `.team/` directory as the shared state between agents
4. Let the framework handle parallel execution within phases

The key advantage of the `.team/` filesystem protocol is that it's
framework-agnostic — any agent that can read and write files can participate.

## Claude Code Integration

In Claude Code, the skill triggers automatically. Agents are spawned via
the `Agent` tool with `isolation: "worktree"` for code-writing roles.

No additional setup needed — the SKILL.md handles orchestration.

## Environment Variables

The scripts support these optional environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `TEAM_DIR` | `.team` | Path to team communication directory |
| `WORKTREE_DIR` | `.worktrees` | Path to git worktrees |
| `MAIN_BRANCH` | auto-detected | Main branch name (main or master) |

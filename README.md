# Agent Team

**Multi-agent orchestration skill for Claude Code & Codex CLI.**

Turn your AI assistant into a full development team with 10 specialized agents that plan, design, implement, test, and document — all coordinated automatically.

```
     You: "Equipe, criem um sistema de autenticacao"
      |
      v
  Orchestrator (Tech Lead)
      |
      +---> Planner -----> requirements.md
      +---> Architect ----> design.md         } Phase 1 (parallel)
      |
      +---> UX Agent -----> ux-spec.md        } Phase 2
      |
      +---> Executor -----> code (worktree)   } Phase 3
      |
      +---> QA Agent -----> test-report.md    }
      +---> Security -----> sec-report.md     } Phase 4 (parallel)
      |
      +---> Context Steward -> vault/*.md     } Phase 5
```

---

## Agents

| Agent | Role | What it does |
|-------|------|--------------|
| **Planner** | Product Manager | Defines requirements, acceptance criteria, priorities |
| **Architect** | Staff Engineer | Defines technical design, ADRs, constraints |
| **UX Agent** | Designer | Defines user flows, states, accessibility |
| **Executor** | Software Engineer | Writes code in isolated git worktrees |
| **QA Agent** | Test Engineer | Tests, validates, reports bugs |
| **Security** | Security Engineer | OWASP review, vulnerability scanning |
| **Infra** | SRE / DevOps | CI/CD, deploy, rollback plans |
| **Compliance** | Data Engineer | GDPR/LGPD, PII handling, data governance |
| **Context Steward** | Knowledge Manager | Maintains Obsidian vault documentation |

---

## Install

### Install both (Claude Code + Codex)

```bash
git clone https://github.com/riickes/SkillAgenteTeam.git .agent-team && bash .agent-team/install.sh && rm -rf .agent-team
```

### Install only Claude Code

```bash
git clone https://github.com/riickes/SkillAgenteTeam.git .agent-team && bash .agent-team/install.sh --claude && rm -rf .agent-team
```

### Install only Codex CLI

```bash
git clone https://github.com/riickes/SkillAgenteTeam.git .agent-team && bash .agent-team/install.sh --codex && rm -rf .agent-team
```

### Manual

```bash
# 1. Clone this repo
git clone https://github.com/riickes/SkillAgenteTeam.git

# 2. Copy skill to your project
mkdir -p your-project/.claude/skills
cp -r SkillAgenteTeam your-project/.claude/skills/agent-team

# 3. Copy Codex agents (optional, for Codex CLI)
cp -r SkillAgenteTeam/agents your-project/.codex-agents
cp SkillAgenteTeam/AGENTS.md your-project/AGENTS.md

# 4. Initialize workspace
cd your-project
bash .claude/skills/agent-team/scripts/init-team.sh
```

### What gets created

```
your-project/
├── .claude/skills/agent-team/   <-- Skill (Claude Code reads this)
├── .codex-agents/               <-- Agent prompts (Codex CLI)
├── AGENTS.md                    <-- Codex config
└── .team/                       <-- Workspace
    ├── board.md                 <-- Task kanban
    ├── context.md               <-- Project knowledge
    ├── decisions.md             <-- Decision log
    ├── agents/                  <-- Agent outputs (per task)
    └── vault/                   <-- Obsidian vault
        ├── MOC-*.md             <-- Maps of Content
        ├── LOG-*.md             <-- Agent changelogs
        ├── TASK-*.md            <-- Requirements (Planner)
        ├── ADR-*.md             <-- Decisions (Architect)
        ├── IMPL-*.md            <-- Code notes (Executor)
        ├── QA-*.md              <-- Test reports (QA)
        ├── SEC-*.md             <-- Findings (Security)
        └── SPRINT-*.md          <-- Sprint overviews
```

---

## Usage

### Claude Code (automatic)

Just talk naturally. The skill triggers on keywords like **"Equipe"**, **"Time"**, agent names, or complex tasks:

```
Equipe, adicionem autenticacao no servidor       --> full pipeline
O botao de login nao funciona                    --> bug fix (Executor + QA)
Rode o Security Agent no runtime                 --> single agent
Planejem o sistema de cache                      --> Planner + Architect only
Refatorem o arquivo OfficeScene.tsx              --> Architect + Executor + QA
```

### Codex CLI

```bash
# Automated pipeline
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh feature "Add auth system"
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh bugfix  "Login button broken"
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh security "Review the server"
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh plan "Cache system design"

# Single agent
bash .claude/skills/agent-team/scripts/run-codex-pipeline.sh agent security-agent "Audit the API"

# Or run manually
codex "Read .codex-agents/planner.md and follow its protocol. Task: Add notifications"
```

---

## How It Works

### Phases

Agents run in **phases**. Within a phase they run **in parallel**. Between phases, **sequentially** (each reads the output of the previous).

| Phase | Agents | Parallel? |
|-------|--------|:---------:|
| 1. Planning | Planner + Architect | Yes |
| 2. Design | UX Agent | Solo |
| 3. Implementation | Executor | Solo (worktree) |
| 4. Validation | QA + Security + Compliance | Yes |
| 5. Close | Orchestrator + Context Steward | Yes |

### Smart Routing

Not every task needs every agent. The Orchestrator decides:

| Task Type | Agents Used |
|-----------|-------------|
| New feature | All (full pipeline) |
| Bug fix | Executor + QA only |
| Refactor | Architect + Executor + QA |
| Security review | Security only |
| Planning | Planner + Architect only |

### Isolation

Code-writing agents (Executor, QA, Infra) work in **git worktrees** — isolated branches that don't touch your main code until the Orchestrator merges.

### Communication

Agents don't talk to each other directly. They communicate through **files in `.team/`**:

```
Planner writes .team/agents/planner/requirements.md
    --> Architect reads it, writes .team/agents/architect/design.md
        --> Executor reads both, writes CODE + .team/agents/executor/notes.md
            --> QA reads requirements + code, writes .team/agents/qa/report.md
```

---

## Obsidian Integration

Every agent creates Obsidian-compatible `.md` files in `.team/vault/` with:
- **YAML frontmatter** (tags, dates, status — filterable in Obsidian)
- **`[[wiki-links]]`** (creates the knowledge graph)
- **Agent changelogs** (`LOG-executor.md`, `LOG-planner.md`, etc.)
- **Maps of Content** (MOC pages for navigation)

Open `.team/vault/` as an Obsidian vault and see the graph grow:

```
         MOC-project
        /     |     \
  TASK-001  BUG-001  SEC-001
   / |  \              |
ADR  UX  IMPL       LOG-security
         |
       QA-001
         |
    LOG-executor --- MOC-agents
```

---

## File Structure

```
SkillAgenteTeam/
├── SKILL.md                           # Main orchestrator (Claude Code entry point)
├── AGENTS.md                          # Codex CLI entry point
├── TUTORIAL.md                        # Full tutorial (pt-BR)
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
├── scripts/
│   ├── init-team.sh                   # Initialize .team/ workspace
│   ├── create-worktree.sh             # Create isolated git worktree
│   ├── merge-work.sh                  # Merge agent branch to main
│   └── run-codex-pipeline.sh          # Automated Codex CLI pipeline
├── references/
│   ├── communication-protocol.md      # How agents communicate
│   ├── obsidian-vault.md              # Obsidian vault conventions
│   └── codex-adapter.md              # Multi-framework adapter guide
├── install.sh                         # One-command installer
└── LICENSE
```

---

## Compatibility

| Platform | Status | How |
|----------|:------:|-----|
| Claude Code (CLI) | **Full** | Automatic orchestration via skill |
| Claude Code (Desktop) | **Full** | Same as CLI |
| Claude Code (VS Code) | **Full** | Same as CLI |
| Codex CLI (OpenAI) | **Manual** | Via `run-codex-pipeline.sh` or manual commands |
| Any agent framework | **Portable** | Agent prompts are plain markdown |

---

## License

MIT - [@riickes](https://instagram.com/riickes)

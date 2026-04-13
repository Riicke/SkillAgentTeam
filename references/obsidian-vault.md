# Obsidian Vault Convention

All agent outputs live in a **single flat folder** (`.team/vault/`) so Obsidian's
graph view connects everything into a knowledge brain.

## File Naming

Every file follows the pattern: `PREFIX-NNN-slug.md`

| Agent           | Prefix  | Example                              |
|-----------------|---------|--------------------------------------|
| Planner         | `TASK`  | `TASK-001-notification-system.md`    |
| Architect       | `ADR`   | `ADR-001-zustand-store.md`           |
| UX Agent        | `UX`    | `UX-001-notification-bubble.md`      |
| Executor        | `IMPL`  | `IMPL-001-notification-store.md`     |
| QA Agent        | `QA`    | `QA-001-notification-tests.md`       |
| Security Agent  | `SEC`   | `SEC-001-cors-wildcard.md`           |
| Infra Agent     | `INFRA` | `INFRA-001-ci-pipeline.md`           |
| Compliance      | `COMP`  | `COMP-001-pii-audit.md`             |
| Context Steward | `CTX`   | `CTX-001-project-overview.md`        |
| Orchestrator    | `SPRINT`| `SPRINT-001-auth-feature.md`         |
| Bug reports     | `BUG`   | `BUG-001-click-handler.md`           |

**Numbering**: IDs are global and auto-increment across the whole vault.
Check the highest existing number before creating a new file.

## Frontmatter (YAML)

Every file starts with YAML frontmatter for Obsidian metadata and filtering:

```yaml
---
id: TASK-001
agent: planner
date: 2026-04-01
project: avatar-hq
task: TASK-001
status: done
tags:
  - agent/planner
  - type/task
  - project/avatar-hq
  - sprint/001
related:
  - "[[ADR-001-zustand-store]]"
  - "[[UX-001-notification-bubble]]"
---
```

### Required Fields
- `id`: The file's own ID (matches filename prefix)
- `agent`: Which agent created this (planner, architect, ux, executor, qa, security, infra, compliance, context-steward, orchestrator)
- `date`: Creation date (YYYY-MM-DD)
- `project`: Project slug
- `status`: draft | in-progress | done | blocked | superseded
- `tags`: Array of hierarchical tags for Obsidian filtering

### Tag Hierarchy

```
agent/          → agent/planner, agent/executor, agent/qa ...
type/           → type/task, type/adr, type/implementation, type/bug, type/security ...
project/        → project/avatar-hq, project/my-app ...
sprint/         → sprint/001, sprint/002 ...
status/         → status/done, status/blocked ...
priority/       → priority/p0, priority/p1, priority/p2 ...
```

## Wiki-Links

Use Obsidian `[[wiki-links]]` to connect documents. This is what builds the graph.

### Mandatory Links
Every document MUST link to:
1. **Its parent task**: `[[TASK-001-notification-system]]`
2. **The agent's changelog**: `[[LOG-executor]]`
3. **Documents it depends on** (inputs it read)
4. **Documents that depend on it** (outputs it enables)

### Link Patterns

```markdown
> 🤖 Created by [[LOG-executor|Executor Agent]] for [[TASK-001-notification-system]]
> Based on [[ADR-001-zustand-store]] | Validated by [[QA-001-notification-tests]]
```

Use `[[FILE|Display Text]]` for readable links:
- `[[LOG-planner|Planner Agent]]`
- `[[TASK-001-notification-system|Task #001]]`
- `[[ADR-001-zustand-store|ADR: Zustand Store]]`

### Cross-Reference Section

Every document ends with a `## Related` section:

```markdown
## Related

| Relation    | Link                                  |
|-------------|---------------------------------------|
| Task        | [[TASK-001-notification-system]]      |
| Depends on  | [[ADR-001-zustand-store]]             |
| Enables     | [[QA-001-notification-tests]]         |
| Agent Log   | [[LOG-executor]]                      |
| Sprint      | [[SPRINT-001-auth-feature]]           |
```

## Agent Changelogs (LOG files)

Each agent maintains a running changelog: `LOG-{role}.md`

```markdown
---
agent: executor
type: changelog
tags:
  - agent/executor
  - type/changelog
---

# Executor Agent — Changelog

## 2026-04-01 — [[TASK-001-notification-system|Notification System]]
- Created [[IMPL-001-notification-store]]
- Modified: `src/store/useNotificationStore.ts`, `src/office/AgentAvatar.tsx`
- Branch: `agent/executor/task-001`
- Status: ✅ done

## 2026-04-01 — [[BUG-001-click-handler|Click Handler Bug]]
- Created [[IMPL-002-avatar-click-handler]]
- Found 3 bugs, proposed fixes for all
- Branch: `agent/executor/bug-001`
- Status: ✅ done
```

Changelogs are **append-only** — new entries go at the top (newest first).

## Map of Content (MOC)

The Context Steward creates MOC pages that serve as navigation hubs:

### `MOC-projects.md` — All projects
```markdown
# Projects

## [[MOC-avatar-hq|AvatarHQ]]
- Status: active
- Agents: 5 active
- Recent: [[TASK-001-notification-system]], [[BUG-001-click-handler]]
```

### `MOC-{project}.md` — Project overview
```markdown
# AvatarHQ — Map of Content

## Tasks
- [[TASK-001-notification-system]] — ✅ done
- [[TASK-002-auth-system]] — 🔄 in-progress

## Architecture Decisions
- [[ADR-001-zustand-store]] — active
- [[ADR-002-websocket-auth]] — active

## Bugs
- [[BUG-001-click-handler]] — ✅ fixed

## Security
- [[SEC-001-cors-wildcard]] — ⚠️ open
```

### `MOC-agents.md` — All agent activity
```markdown
# Agent Activity

| Agent    | Log                              | Last Active | Tasks |
|----------|----------------------------------|-------------|-------|
| Planner  | [[LOG-planner\|Changelog]]       | 2026-04-01  | 3     |
| Executor | [[LOG-executor\|Changelog]]      | 2026-04-01  | 5     |
| QA       | [[LOG-qa\|Changelog]]            | 2026-04-01  | 4     |
```

## Sprint Pages

The Orchestrator creates a sprint page for each coordinated task:

```markdown
---
id: SPRINT-001
agent: orchestrator
date: 2026-04-01
project: avatar-hq
status: done
tags:
  - agent/orchestrator
  - type/sprint
  - project/avatar-hq
---

# SPRINT-001: Notification System

## Pipeline
| Phase | Agent | Status | Output |
|-------|-------|--------|--------|
| Planning | [[LOG-planner\|Planner]] | ✅ | [[TASK-001-notification-system]] |
| Architecture | [[LOG-architect\|Architect]] | ✅ | [[ADR-001-zustand-store]] |
| Design | [[LOG-ux\|UX Agent]] | ✅ | [[UX-001-notification-bubble]] |
| Implementation | [[LOG-executor\|Executor]] | ✅ | [[IMPL-001-notification-store]] |
| QA | [[LOG-qa\|QA Agent]] | ✅ | [[QA-001-notification-tests]] |

## Timeline
- 2026-04-01 09:00 — Sprint created
- 2026-04-01 09:05 — Phase 1 complete
- 2026-04-01 09:15 — Phase 3 complete
- 2026-04-01 09:30 — All validations passed, merged
```

## Graph Optimization Tips

For a rich Obsidian graph:

1. **Every file links to at least 3 other files** — task, agent log, and one peer
2. **Use tags consistently** — the tag hierarchy enables powerful filtering
3. **MOC pages are hubs** — they connect clusters of related notes
4. **Agent logs are spines** — they thread all of one agent's work together
5. **Sprint pages are bridges** — they connect agents who worked on the same task
6. **Bidirectional links** — if A links to B, B should link back to A

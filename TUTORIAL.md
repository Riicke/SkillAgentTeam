# Tutorial — Agent Team

## Como funciona (visão geral)

Você tem uma **equipe de 10 agentes de IA**. Cada um tem uma função
específica, como numa empresa real de software:

```
  VOCÊ (dono do projeto)
    │
    ▼
  ORCHESTRATOR (Tech Lead)  ← Este é o "gerente", roda automaticamente
    │
    ├──► Planner (PM)        — define O QUE fazer
    ├──► Architect (Staff)   — define COMO fazer
    ├──► UX Agent (Designer) — define como o USUÁRIO interage
    ├──► Executor (Dev)      — ESCREVE o código
    ├──► QA Agent (Tester)   — TESTA o código
    ├──► Security (SecEng)   — VERIFICA segurança
    ├──► Infra (DevOps)      — faz DEPLOY
    ├──► Compliance (Legal)  — verifica DADOS e regras
    └──► Context Steward     — DOCUMENTA tudo no Obsidian
```

---

## Eles rodam simultaneamente?

**Sim e não.** Depende da fase:

```
FASE 1 ─ PLANEJAMENTO
  ┌─────────────┐   ┌──────────────┐
  │   Planner   │   │  Architect   │   ← rodam EM PARALELO
  │ (o que)     │   │  (como)      │
  └──────┬──────┘   └──────┬───────┘
         │                 │
         └────────┬────────┘
                  ▼
FASE 2 ─ DESIGN
  ┌─────────────┐
  │  UX Agent   │   ← roda SOZINHO (precisa ler fase 1)
  └──────┬──────┘
         ▼
FASE 3 ─ IMPLEMENTAÇÃO
  ┌─────────────┐
  │  Executor   │   ← roda SOZINHO em git worktree isolado
  │  (código)   │
  └──────┬──────┘
         ▼
FASE 4 ─ VALIDAÇÃO
  ┌──────────┐  ┌──────────┐  ┌────────────┐
  │ QA Agent │  │ Security │  │ Compliance │  ← rodam EM PARALELO
  └────┬─────┘  └────┬─────┘  └─────┬──────┘
       │              │              │
       └──────────────┼──────────────┘
                      ▼
FASE 5 ─ MERGE
  ┌──────────────┐   ┌─────────────────┐
  │ Orchestrator │   │ Context Steward │   ← finalizam
  │ (merge)      │   │ (documenta)     │
  └──────────────┘   └─────────────────┘
```

**Regra**: dentro da mesma fase = paralelo. Entre fases = sequencial.

Cada agente **lê o output dos anteriores** e **escreve o seu** para o próximo.

---

## Um joga para o outro?

Sim. É uma **cadeia**. Cada agente produz um documento que o próximo consome:

```
Planner escreve → requirements.md
                      │
Architect lê requirements, escreve → design.md
                                          │
UX Agent lê requirements + design, escreve → ux-spec.md
                                                  │
Executor lê TUDO acima, escreve → CÓDIGO + implementation-notes.md
                                                         │
QA Agent lê requirements + código, escreve → test-report.md
                                                      │
Security lê código, escreve → security-report.md
                                          │
Orchestrator lê TODOS os reports → decide merge ou corrigir
                                          │
Context Steward lê tudo → atualiza vault Obsidian
```

A comunicação toda acontece por **arquivos na pasta `.team/`**:

```
.team/
├── board.md           ← Kanban (quem está fazendo o quê)
├── agents/
│   ├── planner/requirements.md      ← Output do Planner
│   ├── architect/design.md          ← Output do Architect
│   ├── ux/ux-spec.md               ← Output do UX
│   ├── executor/implementation.md   ← Output do Executor
│   ├── qa/test-report.md           ← Output do QA
│   └── security/security-report.md ← Output do Security
└── vault/                           ← Obsidian vault (documentação permanente)
```

---

## Passo a passo para começar

### Passo 1 — Inicialize o workspace (só na primeira vez)

```bash
bash .claude/skills/agent-team/scripts/init-team.sh
```

Isso cria a pasta `.team/` com o board, vault Obsidian e logs de cada agente.
**Você já fez isso** no AvatarHQ.

### Passo 2 — Peça algo ao Claude

Abra o Claude Code no seu projeto e fale normalmente. O Orchestrator
ativa automaticamente quando detecta certas frases.

### Passo 3 — Acompanhe no Obsidian

Abra `.team/vault/` como vault no Obsidian e veja o grafo crescer.

---

## 6 Modos de Uso

### Modo 1: Pipeline Completo (feature nova)

**Quando usar**: Funcionalidade nova, complexa, com UI.

```
Você diz:
  "Equipe, preciso de um sistema de notificações.
   O avatar deve mostrar um badge quando receber mensagem."

O que acontece:
  1. Orchestrator analisa → classifica como "New Feature"
  2. Fase 1: Planner + Architect rodam em paralelo
  3. Fase 2: UX Agent define a interface
  4. Fase 3: Executor implementa em branch isolada
  5. Fase 4: QA + Security validam em paralelo
  6. Fase 5: Merge + Context Steward documenta

Resultado:
  - Código implementado em branch separada
  - 6+ documentos no vault Obsidian
  - Tudo linkado e rastreável
```

### Modo 2: Pipeline Curto (bug fix)

**Quando usar**: Algo quebrou, precisa corrigir.

```
Você diz:
  "O botão de fala do avatar não responde ao click."

O que acontece:
  1. Orchestrator analisa → classifica como "Bug Fix"
  2. PULA Fase 1 e 2 (não precisa planejar um bug fix)
  3. Fase 3: Executor investiga e corrige
  4. Fase 4: QA valida a correção
  5. Fase 5: Merge

Resultado:
  - Bug diagnosticado e corrigido
  - BUG-xxx.md + QA-xxx.md no vault
```

### Modo 3: Agente Direto (shortcut)

**Quando usar**: Você sabe exatamente qual agente quer.

```
Você diz:                          O que roda:
  "Rode o Security Agent"         → Só Security
  "Rode o QA nesse código"        → Só QA
  "Rode o Architect para cache"   → Só Architect
  "Analise a segurança"           → Só Security
  "Planeje o sistema de auth"     → Só Planner + Architect
```

### Modo 4: Refactor

**Quando usar**: Código funciona mas precisa melhorar.

```
Você diz:
  "Refatorem o OfficeScene.tsx, está muito grande."

O que acontece:
  1. Architect define como dividir
  2. Executor implementa a refatoração
  3. QA garante que nada quebrou
```

### Modo 5: Review de Segurança

**Quando usar**: Antes de deploy ou auditoria.

```
Você diz:
  "Equipe, revisem a segurança do runtime inteiro."

O que acontece:
  1. Security faz varredura completa
  2. Compliance verifica dados e LGPD
  3. (opcional) QA testa as correções
```

### Modo 6: Só Planejamento

**Quando usar**: Quer pensar antes de fazer.

```
Você diz:
  "Planejem um sistema de plugins para os avatares.
   Não implementem ainda, só o plano."

O que acontece:
  1. Planner define requirements
  2. Architect define arquitetura
  3. PARA. Ninguém implementa.

Resultado:
  - TASK-xxx.md + ADR-xxx.md no vault
  - Pronto para você revisar antes de mandar executar
```

---

## Isolamento: como eles não se atrapalham

### Agentes que NÃO escrevem código
Planner, Architect, UX, Security, Compliance, Context Steward

Eles só leem o código e escrevem documentos na pasta `.team/`.
Cada um escreve **só na sua pasta**. Não tocam nos arquivos do projeto.

### Agentes que ESCREVEM código
Executor, QA, Infra

Eles trabalham em **git worktrees** (cópias isoladas do repo):

```
Projeto principal (main)
  │
  ├── .worktrees/
  │   ├── agent-executor-task-001/    ← Executor trabalha aqui
  │   │   └── (cópia completa do repo na branch agent/executor/task-001)
  │   │
  │   └── agent-qa-task-001/          ← QA trabalha aqui
  │       └── (cópia completa do repo na branch agent/qa/task-001)
  │
  └── src/ (intocado até o merge final)
```

Quando tudo está validado, o Orchestrator faz merge das branches.

---

## Frases que ativam o skill

| Frase                                    | Ação                          |
|------------------------------------------|-------------------------------|
| "Equipe, ..."                            | Pipeline completo             |
| "Time, precisamos de..."                 | Pipeline completo             |
| "Crie/Adicione/Implemente [feature]"     | Pipeline completo             |
| "Corrige/Fixa [bug]"                     | Pipeline curto (Executor+QA)  |
| "Rode o [nome do agente]"               | Agente direto                 |
| "Analise a segurança"                    | Security direto               |
| "Planeje [algo]"                         | Planner + Architect           |
| "Refatore [algo]"                        | Architect + Executor + QA     |
| "Faça deploy de..."                      | Infra + Executor              |
| "Revise compliance de..."               | Compliance + Security         |

---

## O que cada agente produz no Obsidian

Depois de cada tarefa, o vault ganha novos arquivos:

```
vault/
├── SPRINT-001-notificacoes.md      ← Orchestrator (visão geral da tarefa)
├── TASK-001-notificacoes.md        ← Planner (requirements)
├── ADR-001-zustand-store.md        ← Architect (decisão técnica)
├── UX-001-notification-bubble.md   ← UX Agent (spec de interface)
├── IMPL-001-notification-store.md  ← Executor (o que foi implementado)
├── QA-001-notification-tests.md    ← QA (relatório de testes)
├── SEC-001-xss-check.md           ← Security (findings)
├── LOG-planner.md                  ← Changelog do Planner (atualizado)
├── LOG-executor.md                 ← Changelog do Executor (atualizado)
├── MOC-myemployees-avatarhq.md     ← Context Steward (índice atualizado)
└── ...
```

No Obsidian Graph View, isso aparece como:

```
         MOC-avatar-hq
        ╱      │      ╲
  TASK-001   BUG-001   SEC-001
   ╱  │  ╲              │
ADR  UX  IMPL         LOG-security
         │
       QA-001
         │
    LOG-executor ─── MOC-agents
```

Cada nó é clicável. Cada link é rastreável.

---

## Resumo rápido

| Pergunta                         | Resposta                                  |
|----------------------------------|-------------------------------------------|
| Rodam simultaneamente?           | Sim, dentro da mesma fase                 |
| Um joga para o outro?            | Sim, via arquivos na pasta `.team/`       |
| Precisam de git?                 | Sim, para worktrees (agentes que codam)   |
| Posso rodar só 1 agente?         | Sim, é só pedir pelo nome                 |
| Posso rodar no Codex também?     | Sim, veja `references/codex-adapter.md`   |
| Onde vejo tudo?                  | Obsidian vault em `.team/vault/`          |
| Eles mexem no meu código direto? | Não, trabalham em branch isolada          |
| Quem decide o merge?             | O Orchestrator, depois que QA aprova      |

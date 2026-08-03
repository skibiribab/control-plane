# E10 · Expansion backlog

## Parent issue

**Title:** `E10 · Expansion backlog`
**Labels:** `ai/epic`, `ai/backlog`

### Context
The brainstorm produced ~90 workflow ideas across 13 domains (see the session plan:
`issue-*`, `pr-*`, `repo-*`, `ops-*`, `release-*`, `security-*`, `hygiene-*`, `kb-*`,
`ai-*`). This epic governs how the next wave is chosen and built.

### Goal
Adopt the highest-value workflows next, each following the E01 conventions.

### Children

| ID | Title | Status |
|---|---|---|
| E10-1 | Phase-2 shortlist decision | open |
| E10-2 | Per-domain adoption epics | open |

---

## Child issues

### E10-1 · Phase-2 shortlist decision

**Context:** not all ~90 ideas are worth building now.
**Goal:** a scored shortlist of the next workflows to adopt.

**Tasks**
- [ ] Score candidates on cost vs value (setup, AI complexity, maintenance, risk)
- [ ] Candidates to evaluate: `repo-deps`, `ops-investigate`, `release-ci-flake`, `security-secrets`, `issue-duplicates`, `issue-stale`, `pr-update-base`, `repo-todo-sweep`, `ops-deploy-check`
- [ ] Record the decision + rationale in this issue

**Acceptance criteria**
- [ ] Shortlist has explicit winners + rejected-with-reason entries

**Depends on:** E01, E09
**Labels:** `ai/backlog`

### E10-2 · Per-domain adoption epics

**Context:** each adopted workflow must follow the same contract.
**Goal:** one epic per adopted domain, following the E01 conventions.

**Tasks**
- [ ] For each adopted domain, create an epic following the E01 template
- [ ] Each new stage: reusable + caller entry + conventions compliance
- [ ] Register each new stage in README + chain diagram

**Acceptance criteria**
- [ ] Every new stage conforms to `docs/workflow-conventions.md`

**Depends on:** E10-1, E01
**Labels:** `ai/backlog`

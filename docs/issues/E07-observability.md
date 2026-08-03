# E07 · Observability

## Parent issue

**Title:** `E07 · Observability`
**Labels:** `ai/epic`, `ai/ops`

### Context
You can't trust an autonomous plane you can't inspect. Every run must leave a
trace and every repo must have a readable status.

### Goal
Anyone can see what the plane did, why, and at what cost.

### Children

| ID | Title | Status |
|---|---|---|
| E07-1 | Structured run logging | open |
| E07-2 | Per-repo status issue | open |
| E07-3 | Plane health checks | open |

---

## Child issues

### E07-1 · Structured run logging

**Context:** run summaries are ephemeral; decisions need to be auditable.
**Goal:** each run emits structured logs: inputs, AI output, actions, cost.

**Tasks**
- [ ] Log format (inputs, AI output, actions taken, cost)
- [ ] Attach logs to the run summary and optionally a status issue
- [ ] Retain history beyond the run UI

**Acceptance criteria**
- [ ] Any run can be reconstructed from its log

**Depends on:** E01-1
**Labels:** `ai/ops`

### E07-2 · Per-repo status issue

**Context:** a repo's backlog/in-flight/stuck state is otherwise scattered.
**Goal:** an auto-updated status issue per repo.

**Tasks**
- [ ] Status issue template: backlog / in-progress / stuck / done + history
- [ ] Auto-update after each stage run
- [ ] Link from README onboarding

**Acceptance criteria**
- [ ] Status issue reflects repo state after every run

**Depends on:** E01-1
**Labels:** `ai/ops`

### E07-3 · Plane health checks

**Context:** the plane itself can fail silently (bad inputs, action outages).
**Goal:** our own workflows failing gets flagged.

**Tasks**
- [ ] Detect broken/failing runs across target repos
- [ ] Notify + log health status
- [ ] Feed future `hygiene-workflow-health` work

**Acceptance criteria**
- [ ] A silently failing stage surfaces within one cycle

**Depends on:** E01-1
**Labels:** `ai/ops`

# E05 · AI invocation layer

## Parent issue

**Title:** `E05 · AI invocation layer`
**Labels:** `ai/epic`, `ai/ai`

### Context
Every stage currently carries a `# <stage>-gh` marker stub. This epic replaces the
stubs with real AI calls under one contract.

### Goal
All 8 stages run real AI end-to-end, idempotently and within a cost budget.

### Children

| ID | Title | Status |
|---|---|---|
| E05-1 | AI contract spec | open |
| E05-2 | Wire all stages | open |
| E05-3 | Idempotency & cost guard | open |

---

## Child issues

### E05-1 · AI contract spec

**Context:** 8 different AI calls need one shape or they'll drift apart.
**Goal:** a written contract for input JSON, expected output, and failure semantics.

**Tasks**
- [ ] Define JSON input per stage (repo, issue, pr, stage, context)
- [ ] Define expected outputs per stage (actions + entities: comment, issue, PR, review)
- [ ] Define retry/failure semantics and per-run cost budget
- [ ] Publish as `docs/ai-contract.md`

**Acceptance criteria**
- [ ] Contract covers all 8 stages; outputs map to workflow steps

**Depends on:** E01-2
**Labels:** `ai/ai`

### E05-2 · Wire all stages

**Context:** stubs are placeholders; the real work is the AI call.
**Goal:** every `# <stage>-gh` stub replaced by the real invocation honoring the contract.

**Tasks**
- [ ] Replace each stub step across the 8 reusables
- [ ] Ensure outputs feed the next stage (handoffs)
- [ ] Keep the `# <stage>-gh` markers as stable identifiers

**Acceptance criteria**
- [ ] Every stage runs real AI end-to-end

**Depends on:** E05-1, E02, E03
**Labels:** `ai/ai`

### E05-3 · Idempotency & cost guard

**Context:** reruns must not duplicate work or blow the budget.
**Goal:** skip already-done work; cap cost per run.

**Tasks**
- [ ] Pre-checks: "already has AI plan comment / PR / review?"
- [ ] Max tokens/cost per run; hard stop with a clear message
- [ ] Per-repo run lock to prevent concurrent duplicate runs

**Acceptance criteria**
- [ ] Reruns don't duplicate work or exceed budget

**Depends on:** E05-2
**Labels:** `ai/ai`

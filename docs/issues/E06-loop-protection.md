# E06 · Loop protection & guardrails

## Parent issue

**Title:** `E06 · Loop protection & guardrails`
**Labels:** `ai/epic`, `ai/safety`

### Context
An autonomous loop must be provably unable to spin forever. Attempts, caps, and
stuck-detection are the three layers that make it safe.

### Goal
The plane can never loop forever; stuck work always surfaces.

### Children

| ID | Title | Status |
|---|---|---|
| E06-1 | Unified attempts tracking | open |
| E06-2 | Global caps | open |
| E06-3 | Stuck detection | open |

---

## Child issues

### E06-1 · Unified attempts tracking

**Context:** `pr-fix` and `pr-janitor` must agree on how many attempts happened.
**Goal:** one source of truth for attempt counts.

**Tasks**
- [ ] Single counter mechanism (`<!-- ai-fix-attempt -->` comment markers)
- [ ] Shared helper/expression used by `pr-fix` and `pr-janitor`
- [ ] Expose `max_attempts` input consistently

**Acceptance criteria**
- [ ] One counting mechanism; no second format anywhere

**Depends on:** E03-2
**Labels:** `ai/safety`

### E06-2 · Global caps

**Context:** unbounded concurrency or open PRs can overwhelm a repo.
**Goal:** enforce repo-wide ceilings and fail fast.

**Tasks**
- [ ] Max open AI PRs per repo
- [ ] Max runs/day per repo
- [ ] Clear failure messages when a cap is hit

**Acceptance criteria**
- [ ] Caps enforced; overruns logged, never silent

**Depends on:** E01-1
**Labels:** `ai/safety`

### E06-3 · Stuck detection

**Context:** some things fail slowly, not loudly.
**Goal:** work with no progress for X days is routed to the janitor.

**Tasks**
- [ ] No-progress scan (X days) across open AI PRs/issues
- [ ] Route detected work to `pr-janitor`
- [ ] Config for X per repo

**Acceptance criteria**
- [ ] Stalled work surfaces within X days

**Depends on:** E03-4
**Labels:** `ai/safety`

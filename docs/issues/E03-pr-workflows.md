# E03 · pr-* — implement, fix, review, janitor

## Parent issue

**Title:** `E03 · pr-* — implement, fix, review, janitor`
**Labels:** `ai/epic`, `ai/pr`

### Context
Issues become PRs that either close cleanly or get parked safely. Four PR-focused
stages cover the whole lifecycle, with a janitor as the backstop.

### Goal
PRs flow from issues, get fixed/reviewed within `max_attempts`, and never loop forever.

### Children

| ID | Title | Status |
|---|---|---|
| E03-1 | pr-create | open |
| E03-2 | pr-fix | open |
| E03-3 | pr-review | open |
| E03-4 | pr-janitor | open |

---

## Child issues

### E03-1 · pr-create

**Context:** a picked issue (`ai/in-progress`) needs an implementation.
**Goal:** from `issue_number`, open a draft PR linking the issue.

**Tasks**
- [ ] Inputs `repo`, `issue_number`
- [ ] Branch `ai/<issue>-<slug>`
- [ ] `# pr-create-gh` marker → implement + tests
- [ ] Open draft PR linking the issue; comment PR link on the issue

**Acceptance criteria**
- [ ] Draft PR opens and CI runs
- [ ] Issue shows PR link + `ai/in-progress`

**Depends on:** E02-4
**Labels:** `ai/pr`

### E03-2 · pr-fix

**Context:** a PR with failing checks needs bounded repair.
**Goal:** push fixes until checks pass or `max_attempts` is exhausted.

**Tasks**
- [ ] Inputs `repo`, `pr_number`, `max_attempts`
- [ ] Count attempts from `<!-- ai-fix-attempt -->` comments
- [ ] `# pr-fix-gh` marker → read CI failures, fix, push, update PR body
- [ ] Post an attempt marker per fix run; stop when exhausted; hand off to janitor

**Acceptance criteria**
- [ ] Fixes push up to `max_attempts`, then stop cleanly
- [ ] On exhaustion, `pr-janitor` can take over

**Depends on:** E03-1, E06-1
**Labels:** `ai/pr`

### E03-3 · pr-review

**Context:** a green PR still needs scrutiny.
**Goal:** post a review only when checks pass, flag issues, approve only if configured + confident.

**Tasks**
- [ ] Inputs `repo`, `pr_number`, optional `approve`
- [ ] Gate on green checks
- [ ] `# pr-review-gh` marker → review summary; approve only if `approve=true` and confident
- [ ] Skip re-review

**Acceptance criteria**
- [ ] Review posted only after green checks; no double reviews
- [ ] Issues flagged, never silently approved

**Depends on:** E03-1/E03-2
**Labels:** `ai/pr`

### E03-4 · pr-janitor

**Context:** PRs past `max_attempts` would otherwise loop or rot forever.
**Goal:** comment + close the stuck PR and open a `ai/stuck` tracking issue.

**Tasks**
- [ ] Inputs `repo`, optional `pr_number` (empty = scan open PRs)
- [ ] Count attempts from `<!-- ai-fix-attempt -->` comments; compare to `max_attempts`
- [ ] Comment summary + close PR + open tracking issue referencing the original issue
- [ ] Clear `ai/in-progress`; label tracking issue `ai/stuck`

**Acceptance criteria**
- [ ] Nothing stays in an infinite fix loop
- [ ] Every AI-closed PR has a tracking issue

**Depends on:** E03-2, E06-1
**Labels:** `ai/pr`, `ai/stuck`

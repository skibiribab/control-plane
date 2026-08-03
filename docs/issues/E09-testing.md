# E09 · Testing & validation

## Parent issue

**Title:** `E09 · Testing & validation`
**Labels:** `ai/epic`, `ai/testing`

### Context
The chain is only worth trusting after it is proven. Validation must cover syntax,
the full chain, and failure modes.

### Goal
All 8 stages validated locally and end-to-end; failure injection proves the janitor works.

### Children

| ID | Title | Status |
|---|---|---|
| E09-1 | Local validation | open |
| E09-2 | End-to-end run | open |
| E09-3 | Failure injection | open |

---

## Child issues

### E09-1 · Local validation

**Context:** broken YAML/syntax fails late and loudly in Actions.
**Goal:** all 8 reusables + caller pass local dry-run/`act` validation.

**Tasks**
- [ ] Validate all workflow files parse
- [ ] `act` dry-run of each stage with realistic inputs
- [ ] Wire validation into CI on this repo

**Acceptance criteria**
- [ ] Every workflow passes; CI enforces it

**Depends on:** E01-1
**Labels:** `ai/testing`

### E09-2 · End-to-end run

**Context:** stages must chain correctly in a real repo.
**Goal:** a throwaway repo run through all 8 stages with each handoff asserted.

**Tasks**
- [ ] Create throwaway test repo with the caller installed
- [ ] Run the chain: gaps → epic → review → pick → create → fix/review → janitor
- [ ] Assert handoffs (issue_number → pr_number) and labels

**Acceptance criteria**
- [ ] Full chain completes; each handoff verified

**Depends on:** E02, E03, E04
**Labels:** `ai/testing`

### E09-3 · Failure injection

**Context:** the janitor only matters if failure is exercised.
**Goal:** prove the janitor catches broken PRs, stuck loops, and bad inputs.

**Tasks**
- [ ] Broken PR (failing checks) → assert bounded `pr-fix`
- [ ] Stuck loop (attempts ≥ max) → assert close + tracking issue
- [ ] Bad dispatch inputs (missing `issue_number`) → assert clean failure message

**Acceptance criteria**
- [ ] Janitor catches each case; no infinite loop in any scenario

**Depends on:** E03-4, E04
**Labels:** `ai/testing`

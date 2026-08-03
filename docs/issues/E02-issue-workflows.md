# E02 · issue-* — backlog & planning

## Parent issue

**Title:** `E02 · issue-* — backlog & planning`
**Labels:** `ai/epic`, `ai/issue`

### Context
The chain starts with a clean, prioritized backlog. Four issue-focused stages build it.
Work in order: gaps → epics → review → pick.

### Goal
A healthy backlog: no duplicates, every issue well-formed, and a deterministic picker.

### Children

| ID | Title | Status |
|---|---|---|
| E02-1 | issue-find-gaps | open |
| E02-2 | issue-create-epic | open |
| E02-3 | issue-review | open |
| E02-4 | issue-pick-task | open |

---

## Child issues

### E02-1 · issue-find-gaps

**Context:** repo weaknesses that are not covered by any existing issue go unnoticed.
**Goal:** scan repo state vs open issues and open `ai/gap` issues for uncovered weaknesses.

**Tasks**
- [ ] Inputs `repo`, optional `scope` paths
- [ ] Gather repo state (structure, recent history, tooling) + open issues
- [ ] `# issue-find-gaps-gh` marker → AI dedupes and emits gap issues with evidence + acceptance criteria
- [ ] Label each gap issue `ai/gap`

**Acceptance criteria**
- [ ] Running twice creates no duplicate gap issues
- [ ] Every gap issue cites evidence and has acceptance criteria

**Depends on:** E01-1
**Labels:** `ai/issue`, `ai/gap`

### E02-2 · issue-create-epic

**Context:** big goals need decomposition into reviewable children.
**Goal:** from a goal, create a parent issue + template-following child issues.

**Tasks**
- [ ] Inputs `epic_title`, `epic_body`
- [ ] `# issue-create-epic-gh` marker → AI decomposes into children (template-following, with dependencies)
- [ ] Parent body lists children + status table; parent↔child ids back-linked

**Acceptance criteria**
- [ ] Parent + children created; ids back-linked both ways
- [ ] Children follow the shared template (see `docs/issues/index.md`)

**Depends on:** E01-4, E01-1
**Labels:** `ai/issue`, `ai/epic`

### E02-3 · issue-review

**Context:** raw/rough issues need triage before they are pickable.
**Goal:** every open issue gets one AI plan comment; duplicates are flagged, never auto-merged.

**Tasks**
- [ ] Inputs `repo`, optional single `issue_number`
- [ ] `# issue-review-gh` marker → enrich: title, repro/context, acceptance criteria, label suggestions, duplicate flag
- [ ] Skip human-assigned issues unless allowed by config

**Acceptance criteria**
- [ ] Every unplanned issue gets exactly one plan comment
- [ ] Duplicates flagged, not auto-merged

**Depends on:** E01-1
**Labels:** `ai/issue`

### E02-4 · issue-pick-task

**Context:** someone must decide which issue to implement next.
**Goal:** pick the least-ambiguous issue without a PR, deterministically.

**Tasks**
- [ ] Input `repo`
- [ ] Score candidates: has acceptance criteria, no PR, not blocked, not `ai/parked`
- [ ] `# issue-pick-task-gh` marker → pick winner, label `ai/in-progress`, post plan
- [ ] Output `issue_number` for `pr-create`

**Acceptance criteria**
- [ ] Deterministic given the same repo state
- [ ] Never picks parked or stuck issues

**Depends on:** E02-3
**Labels:** `ai/issue`

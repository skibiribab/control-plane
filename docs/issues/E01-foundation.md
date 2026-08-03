# E01 · Foundation — scaffold & workflow conventions

## Parent issue

**Title:** `E01 · Foundation — scaffold & workflow conventions`
**Labels:** `ai/epic`, `ai/foundation`

### Context
`ai-coder` is a control plane of reusable GitHub Actions workflows. Everything else
depends on the skeleton and on one contract every stage obeys.

### Goal
A repo skeleton plus a written convention doc that all 8 stages conform to.

### Children

| ID | Title | Status |
|---|---|---|
| E01-1 | Scaffold repo skeleton | open |
| E01-2 | Workflow contract doc | open |
| E01-3 | README + architecture diagram | open |
| E01-4 | Labels + issue templates | open |

---

## Child issues

### E01-1 · Scaffold repo skeleton

**Context:** repo has only a bare README. Establish the structure for everything else.
**Goal:** a layout where the 8 reusables, caller template, docs and future epics fit.

**Tasks**
- [ ] Create `.github/workflows/` with the 8 reusable stubs (inputs `repo`, `issue_number`, `pr_number`, `max_attempts`; guard `if: github.repository != 'gardusig/ai-coder'`; `# <stage>-gh` marker step)
- [ ] Add `docs/` for conventions + issue tree
- [ ] Add `.gitignore`
- [ ] Add `caller-template.yml`

**Acceptance criteria**
- [ ] Layout matches the plan in `docs/issues/index.md`
- [ ] Every stub parses and passes a dry-run/`act` validation

**Depends on:** none (root)
**Labels:** `ai/foundation`

### E01-2 · Workflow contract doc

**Context:** all 8 reusables must behave identically or the chain breaks.
**Goal:** one `docs/workflow-conventions.md` that every stage can be checked against.

**Tasks**
- [ ] Define input schema (common + per-stage)
- [ ] Define self-guard rule and why `github.repository` is the caller repo
- [ ] Define AI marker convention `# <stage>-gh`
- [ ] Define success/failure/rerun semantics and idempotency
- [ ] Define stage handoff (`issue_number`/`pr_number`)
- [ ] Define attempt-counting rule for fix/janitor

**Acceptance criteria**
- [ ] The 8 stubs conform to the doc (verifiable by checklist in a review)

**Depends on:** E01-1
**Labels:** `ai/foundation`

### E01-3 · README + architecture diagram

**Context:** nobody can adopt the plane without understanding the chain.
**Goal:** a new reader can trigger one manual stage and know what happens next.

**Tasks**
- [ ] Architecture summary + chain diagram
- [ ] Onboarding flow (install caller, set PAT_TOKEN)
- [ ] Secrets overview + link to conventions

**Acceptance criteria**
- [ ] README renders on GitHub; links resolve
- [ ] Onboarding steps work when followed verbatim

**Depends on:** E01-2
**Labels:** `ai/foundation`

### E01-4 · Labels + issue templates

**Context:** issues created by the plane need a consistent taxonomy and shape.
**Goal:** creating an epic auto-offers children with prefilled bodies.

**Tasks**
- [ ] Add labels `ai/gap`, `ai/epic`, `ai/stuck`, `ai/in-progress`, `ai/parked`, `ai/done`
- [ ] Add `.github/ISSUE_TEMPLATES/` for epic + child using the shared template
- [ ] Document parent-child linking guidance

**Acceptance criteria**
- [ ] Labels present; templates available in the Issues UI

**Depends on:** E01-1
**Labels:** `ai/foundation`

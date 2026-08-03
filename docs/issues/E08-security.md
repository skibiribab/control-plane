# E08 · Security & secrets

## Parent issue

**Title:** `E08 · Security & secrets`
**Labels:** `ai/epic`, `ai/security`

### Context
The plane holds a PAT that can write to target repos. Least privilege and no leaks
are non-negotiable.

### Goal
Every workflow scoped to the minimum; nothing secret leaks; tokens rotate.

### Children

| ID | Title | Status |
|---|---|---|
| E08-1 | Permissions blocks | open |
| E08-2 | Self secrets scan | open |
| E08-3 | PAT rotation | open |

---

## Child issues

### E08-1 · Permissions blocks

**Context:** GitHub Actions default to broad permissions without explicit blocks.
**Goal:** every workflow has a minimal top-level `permissions:` block.

**Tasks**
- [ ] Audit all 8 reusables + caller for `permissions:`
- [ ] Use `contents: read` by default; escalate only where writes happen
- [ ] CI check that blocks workflows without permissions

**Acceptance criteria**
- [ ] No workflow runs with unneeded write scope

**Depends on:** E01-1
**Labels:** `ai/security`

### E08-2 · Self secrets scan

**Context:** the plane should be scanned the way it scans others.
**Goal:** run a secrets scan on this repo, wired to CI.

**Tasks**
- [ ] Add a secrets-scan workflow/action on `ai-coder` itself
- [ ] Block merge on findings

**Acceptance criteria**
- [ ] Scan runs on every PR; findings block merge

**Depends on:** E01-1
**Labels:** `ai/security`

### E08-3 · PAT rotation

**Context:** fine-grained PATs expire; forgotten expiry = silent breakage or risk.
**Goal:** expiry reminders + a rotation checklist.

**Tasks**
- [ ] Track PAT expiry (input/doc)
- [ ] Reminder workflow before expiry
- [ ] Rotation checklist in the permissions doc

**Acceptance criteria**
- [ ] Expiring token is flagged before it breaks the plane

**Depends on:** E04-3
**Labels:** `ai/security`

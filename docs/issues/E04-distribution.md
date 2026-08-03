# E04 · Distribution — onboard any repo

## Parent issue

**Title:** `E04 · Distribution — onboard any repo`
**Labels:** `ai/epic`, `ai/infra`

### Context
The plane is only useful if target repos can adopt it quickly and safely.
This epic covers the caller template, the install process, and the secret/permission model.

### Goal
Any repo onboarded in <5 minutes with least-privilege access.

### Children

| ID | Title | Status |
|---|---|---|
| E04-1 | caller-template | open |
| E04-2 | Install process + script | open |
| E04-3 | Permissions & PAT spec | open |

---

## Child issues

### E04-1 · caller-template

**Context:** each target repo needs a thin, single-file entry point to all 8 stages.
**Goal:** one copy-paste file exposes every stage as a manual `workflow_dispatch`.

**Tasks**
- [ ] `caller-template.yml` with 8 jobs, `stage` selector dropdown
- [ ] Pass `repo` (default caller repo), `issue_number`, `pr_number`, `max_attempts` through
- [ ] `secrets: inherit` to forward `PAT_TOKEN`

**Acceptance criteria**
- [ ] Copy-paste install exposes all 8 manual triggers
- [ ] Each job calls `gardusig/ai-coder/...@main`

**Depends on:** E01-2, E02, E03
**Labels:** `ai/infra`

### E04-2 · Install process + script

**Context:** manual copying is error-prone and slow.
**Goal:** an idempotent installer that drops the caller + secrets into a target repo.

**Tasks**
- [ ] `scripts/install-caller.sh` (target repo arg) — idempotent
- [ ] Create branch + PR in the target repo with the caller file
- [ ] Document env/secret setup steps

**Acceptance criteria**
- [ ] Throwaway repo onboarded in <5 min via the documented path

**Depends on:** E04-1
**Labels:** `ai/infra`

### E04-3 · Permissions & PAT spec

**Context:** the PAT is the plane's identity; over-scoping is a security risk.
**Goal:** document the exact PAT scopes and enforce least privilege.

**Tasks**
- [ ] Spec `PAT_TOKEN`: fine-grained, `Contents` + `Issues` read/write on target repos only, expiry set
- [ ] Least-privilege table: which stage needs which permission
- [ ] Rotation + expiry reminder notes

**Acceptance criteria**
- [ ] Doc lists exact scopes; token cannot touch non-target repos

**Depends on:** E01-2
**Labels:** `ai/infra`, `ai/security`

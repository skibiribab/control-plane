# Workflow conventions

Every stage in this repo is a **reusable** workflow (`workflow_call`). Stages never run standalone here — target repos call them through a thin caller. This document is the shared contract they all follow.

## 1. Trigger model

- Reusables use only `on: workflow_call`. No `workflow_dispatch`/`schedule` here.
- Manual/scheduled triggers live in the caller installed per target repo (`caller-template.yml`).
- A caller job calls a reusable with `uses: gardusig/ai-coder/.github/workflows/<stage>.yml@main` and `secrets: inherit`.

## 2. Inputs schema

Common inputs (all reusables):

| Input | Type | Required | Notes |
|---|---|---|---|
| `repo` | string | yes | Target `owner/name` |
| `issue_number` | string | no | Where a single issue is targeted |
| `pr_number` | string | no | Where a single PR is targeted |
| `max_attempts` | number | no (default 3) | Fix/janitor threshold |

Stage-specific inputs add to this (e.g. `epic_title` on `issue-create-epic`, `scope` on `issue-find-gaps`, `approve` on `pr-review`).

Secret (all reusables): `PAT_TOKEN` — fine-grained, `Contents` + `Issues` read/write **only** on the target repo. Passed via `secrets: inherit`; never defined inside the reusable.

## 3. Self-guard

Every job runs `if: github.repository != 'gardusig/ai-coder'`. Inside a reusable, `github.repository` is the **caller** repo, so this guarantees the plane never acts on itself. Add the same guard to any future stage.

## 4. AI marker

Each stage carries an AI marker comment plus a stub step:

```yaml
# ai marker: <stage>-gh
# TODO(ai): <what the stage must do>
- name: AI stub — <stage>
  run: |
    echo "AI_STAGE=<stage>"
```

The marker name is `<stage>-gh` (e.g. `issue-review-gh`, `pr-fix-gh`). When the AI invocation layer lands (see `docs/issues/E05`), the stub step is replaced by the real call honoring the contract — the marker stays as a stable identifier.

## 5. Success / failure / rerun semantics

- Stages must be **rerunnable**: a repeat run must not duplicate comments, issues, or PRs.
- Every state-changing action the AI takes must be idempotent or pre-checked (e.g. "has an AI plan comment already?").
- On failure, the stage exits non-zero; the caller shows a failed run. No retry logic inside the reusable.

## 6. Stage handoff

Stages pass work to the next stage by identifiers:

- `issue-pick-task` → `pr-create`: the **issue_number**.
- `pr-create` → `pr-fix` / `pr-review`: the **pr_number**.
- `pr-fix` → `pr-janitor`: the **pr_number** when `max_attempts` is exhausted.

Handoffs happen via caller inputs; nothing is stored between runs except what lives in the repo itself (issue/PR state).

## 7. Attempt counting

- `pr-fix` counts prior attempts from PR comments starting with `<!-- ai-fix-attempt -->` and stops once `count >= max_attempts`.
- `pr-janitor` uses the same source of truth, closes the PR, and opens a `ai/stuck` tracking issue.
- One counter, one format — do not introduce a second mechanism.

## 8. Permissions

Each workflow sets a minimal top-level `permissions:` block. Prefer `contents: read`; escalate only where a stage genuinely writes (e.g. `pr-create` needs `contents: write` + `pull-requests: write`).

## 9. Labels

| Label | Meaning |
|---|---|
| `ai/gap` | issue opened by `issue-find-gaps` |
| `ai/epic` | parent issue |
| `ai/stuck` | tracking issue opened by `pr-janitor` |
| `ai/in-progress` | issue picked by `issue-pick-task` |
| `ai/parked` | explicitly not to be picked |
| `ai/done` | completed AI work |

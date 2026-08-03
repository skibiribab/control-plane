# ai-coder

Control plane for AI-driven software maintenance. A set of focused, reusable GitHub Actions workflows ("stages") that inspect a repository, plan work, open issues, create PRs, fix them, review them, and clean up anything that gets stuck.

This repo does **not** run logic against itself. It holds the reusable workflows; each target repository installs a thin caller that exposes the stages as manual `workflow_dispatch` buttons.

## The chain

```
issue-find-gaps ──► issue-create-epic ──► issue-review ──► issue-pick-task
                                                              │
                                                              ▼
                                                        pr-create
                                                          │
                                              ┌───────────┴───────────┐
                                              ▼                       ▼
                                          pr-fix                 pr-review
                                              │                       │
                                              └───────────┬───────────┘
                                                          ▼
                                                     pr-janitor
```

| Stage | Job | Marker |
|---|---|---|
| `issue-find-gaps` | weaknesses not covered by existing issues → gap issues | `issue-find-gaps-gh` |
| `issue-create-epic` | parent issue + children from a goal | `issue-create-epic-gh` |
| `issue-review` | triage / plan comments on open issues | `issue-review-gh` |
| `issue-pick-task` | pick least-ambiguous issue without a PR | `issue-pick-task-gh` |
| `pr-create` | issue → implementation → draft PR | `pr-create-gh` |
| `pr-fix` | PR with failing checks → fix + push (bounded) | `pr-fix-gh` |
| `pr-review` | green PR → review comments | `pr-review-gh` |
| `pr-janitor` | stuck PRs → comment + close + tracking issue | `pr-janitor-gh` |

## Layout

```
.github/workflows/
  issue-find-gaps.yml     reusable
  issue-create-epic.yml   reusable
  issue-review.yml        reusable
  issue-pick-task.yml     reusable
  pr-create.yml           reusable
  pr-fix.yml              reusable
  pr-review.yml           reusable
  pr-janitor.yml          reusable
  caller-template.yml     thin caller to install into target repos
docs/
  workflow-conventions.md shared contract every stage follows
  issues/                 epic + child issue tree for building this repo
```

## Onboarding a target repo

1. Copy `.github/workflows/caller-template.yml` into `<target>/.github/workflows/`.
2. Set the `PAT_TOKEN` secret on the target repo (fine-grained, `Contents` + `Issues` read/write on that repo only).
3. Trigger stages from the Actions tab (manual dispatch). Pass `issue_number` / `pr_number` where the stage requires it.

Every reusable workflow is guarded with `if: github.repository != 'gardusig/ai-coder'` so the plane never acts on itself.

## Status

Scaffolding. The AI invocation is intentionally **not wired** — each workflow carries a `# <stage>-gh` marker comment (see `docs/workflow-conventions.md`) where the real AI call goes. The full build plan lives in `docs/issues/`.

# ai-coder

Control plane for AI-driven software maintenance. A set of focused, reusable GitHub Actions workflows — called **stages** — that inspect a repository, plan work, open issues, create PRs, fix them, review them, and clean up anything that gets stuck.

The AI logic is deliberately **not wired yet**. Each workflow carries an `# <stage>-gh` marker comment where the real AI invocation will go. The mechanical plumbing (checkout, self-guard, attempt counting, janitor) already works.

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

## How it works

- **Reusables only.** All 8 stages are `workflow_call` workflows. They never run standalone and have no `schedule`/`workflow_dispatch` of their own — triggers live in the caller installed per target repo.
- **Self-guard.** Every job runs `if: github.repository != 'gardusig/ai-coder'`. Inside a reusable, `github.repository` is the *caller* repo, so the plane can never act on itself.
- **Manual triggers.** Each caller exposes the 8 stages as a manual `workflow_dispatch` run with a `stage` selector plus `issue_number` / `pr_number` / `max_attempts` inputs.
- **Attempt counting.** `pr-fix` counts prior fixes from PR comments starting with `<!-- ai-fix-attempt -->` and stops once `count >= max_attempts`. `pr-janitor` uses the same counter: past the threshold it comments, closes the PR, and opens a `ai/stuck` tracking issue — no infinite loops.
- **AI markers.** Each stage has a stub step whose comment identifies the future AI call: `# ai marker: <stage>-gh`. When the AI layer lands (see build plan), stubs get replaced by real calls; the markers stay as stable identifiers.
- **Idempotency rule.** Stages must be rerunnable — a repeat run must not duplicate comments, issues, or PRs (pre-check "already has AI plan comment / PR / review").

### Labels

| Label | Meaning |
|---|---|
| `ai/gap` | issue opened by `issue-find-gaps` |
| `ai/epic` | parent (epic) issue |
| `ai/stuck` | tracking issue opened by `pr-janitor` |
| `ai/in-progress` | issue picked by `issue-pick-task` |
| `ai/parked` | explicitly not to be picked |
| `ai/done` | completed AI work |

## Layout

```
.github/workflows/
  issue-find-gaps.yml     reusable stage
  issue-create-epic.yml   reusable stage
  issue-review.yml        reusable stage
  issue-pick-task.yml     reusable stage
  pr-create.yml           reusable stage
  pr-fix.yml              reusable stage
  pr-review.yml           reusable stage
  pr-janitor.yml          reusable stage
  caller-template.yml     thin caller to install into target repos
```

## Onboarding a target repo

1. Copy `.github/workflows/caller-template.yml` into `<target>/.github/workflows/` (rename as you like).
2. Set the `PAT_TOKEN` secret on the target repo — a **fine-grained** token with `Contents` + `Issues` read/write on that repo **only**, with an expiry.
3. From the target repo's Actions tab, run **ai-coder**, pick a `stage`, and fill in `issue_number` / `pr_number` where required.

The caller forwards your secret to the reusable via `secrets: inherit`; the reusable is referenced as `gardusig/ai-coder/.github/workflows/<stage>.yml@main`.

## Build plan

The roadmap is tracked as GitHub issues in this repo — epics `E01`–`E10` (dependency-ordered), each with child issues following a shared template (Context / Goal / Tasks / Acceptance criteria / Depends on):

- `E01` Foundation & conventions · `E02` issue-* workflows · `E03` pr-* workflows · `E04` Distribution · `E05` AI invocation layer · `E06` Loop protection · `E07` Observability · `E08` Security & secrets · `E09` Testing & validation · `E10` Expansion backlog

Start with **#1 (E01)** and work through its children.

## Status

Scaffolding. Reusables + caller + janitor logic are in place; AI calls are stubbed behind `# <stage>-gh` markers. See the build plan issues for what's next.

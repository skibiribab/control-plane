# control-plane

Workflow dispatcher and janitor for the gardusig ecosystem. A **bash-first CLI** (`cli <noun> <verb>`) for repository automation, plus a set of reusable **stage workflows** that inspect repositories, plan work, open issues, create PRs, fix and review them, and clean up anything that gets stuck.

Two halves, one repo:

- **CLI** — runs in Docker images and hosts the shared lint / validation / ops commands that every repo consumes.
- **Stages** — reusable `workflow_call` workflows (the control plane) that act on *other* repos. This repo never acts on itself (self-guard).

## Focus

Three pillars:

- **CLI** — `cli <noun> <verb>` commands (lint / validation / ops) shipped in Docker images.
- **Stages** — reusable dispatch workflows (issue-* → pr-* → janitor) that act on other repos.
- **Docker + release** — the runtime images and tag-driven releases.

## CLI

A lean, bash-first CLI for workflow automation, repository checks, and release orchestration. Every command is a thin wrapper around an existing tool; each command runs in the Docker image that owns its toolchain.

```bash
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0 sh lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0-node md lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0-python yml lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0 git status
```

If a command's tool is missing, `cli` tells you which image to use.

### Images

Alpine-based, versioned tags (no `latest`):

| Tag | Adds | Use for |
| --- | --- | --- |
| `:1.2.0` (`:base-1.2.0`) | git, gh, docker-cli, opencode, shellcheck, actionlint, curl, jq-adjacent core | `sh lint`, `dockerfile lint`, `structure lint`, `git`, `gh`, `docker`, `opencode`, `integration` |
| `:1.2.0-rust` | rust/cargo + lychee | `url`, `rust lint`, `rust test` |
| `:1.2.0-node` | node/npm + markdownlint + jq | `md lint`, `json lint`, `tasks lint`, `typescript lint/test`, `javascript lint/test`, `node` |
| `:1.2.0-python` | python3/pip + codespell, yamllint | `yml lint`, `python lint/test` |
| `:1.2.0-media` | ffmpeg, imagemagick, poppler | `pdf lint`, `png/jpg/... lint`, `mp4/... scan/compress` |
| `:1.2.0-cpp` | gcc/g++/make/cmake/clang-format | `cpp lint/test` |
| `:1.2.0-go` | golang | `go lint/test` |
| `:1.2.0-java` | OpenJDK 21/Maven/Gradle | `java lint/test` |

Every dependency — Alpine base digest, apk packages, static binaries, npm/pip packages — is pinned in `src/docker/runtime/versions.env`.

## Stages (the control plane)

The AI logic is deliberately **not wired yet**. Each workflow carries an `# <stage>-gh` marker comment where the real AI invocation will go. The mechanical plumbing (checkout, self-guard, attempt counting, janitor) already works.

### The chain

```text
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

### How it works

- **Reusables only.** All 8 stages are `workflow_call` workflows. They never run standalone and have no `schedule`/`workflow_dispatch` of their own — triggers live in the caller installed per target repo.
- **Self-guard.** Every job runs `if: github.repository != 'gardusig/control-plane'`. Inside a reusable, `github.repository` is the *caller* repo, so the plane can never act on itself.
- **Manual triggers.** Each caller exposes the 8 stages as a manual `workflow_dispatch` run with a `stage` selector plus `issue_number` / `pr_number` / `max_attempts` inputs.
- **Attempt counting.** `pr-fix` counts prior fixes from PR comments starting with `<!-- ai-fix-attempt -->` and stops once `count >= max_attempts`. `pr-janitor` uses the same counter: past the threshold it comments, closes the PR, and opens a `ai/stuck` tracking issue — no infinite loops.
- **AI markers.** Each stage has a stub step whose comment identifies the future AI call: `# ai marker: <stage>-gh`. When the AI layer lands, stubs get replaced by real calls; the markers stay as stable identifiers.
- **Idempotency rule.** Stages must be rerunnable — a repeat run must not duplicate comments, issues, or PRs.

### Labels

| Label | Meaning |
|---|---|
| `ai/gap` | issue opened by `issue-find-gaps` |
| `ai/epic` | parent (epic) issue |
| `ai/stuck` | tracking issue opened by `pr-janitor` |
| `ai/in-progress` | issue picked by `issue-pick-task` |
| `ai/parked` | explicitly not to be picked |
| `ai/done` | completed AI work |

## Onboarding a target repo

1. Copy `.github/workflows/caller-template.yml` into `<target>/.github/workflows/` (rename as you like).
2. Set the `PAT_TOKEN` secret on the target repo — a **fine-grained** token with `Contents` + `Issues` read/write on that repo **only**, with an expiry.
3. From the target repo's Actions tab, run the caller, pick a `stage`, and fill in `issue_number` / `pr_number` where required.

The caller forwards your secret to the reusable via `secrets: inherit`; the reusable is referenced as `gardusig/control-plane/.github/workflows/<stage>.yml@main`.

## Layout

```text
src/
  cli/                  the CLI entrypoint
  commands/             cli <noun> subcommands
  lib/                  shared command libs + validators
  scripts/              pull-request + release build helpers
  tests/                bats tests
docker/                 image variants + runtime installers
docs/                   docs
.github/workflows/
  issue-*.yml           reusable dispatch stages
  pr-*.yml              reusable dispatch stages
  caller-template.yml   thin caller for target repos
  test.yml              PR checks
  release.yml           release (docker + GitHub)
```

## Build plan

The roadmap is tracked as GitHub issues in this repo — epics `E01`–`E10` (dependency-ordered), each with child issues following a shared template. See the issues for the full plan.

## Status

Scaffolding. Reusables + caller + janitor logic are in place; AI calls are stubbed behind `# <stage>-gh` markers. The CLI ships in Docker images (`binarylifter/gardusig-cli`).

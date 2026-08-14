# control-plane

Workflow dispatcher and janitor for the skibiribab ecosystem. A **bash-first CLI** (`cli <noun> <verb>`) for repository automation, plus a set of reusable **stage workflows** that inspect repositories, plan work, open issues, create PRs, fix and review them, and clean up anything that gets stuck.

Two halves, one repo:

- **CLI** — runs in Docker images and hosts the shared lint / validation / ops commands that every repo consumes.
- **Stages** — reusable `workflow_call` workflows (the control plane) that act on *other* repos. This repo never acts on itself (self-guard).

## Focus

Three pillars:

- **CLI** — `cli <noun> <verb>` commands (lint / validation / ops) shipped in Docker images.
- **Stages** — reusable dispatch workflows (issue-\* → pr-\* → janitor) that act on other repos.
- **Docker + release** — the runtime images and tag-driven releases.

## CLI

A lean, bash-first CLI for workflow automation, repository checks, and release orchestration. Every command is a thin wrapper around an existing tool; each command runs in the Docker image that owns its toolchain.

```bash
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-orphanage sh lint .
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-node md lint .
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-python yml lint .
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-orphanage git status
```

If a command's tool is missing, `cli` tells you which image to use.

### Images

Alpine-based, self-contained (no shared base inheritance), versioned tags
(`<version>-<variant>`, no `latest`, no bare aliases):

| Tag | Adds | Use for |
| --- | --- | --- |
| `:<v>-orphanage` | shellcheck, actionlint, git, gh, docker-cli, curl, jq, coreutils, qpdf, poppler, lychee, buildx, texlive+latexmk | `sh lint`, `actions lint`, `dockerfile lint`, `pdf lint`, `url`, `tex build`, `git`, `gh`, `docker`, `integration` |
| `:<v>-ai` | opencode (musl; only `libstdc++` runtime dep) + git, gh, docker-cli | `opencode`, the agent loop |
| `:<v>-node` | node/npm + markdownlint | `md lint`, `json lint`, `tasks lint`, `tree`, `repo lint`, `typescript/javascript lint/test` |
| `:<v>-python` | python3 + yamllint | `yml lint`, `python lint/test` |
| `:<v>-rust` | rust/cargo | `rust lint/test` |
| `:<v>-media` | ffmpeg, imagemagick | `png/jpg/... lint`, `mp4/... scan/compress` |
| `:<v>-cpp` | gcc/g++/make/cmake/clang-format | `cpp lint/test` |
| `:<v>-go` | golang | `go lint/test` |
| `:<v>-java` | OpenJDK 21/Maven/Gradle | `java lint/test` |

Every dependency — Alpine base digest, apk packages, static binaries, npm packages — is pinned in `docker/runtime/versions.env`.

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
- **Self-guard.** Every job runs `if: github.repository != 'skibiribab/control-plane'`. Inside a reusable, `github.repository` is the *caller* repo, so the plane can never act on itself.
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

The caller forwards your secret to the reusable via `secrets: inherit`; the reusable is referenced as `skibiribab/control-plane/.github/workflows/<stage>.yml@main`.

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

## CI / releases

Two workflows, Docker-only:

- **PR** (`.github/workflows/test.yml`) — runs as many validations as possible: version gate (**bare `X.Y.Z`**, strictly greater than the greatest **git release tag** *and* the greatest published **Docker Hub** version, derived from `<version>-<variant>` tags — the bump is embedded in the PR), lint (md/json/yml via node/python, sh/actions/dockerfile via orphanage), bats, all 9 runtime images + full per-variant smoke (each image is distinct — other language toolchains are asserted absent), integration.
- **Publish** (`.github/workflows/release.yml`) — on push to `main` it tags the merged `VERSION` (`X.Y.Z`, no `v`; only minor-bumps as a fallback for direct pushes so we always release strictly above what's live); on a version tag it builds + pushes every image (`<X.Y.Z>-<variant>`) and runs a slim pull-back smoke. See [`docs/ci-workflows.md`](docs/ci-workflows.md).

Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `PAT_TOKEN` — see [`docs/secrets.md`](docs/secrets.md).

## Build plan

The roadmap is tracked as GitHub issues in this repo — epics `E01`–`E10` (dependency-ordered), each with child issues following a shared template. See the issues for the full plan.

## Status

Scaffolding. Reusables + caller + janitor logic are in place; AI calls are stubbed behind `# <stage>-gh` markers. The CLI ships in Docker images (`skibiribab/cli`).

# Control-plane conventions

Workflow dispatcher and janitor for the skibiribab ecosystem. Two halves:

- **CLI** — bash-first `cli <noun> <verb>` commands run in Docker images (`skibiribab/cli`).
- **Stages** — reusable `workflow_call` workflows that act on *other* repos.

## Rules

- **Self-guard:** stages never act on this repo (`github.repository != 'skibiribab/control-plane'`).
- **Thin repos:** other repos stay independent with their own PR workflow; they call the reusable stages / PR router here.
- New commands: add a `src/commands/<flavor>/<noun>.sh` + a `lib/` helper + wire the docker image; update `docs/commands.md`.
- Reusable workflows live under `.github/workflows/` (stages at root, `lib/` for router).
- Theme: `GitHub Dark Default`.

## CI

- `test.yml` — PR checks: Docker version gate (VERSION must be > greatest published Docker tag), lint (md/json/yml/sh/dockerfile/actionlint), bats, all 8 runtime images + full smoke, integration.
- `release.yml` — on push to `main`: auto-version + tag (VERSION, or minor-bump of the greatest published Docker version); on version tag: build + push Docker images + slim publish smoke + GitHub release.

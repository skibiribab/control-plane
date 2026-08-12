# Control-plane conventions

Workflow dispatcher and janitor for the gardusig ecosystem. Two halves:

- **CLI** — bash-first `cli <noun> <verb>` commands run in Docker images (`binarylifter/gardusig-cli`).
- **Stages** — reusable `workflow_call` workflows that act on *other* repos.

## Rules

- **Self-guard:** stages never act on this repo (`github.repository != 'gardusig/control-plane'`).
- **Thin repos:** other repos stay independent with their own PR workflow; they call the reusable stages / PR router here.
- New commands: add a `commands/<flavor>/<noun>.sh` + a `lib/` helper + wire the docker image; update `docs/commands.md`.
- Reusable workflows live under `.github/workflows/` (stages at root, `lib/` for router).
- Theme: `GitHub Dark Default`.

## CI

- `test.yml` — PR checks (build + lint + bats).
- `release.yml` — tag-driven: build + publish docker images + GitHub release.

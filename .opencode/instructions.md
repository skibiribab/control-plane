# Control-plane conventions

Workflow dispatcher and janitor for the skibiribab ecosystem. Two halves:

- **CLI** — bash-first `cli <noun> <verb>` commands run in Docker images (`skibiribab/cli`).
- **Stages** — reusable `workflow_call` workflows that act on *other* repos.

## Rules

- **Self-guard:** stages never act on this repo (`github.repository != 'skibiribab/control-plane'`).
- **Minimal dependencies:** images ship the language basics plus only the **shared** tooling that many repos consume (e.g. markdownlint in node, shellcheck/actionlint in orphanage) — nothing repo-specific. Before adding an OS package or new tool, verify its real runtime deps (`ldd` on the binary / `apk info -d <pkg>`); prefer static/musl builds so Alpine carries nothing extra. Repo-specific tooling belongs in the consumer repo (package.json/Makefile scripts — see `docs/consumer-tooling.md`), not in images. Example: `opencode` runs standalone on Alpine with only `libstdc++`; `git`/`gh`/`docker-cli` are shelled-out commands, not dependencies.
- **Thin repos:** other repos stay independent with their own PR workflow; they call the reusable stages / PR router here.
- New commands: add a `src/commands/<flavor>/<noun>.sh` + a `lib/` helper + wire the docker image; update `docs/commands.md`.
- Reusable workflows live under `.github/workflows/` (stages at root, `lib/` for router).
- Theme: `GitHub Dark Default`.

## CI

- `test.yml` — PR checks: Docker version gate (VERSION must be > greatest published Docker version, derived from `<version>-<variant>` tags), lint (md/json/yml via node/python, sh/actions/dockerfile via orphanage), bats, all 9 runtime images + full smoke, integration.
- `release.yml` — on push to `main`: auto-version + tag (VERSION, or minor-bump of the greatest published Docker version); on version tag: build + push Docker images + slim publish smoke + GitHub release.

# CI workflows

Two workflows, Docker-only (no PyPI/pip — the bash CLI ships in runtime images):

- **CI** (`.github/workflows/test.yml`) — runs on pull requests: runs as many validations as possible, never publishes.
- **Publish** (`.github/workflows/release.yml`) — runs on push to `main` (auto-versions + tags) and on version tags (build + push + publish).

## CI (`test.yml`) — pull requests

Every check below runs per PR; nothing is published. The version upgrade is
**embedded in the PR**: the gate fails unless `VERSION` is bumped above both
sources, so `main` merges release-ready.

| Job | What it does |
| --- | --- |
| `resolve` | VERSION + greatest **git release tag** (`host-last-published-version.sh`) + greatest **published Docker Hub** version (`host-last-published-docker-version.sh` — all tags paginated, greatest `<version>-<variant>` tag = latest) → `git_version` + `base_version` |
| `version-check` | VERSION must be bare semver `x.y.z`, **strictly greater than both** the greatest git release tag and the greatest published Docker version (each comparison skipped only when that source has nothing published) |
| `lint` | node image: `md lint` · `md link` · `md table` · `json lint` · `whitespace lint`; orphanage image: `sh lint` · `actions lint` · `dockerfile lint` |
| `lint-yml` | python image: `yamllint` |
| `unit-test` | bats tests |
| `runtime-build` | all 9 variants (orphanage/ai/node/python/rust/cpp/go/java/media): build each Dockerfile + full per-variant `runtime-smoke.sh` (tools present **and** other-language toolchains absent) |
| `integration` | `cli` integration smoke |

Every job that builds images cleans up afterwards
(`docker image prune -af && docker builder prune -af`).

## Publish (`release.yml`) — main pushes + version tags

Lean on purpose: full validation already ran in the PR gate, so the release focuses on **build + push**.

- **Push to `main`** → `auto-tag` job (tags are bare `x.y.z`, no `v` prefix):
  - Skips release commits (`chore(release):`) and already-tagged HEAD.
  - `next = VERSION` when VERSION is already strictly greater than the greatest **git release tag** and the greatest **published Docker Hub** version — the normal path, since the PR gate embedded the bump.
  - Otherwise (direct push with a stale `VERSION`) it **minor-bumps** the greater of the two greatest versions (`M.(m+1).0`) — always strictly above both sources.
  - When `next == VERSION` the merged bump is **not re-committed** (no `chore(release):` on the normal path); the job just tags and pushes. The tag push (via `PAT_TOKEN`) triggers the publish jobs below.
- **Tag push (`X.Y.Z`)**:
  - `resolve-release`: tag is bare semver, **matches `VERSION`**, and is greater than the previous git release tag **and** the greatest published Docker version (downgrade guard).
  - `publish-docker`: builds + pushes `skibiribab/cli:<X.Y.Z>-<variant>` for all 9 variants (`-orphanage/-ai/-node/-python/-rust/-cpp/-go/-java/-media`), then a **slim smoke** — pulls each published tag back and verifies `cli --version` matches plus one cheap tool probe per variant (no full lint smoke; that already ran in PR CI on the same tree).
  - `publish-github`: creates the GitHub release.

`ci-push` / `ci-smoke` / `ci-github-release` are `docker/pull-request.dockerfile`
targets running from a `docker:27-cli` image with the daemon socket mounted.

## Version gate

- Two sources of truth, both must be beaten:
  - the greatest **bare `X.Y.Z` git release tag**,
  - the greatest **`X.Y.Z` published on Docker Hub**, derived from the `<version>-<variant>` tags (all tags paginated, greatest semver = latest).
- PR: `VERSION` must be bare semver and **strictly greater than both** (each comparison skipped only when its source has no version yet).
- Release: the tag must be strictly greater than both the previous git tag and the greatest published Docker version (downgrade guard).
- Auto-tag: tags the PR-bumped `VERSION`; only minor-bumps when `VERSION` didn't move (direct push).

## Pipeline scripts

- `src/scripts/_common.sh` — version from `VERSION`, semver compare, `stage_bump_minor`, `stage_max_published_docker_version`, variant → dockerfile/tag maps.
- `src/scripts/pull-request/` — resolve, Docker version gate, lint, bats, integration.
- `src/scripts/release/` — build/push/slim-smoke/verify/release helpers.

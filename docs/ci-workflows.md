# CI workflows

Two workflows, Docker-only (no PyPI/pip — the bash CLI ships in runtime images):

- **CI** (`.github/workflows/ci.yaml`) — runs on pull requests.
- **Publish** (`.github/workflows/publish.yaml`) — runs on new version tags.

## CI (`.github/workflows/ci.yaml`) — PRs

Builds and lints everything, **never publishes**.

| Job | Builds | What it does |
| --- | --- | --- |
| `resolve` | `resolve` stage | VERSION → `version`; greatest previous release tag → `base_version`; prunes |
| `version-check` | `version-check` stage | **fails if VERSION ≤ `base_version`** (only skipped when there's no previous tag); prunes |
| `unit-test` | `unit-test` stage | runs bats tests; prunes |
| `runtime-build` | all 8 variants (base/rust/node/python/media/cpp/go/java) | builds **each Dockerfile separately**, runs the full per-variant `runtime-smoke.sh`, prunes image + build cache |
| `integration` | `integration-smoke` stage | runs `cli` integration smoke; prunes |

Every job that builds images cleans up afterwards
(`docker image prune -af && docker builder prune -af`) — re-downloading is fine.

## Publish (`.github/workflows/publish.yaml`) — new tags

Triggered by `push` of a version tag (`X.Y.Z`):

- `resolve-release` validates the tag is semver, **matches `VERSION`**, and is
  **greater than the previous release tag** (downgrade guard), then prunes.
- `publish-docker` builds + pushes `binarylifter/gardusig-cli:X.Y.Z` and
  `-base/-rust/-node/-python/-media/-cpp/-go/-java`, then smokes the pushed
  images and prunes.
- `publish-github` creates the GitHub release.

`ci-push` / `ci-smoke` / `ci-github-release` are `src/docker/pull-request.dockerfile`
targets running from a `docker:27-cli` image with the daemon socket mounted.

## Version gate

- `VERSION` (the repo's single version source) must be **greater than the
  greatest previous release tag** — enforced on every PR (CI) and again at
  publish time (downgrade guard).
- Comparison is component-wise semver (`stage_compare_versions` in
  `scripts/_common.sh`), so `1.3.0 > 1.2.10`.

## Pipeline scripts (`scripts/`)

- `scripts/_common.sh` — version from `VERSION`, semver compare, variant →
  dockerfile/tag maps, stage timeouts.
- `scripts/release/` — build/push/smoke/verify/release helpers.
- `scripts/pull-request/` — resolve, version gate, bats unit test, integration smoke.

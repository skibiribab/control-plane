# Development

`cli` is bash — no Python, no uv, no pip, no PyPI. Develop against the repo and
build the Docker images to smoke changes.

## Prerequisites

- `bash`, `git`, `docker`.
- Optional: `bats-core` to run `src/src/tests/*.bats` locally.

## Repo commands

```bash
./cli --version
./cli --help
./cli integration list
./cli integration check
```

## Local image builds

```bash
docker build -f src/docker/base.dockerfile -t cli-base .
docker build -f src/docker/rust.dockerfile -t cli-rust .
docker build -f docker/node.dockerfile -t cli-node .
docker build -f docker/python.dockerfile -t cli-python .
docker build -f docker/media.dockerfile -t cli-media .
bash scripts/release/runtime-smoke.sh cli-base base
bash scripts/release/runtime-smoke.sh cli-node node
```

Clean up after yourself so the machine doesn't fill up:

```bash
docker image prune -af
docker builder prune -af
```

## Versioning

- The single source of truth is the `VERSION` file (bare semver).
- Bump `VERSION` (strictly greater than the latest release tag for the PR gate).
- Tagging `X.Y.Z` triggers `.github/workflows/release.yaml` (docker-only).

## Tests

`src/src/tests/*.bats` (bats-core) exercise the dispatcher, lib helpers, and a few
file-type lints. Run them in the `unit-test` stage of
`src/docker/pull-request.dockerfile`:

```bash
docker build -f src/docker/pull-request.dockerfile --target unit-test .
```

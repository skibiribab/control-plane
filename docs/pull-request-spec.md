# PR pipeline spec (`pull-request.yaml`)

The reusable [`pull-request-router.yml`](../.github/workflows/lib/pull-request-router.yml)
drives a target repo's PR gate. Each target repo declares its pipeline in
`.github/pull-request.yaml` (legacy fallback: `.github/repo-review.yaml`).

If no spec file exists, the router falls back to `cli check .` in the repo's
primary image (input `default_image`, default `node`) and auto-adds an
`-orphanage` ops stage when the repo contains shell scripts or Dockerfiles.

## Stage types

A spec is a flat YAML list. Each stage is either:

- **Image stage** — runs a shell command inside
  `skibiribab/cli:<latest-published>-<image>` with the repo mounted at `/repo`
  and the docker socket available. The cli version is resolved at runtime —
  repos never pin a stale tag.

```yaml
- id: lint
  name: cli check
  image: node
  command: cli check .
- id: test
  image: go
  command: go test ./...
```

- **Legacy target stage** — builds the repo's own `docker/Dockerfile`
  (or `Dockerfile`) target and runs it.

```yaml
- id: build
  name: custom build
  target: build
```

## Example

```yaml
# .github/pull-request.yaml
- id: check
  name: cli check
  image: node
  command: cli check .
- id: build
  name: build app
  image: node
  command: npm ci && npm run build
- id: test
  name: unit tests
  image: node
  command: npm test
```

## Routing from your PR workflow

Call the reusable from the target repo's own workflow:

```yaml
name: CI
on:
  pull_request:
    branches: [main]
jobs:
  pipeline:
    uses: skibiribab/control-plane/.github/workflows/lib/pull-request-router.yml@main
    with:
      repo_slug: ${{ github.event.repository.full_name }}
      repository: ${{ github.repository }}
      ref: ${{ github.ref }}
      sha: ${{ github.event.pull_request.head.sha }}
      pr_number: ${{ github.event.pull_request.number }}
      default_image: node
    secrets:
      CENTRAL_PIPELINE_PAT: ${{ secrets.CENTRAL_PIPELINE_PAT }}
```

## Releases

Thin repos release through the reusable
[`release-router.yml`](../.github/workflows/lib/release-router.yml): resolve
latest cli → `cli check` in the primary image → timestamp tag → GitHub release.
See `docs/ci-workflows.md`.

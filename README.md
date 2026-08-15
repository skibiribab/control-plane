# pkg-manager

A multi-language package repo — one **versioned, pinned Docker image per language toolchain**, built on Alpine, published to Docker Hub (`skibiribab/pkg-manager`). Foundational: no UI, no application code. Each image is a self-contained build/test environment for its language.

| Tag | Contents |
| --- | --- |
| `:<v>-node` | node/npm + markdownlint-cli |
| `:<v>-python` | python3 + yamllint |
| `:<v>-rust` | rust/cargo |
| `:<v>-cpp` | gcc/g++/make/cmake/clang |
| `:<v>-go` | golang |
| `:<v>-java` | OpenJDK 21 / Maven / Gradle |
| `:<v>-media` | ffmpeg + imagemagick |

Every dependency — Alpine base, apk packages (exact versions), npm packages — is pinned in `docker/runtime/versions.env`. Tags are versioned only (`<version>-<variant>`, no `latest`, no bare aliases). Images are self-contained (no shared base inheritance).

## Pull and run

```bash
docker pull skibiribab/pkg-manager:1.8.0-node
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/pkg-manager:1.8.0-node node --version
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/pkg-manager:1.8.0-python python3 --version
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/pkg-manager:1.8.0-rust cargo --version
```

## Build locally

```bash
docker build -f docker/node.dockerfile -t pkg-manager-node .
docker build -f docker/python.dockerfile -t pkg-manager-python .
```

## Release

Tag-driven: pushing a bare `X.Y.Z` tag builds + pushes all 7 images and opens a GitHub release (`.github/workflows/release.yml`). The `VERSION` file must be bumped in the merged PR; `main` pushes auto-tag it.

## Docs

- [`docs/docker.md`](docs/docker.md) — image tree, dependencies, rules
- [`docs/README.md`](docs/README.md) — docs index

## Layout

```text
docker/                 image variants + runtime installers
  runtime/              install-*.sh + versions.env (pinned deps)
docs/                   docs
.github/workflows/
  test.yml              PR checks (markdownlint + build smoke per image)
  release.yml           release (build + push + GitHub release)
```

CI secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `GH_TOKEN_REPO_WRITE`.

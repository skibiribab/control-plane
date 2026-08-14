# Docker

This repo owns two kinds of Docker artifacts with clearly separated purposes:

| Kind | File | Purpose | For whom |
| --- | --- | --- | --- |
| **Usable runtime images** | `docker/{orphanage,ai,node,python,rust,cpp,go,java,media}.dockerfile` | `cli` (bash) plus the tools for each domain | Everyone (pull and run) |
| **Development pipeline** | `docker/pull-request.dockerfile` | Build the bash CLI, run bats tests, publish images | This repo's CI only |

## Usable images (`skibiribab/cli`)

Every image is **self-contained** — no shared base inheritance (the runner
provides git/docker in CI). All tags are versioned (`<version>-<variant>`, no
`latest`, no bare/`base-` aliases). Each image bakes `CLI_RUNTIME`.

| Tag | Contents | Typical use |
| --- | --- | --- |
| `:<v>-orphanage` | bash CLI + shellcheck, actionlint, git, gh, docker-cli, curl, jq, coreutils, zip/unzip/tar, qpdf, poppler-utils, lychee, buildx, texlive+latexmk | `sh lint`, `actions lint`, `dockerfile lint`, `pdf lint`, `url`, `tex build`, `structure lint`, `git`, `gh`, `docker`, `integration` |
| `:<v>-ai` | bash CLI + opencode (musl; `libstdc++` only runtime dep), git, gh, docker-cli | `opencode`, the pull→plan→build→git→gh agent loop |
| `:<v>-node` | node/npm, markdownlint-cli | `md lint`, `json lint`, `tasks lint`, `tree generate/validate`, `repo lint`, `typescript`/`javascript` lint+test, `node` |
| `:<v>-python` | python3, yamllint | `yml lint`, `python lint/test` |
| `:<v>-rust` | rust/cargo | `rust lint/test` |
| `:<v>-cpp` | gcc/g++/make/cmake/clang-format | `cpp lint/test` |
| `:<v>-go` | golang | `go lint/test` |
| `:<v>-java` | OpenJDK 21, Maven, Gradle | `java lint/test` |
| `:<v>-media` | ffmpeg, imagemagick | `png/jpg/… lint`, `mp4/… scan/compress` |

### Sizes

Compressed size on Docker Hub (`<version>-<variant>` tag, `size` field),
re-measured on each release. Measured at `1.8.0` (first release of the
self-contained variant set).

| Variant | Size |
| --- | --- |
| `orphanage` | 475 MiB |
| `ai` | 95 MiB |
| `node` | 41 MiB |
| `python` | 22 MiB |
| `rust` | 206 MiB |
| `cpp` | 267 MiB |
| `go` | 130 MiB |
| `java` | 304 MiB |
| `media` | 56 MiB |

### Dependencies (per image)

Every image adds the **core** set first — `bash`, `coreutils`, `curl`,
`ca-certificates` (Alpine, pinned in `docker/runtime/versions.env`) — then its
own domain. Lists are as small as possible: language runtime + the shared tools
that many repos need. Repo-specific tooling is installed by the consumer repo
(see [consumer-tooling.md](consumer-tooling.md)), not baked into images.

| Image | Dependencies (pinned) |
| --- | --- |
| `orphanage` | git 2.47.3 · github-cli 2.63.0 · docker-cli 27.3.1 · zip/unzip/tar · shellcheck 0.10.0 · actionlint 1.7.4 · jq 1.7.1 · qpdf 11.9.1 · poppler-utils 24.02.0 · texlive 20240210.69778 (+luatex/xetex/binextra/dvi) · lychee 0.24.2 · buildx 0.36.1 |
| `ai` | git 2.47.3 · github-cli 2.63.0 · docker-cli 27.3.1 · libstdc++ 14.2.0 · opencode 1.18.11 (musl). `libstdc++` is opencode's only runtime dependency — git/gh/docker-cli are shelled-out commands. |
| `node` | nodejs 22.23.2 · npm 10.9.1 · markdownlint-cli 0.49.1 (shared across repos) |
| `python` | python3 3.12.13 · yamllint 1.35.1 |
| `rust` | rust 1.83.0 · cargo 1.83.0 |
| `cpp` | gcc 14.2.0 · g++ 14.2.0 · make · cmake 3.31.1 · clang 19.1.4 |
| `go` | go 1.23.9 |
| `java` | openjdk21-jdk 21.0.10 · maven 3.9.9 · gradle 8.11.1 |
| `media` | ffmpeg 6.1.2 · imagemagick 7.1.1.41 |

Pull the image you need and run `cli` against a mounted repo:

```bash
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-orphanage sh lint .
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-node md lint .
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-python yml lint .
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-orphanage git status
```

In GitHub Actions:

```yaml
- run: docker run --rm -v "${{ github.workspace }}:/repo" -w /repo skibiribab/cli:1.8.0-orphanage sh lint .
```

## Rules

- **Minimal dependencies.** Each image installs its language basics plus only
  the **shared** tooling many repos consume — no shared base, no speculative
  toolchains, nothing repo-specific (repo-specific tooling lives in the
  consumer repo; see [consumer-tooling.md](consumer-tooling.md)). Verify a
  tool's real runtime deps before adding packages; prefer static/musl builds.
  `opencode` runs standalone on Alpine with only `libstdc++`; `git`/`gh`/
  `docker-cli` are shelled-out commands, not dependencies.
- **Markdown/JSON/YAML/image/PDF/video tooling lives only in its owning image.**
  `cli md lint` works in `-node`, `cli yml lint` in `-python`, `cli pdf lint`
  and `cli url` in `-orphanage` — and fails elsewhere with a recommendation.
  `cli check .` runs every generic-lint verb the current image has and skips
  missing tools with a "use the X image" hint.
- **`dockerfile lint` needs the daemon socket**: `-v /var/run/docker.sock:/var/run/docker.sock`.
- **`docker` commands need the socket** the same way.
- **git on mounted repos**: the image sets `git config --global --add safe.directory '*'`.
- **Config is pure env**: pass `-e GITHUB_TOKEN=…`, `-e DEEPSEEK_API_KEY=…`, etc.
  No config files, no JSON, no jq-for-config.
- **Exit codes**: `cli <noun> lint` exits 0 on success, non-zero on failure.

Every dependency — Alpine base, apk packages (exact versions), static
binaries, npm packages, and the bash CLI itself — is version-pinned
in `docker/runtime/versions.env`. Tags are versioned only.

Images are **multi-stage**: a `src` stage does `COPY . .` (whole context), and
the `final` stage copies only the relevant artifacts (`/cli /lib /commands
/VERSION`) to `/opt/cli` plus its installed toolchain. The `/usr/local/bin/cli`
binary exists only inside the built image — the repo carries source only.
`.dockerignore` ignores just `.git`; the repo's `.gitignore` is a forbid-all
allowlist, enforced by `cli ignore lint .`.

Build locally (from the repo checkout):

```bash
docker build -f docker/orphanage.dockerfile -t cli-orphanage .
docker build -f docker/node.dockerfile -t cli-node .
bash src/scripts/release/runtime-smoke.sh cli-orphanage orphanage
bash src/scripts/release/runtime-smoke.sh cli-node node
```

## Development pipeline (`docker/pull-request.dockerfile`)

Used by PR and release CI. Targets: `resolve`, `resolve-release`,
`version-check`, `unit-test` (bats), `integration-smoke`,
`ci-push`/`ci-smoke`/`ci-github-release`. Every CI job that builds images cleans
up afterwards (`docker image prune -af && docker builder prune -af`) so runners
don't fill up — it's fine to re-download.

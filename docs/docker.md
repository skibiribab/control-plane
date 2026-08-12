# Docker

This repo owns two kinds of Docker artifacts with clearly separated purposes:

| Kind | File | Purpose | For whom |
| --- | --- | --- | --- |
| **Usable runtime images** | `docker/{base,rust,node,python,media,cpp,go,java}.dockerfile` | `cli` (bash) plus the tools for each domain | Everyone (pull and run) |
| **Development pipeline** | `docker/pull-request.dockerfile` | Build the bash CLI, run bats tests, publish images | This repo's CI only |

## Usable images (`binarylifter/gardusig-cli`)

One tag per image, all versioned (no `latest`). Every image inherits **base**
(Alpine + the bash CLI + core shelling tools); each adds its language/domain
toolchain and bakes `CLI_RUNTIME`.

| Tag | Contents | Typical use |
| --- | --- | --- |
| `:1.2.0` (alias `:base-1.2.0`) | bash CLI + git, gh, docker-cli, opencode, shellcheck, actionlint, curl, coreutils, zip/unzip/tar | `sh lint`, `dockerfile lint` (needs socket), `structure lint`, `git`, `gh`, `docker`, `opencode`, `integration` |
| `:1.2.0-rust` | + rust/cargo, lychee (musl) | `url`, `rust lint/test` |
| `:1.2.0-node` | + node/npm, markdownlint-cli, jq | `md lint`, `json lint`, `tasks lint`, `typescript`/`javascript` lint+test, `node` |
| `:1.2.0-python` | + python3/pip, codespell, yamllint | `yml lint`, `python lint/test` |
| `:1.2.0-media` | + ffmpeg, imagemagick, poppler-utils | `pdf lint`, `png/jpg/… lint`, `mp4/… scan/compress` |
| `:1.2.0-cpp` | + gcc/g++/make/cmake/clang-format | `cpp lint/test` |
| `:1.2.0-go` | + golang | `go lint/test` |
| `:1.2.0-java` | + OpenJDK 21, Maven, Gradle | `java lint/test` |

Pull the image you need and run `cli` against a mounted repo:

```bash
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0 sh lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0-node md lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0-python yml lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0 git status
```

In GitHub Actions:

```yaml
- run: docker run --rm -v "${{ github.workspace }}:/repo" -w /repo binarylifter/gardusig-cli:1.2.0 sh lint .
```

## Rules

- **Markdown/JSON/YAML/image/PDF/video tooling lives only in its owning image.**
  `cli md lint` works in `-node`, `cli yml lint` in `-python`, `cli pdf lint` in
  `-media`, `cli url` in `-rust` — and fails elsewhere with a recommendation.
- **`dockerfile lint` needs the daemon socket**: `-v /var/run/docker.sock:/var/run/docker.sock`.
- **`docker` commands need the socket** the same way.
- **git on mounted repos**: the image sets `git config --global --add safe.directory '*'`.
- **Config is pure env**: pass `-e GITHUB_TOKEN=…`, `-e DEEPSEEK_API_KEY=…`, etc.
  No config files, no JSON, no jq-for-config.
- **Exit codes**: `cli <noun> lint` exits 0 on success, non-zero on failure.

Every dependency — Alpine base, apk packages (exact versions), static
binaries, npm/pip packages, and the bash CLI itself — is version-pinned
in `src/docker/runtime/versions.env`. Tags are versioned only.

Images are **multi-stage**: a `src` stage does `COPY . .` (whole context), and
the `final` stage copies only the relevant artifacts (`/cli /lib /commands
/VERSION`) to `/opt/cli` plus its installed toolchain. The `/usr/local/bin/cli`
binary exists only inside the built image — the repo carries source only.
`.dockerignore` ignores just `.git`; the repo's `.gitignore` is a forbid-all
allowlist, enforced by `cli ignore lint .`.

Build locally (from the repo checkout):

```bash
docker build -f docker/base.dockerfile -t cli-base .
docker build -f docker/rust.dockerfile -t cli-rust .
bash scripts/release/runtime-smoke.sh cli-base base
bash scripts/release/runtime-smoke.sh cli-rust rust
```

## Development pipeline (`docker/pull-request.dockerfile`)

Used by PR and release CI. Targets: `resolve`, `resolve-release`,
`version-check`, `unit-test` (bats), `integration-smoke`,
`ci-push`/`ci-smoke`/`ci-github-release`. Every CI job that builds images cleans
up afterwards (`docker image prune -af && docker builder prune -af`) so runners
don't fill up — it's fine to re-download.

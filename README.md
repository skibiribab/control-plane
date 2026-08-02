# cli

A lean, **bash-first** CLI for workflow automation, repository checks, and release
orchestration. Every command is a thin wrapper around an existing tool; each
command runs in the Docker image that owns its toolchain.

Model: **`cli <noun> <verb>`** — noun = file extension · language · concept.

## Quickstart

```bash
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0 sh lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0-node md lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0-python yml lint .
docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0 git status
```

Pick the image that owns the tool you need. If you run a command whose tool is
missing, `cli` tells you which image to use:

```
$ cli md lint .
cli: markdownlint is required but not in this image (base).
     Use the node image: binarylifter/gardusig-cli:1.2.0-node
```

## Images

Alpine-based, versioned tags (no `latest`):

| Tag | Adds | Use for |
| --- | --- | --- |
| `:1.2.0` (`:base-1.2.0`) | git, gh, docker-cli, opencode, shellcheck, actionlint, curl, jq-adjacent core | `sh lint`, `dockerfile lint`, `structure lint`, `git`, `gh`, `docker`, `opencode`, `integration` |
| `:1.2.0-rust` | rust/cargo + lychee | `url`, `rust lint`, `rust test` |
| `:1.2.0-node` | node/npm + markdownlint + jq | `md lint`, `json lint`, `tasks lint`, `typescript lint/test`, `javascript lint/test`, `node` |
| `:1.2.0-python` | python3/pip + codespell, yamllint | `yml lint`, `python lint/test` |
| `:1.2.0-media` | ffmpeg, imagemagick, poppler | `pdf lint`, `png/jpg/... lint`, `mp4/... scan/compress` |
| `:1.2.0-cpp` | gcc/g++/make/cmake/clang-format | `cpp lint/test` |
| `:1.2.0-go` | golang | `go lint/test` |
| `:1.2.0-java` | OpenJDK 21/Maven/Gradle | `java lint/test` |

Every dependency — Alpine base digest, apk packages, static binaries, npm/pip
packages — is pinned in `docker/runtime/versions.env`.

## Commands

See [docs/commands.md](docs/commands.md) (noun → image) and
[docs/validation.md](docs/validation.md) (tool → written-in → image).

## Status

[![License: MIT](https://img.shields.io/pypi/l/gardusig-cli?label=License)](https://github.com/gardusig/cli/blob/main/LICENSE)

Bash CLI distributed in Docker images. Python/PyPI publishing was removed in the
1.2 rewrite.

- [Docs](docs/README.md) · [Docker images](docs/docker.md) · [Install](docs/install.md)
- [GitHub](docs/gh.md) · [OpenCode](docs/opencode.md) · [CI workflows](docs/ci-workflows.md)

# Docker

A multi-language package repo — one **versioned, pinned Docker image per language toolchain**, published to Docker Hub as `skibiribab/pkg-manager`.

## Images

| Tag | Contents | Typical use |
| --- | --- | --- |
| `:<v>-node` | nodejs 22.23.2 · npm 10.9.1 · markdownlint-cli 0.49.1 | node/npm builds, markdown lint |
| `:<v>-python` | python3 3.12.13 · yamllint 1.35.1 | python builds, yaml lint |
| `:<v>-rust` | rust 1.83.0 · cargo 1.83.0 | rust/cargo builds |
| `:<v>-cpp` | gcc 14.2.0 · g++ 14.2.0 · make · cmake 3.31.1 · clang 19.1.4 | C/C++ builds + lint |
| `:<v>-go` | go 1.23.9 | go builds |
| `:<v>-java` | openjdk21-jdk 21.0.10 · maven 3.9.9 · gradle 8.11.1 | java/jvm builds |
| `:<v>-media` | ffmpeg 6.1.2 · imagemagick 7.1.1.41 | video/image processing |

Every image adds the **core** set first — `bash`, `coreutils`, `curl`,
`ca-certificates` (Alpine, pinned in `docker/runtime/versions.env`) — then its
own language toolchain. Images are self-contained (no shared base inheritance);
lists are as small as possible.

## Pull and run

```bash
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/pkg-manager:1.8.0-node node --version
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/pkg-manager:1.8.0-python python3 --version
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/pkg-manager:1.8.0-rust cargo --version
```

In GitHub Actions:

```yaml
- uses: docker/setup-buildx-action@v3
- run: docker run --rm -v "${{ github.workspace }}:/repo" -w /repo skibiribab/pkg-manager:1.8.0-node node --version
```

## Rules

- **Minimal dependencies.** Each image installs its language toolchain plus only the shared basics — no speculative packages, nothing repo-specific.
- **Pinned.** Every dependency — Alpine base, apk packages (exact versions), npm packages — is pinned in `docker/runtime/versions.env`. Tags are versioned only (`<version>-<variant>`, no `latest`, no bare aliases).
- **Multi-stage.** A `src` stage provides the build context; the `final` stage ships only the toolchain.
- **Build locally** from the repo checkout:

```bash
docker build -f docker/node.dockerfile -t pkg-manager-node .
docker build -f docker/python.dockerfile -t pkg-manager-python .
```

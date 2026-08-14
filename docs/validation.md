# Validation reference

Every validation tool, the language it was **written in**, and the **owning
image** that provides it. A tool's own implementation language is irrelevant to
placement — what matters is the thing being validated (see the placement rule).

## Placement rule

1. If the thing being validated matches a supported language image (node,
   python, rust, cpp, go, java, media), the tool lives **in that image**
   (native).
2. Cross-cutting validators with no language home stay in **orphanage** as
   pinned lightweight binaries.
3. A tool written in X but validating something else does **not** move to the X
   image (e.g. actionlint is Go but validates workflows → orphanage; lychee is
   Rust but validates URLs → orphanage).
4. `opencode` (the agent loop) lives in the dedicated **ai** image, which
   otherwise carries only `libstdc++` as a runtime dependency.

## Table

Sizes are the image's compressed size on Docker Hub (`<version>-<variant>` tag,
`size` field), refreshed on each release. `orphanage`/`ai` are new in `1.8.0` —
shown at local uncompressed measure until first publish.

| Command / tool | Owning image | Image size |
| --- | --- | --- |
| `sh lint` (shellcheck) | orphanage | ~475 MiB (local; TBD) |
| `actions lint` (actionlint) | orphanage | ~475 MiB (local; TBD) |
| `dockerfile lint` (`docker build --check`, needs socket) | orphanage | ~475 MiB (local; TBD) |
| `structure lint` / `ignore lint` (bash) | orphanage | ~475 MiB (local; TBD) |
| `url` (lychee) | orphanage | ~475 MiB (local; TBD) |
| `pdf lint` (qpdf / pdfinfo) | orphanage | ~475 MiB (local; TBD) |
| `tex build` (latexmk / texlive) | orphanage | ~475 MiB (local; TBD) |
| `git` / `gh` / `docker` | orphanage | ~475 MiB (local; TBD) |
| `opencode` | ai | ~94 MiB (local; TBD) |
| `md lint` / `md link` / `md table` (markdownlint-cli) | node | 134 MiB |
| `json lint` / `tasks lint` (node) | node | 134 MiB |
| `tree generate/validate` (node) | node | 134 MiB |
| `repo lint` (composite) | node | 134 MiB |
| `typescript` / `javascript` / `node` / `npm` / `npx` | node | 134 MiB |
| `yml lint` (yamllint) | python | 112 MiB |
| `python lint` / `python test` (python3) | python | 112 MiB |
| `png/jpg/… lint` (identify) / `mp4/…` (ffmpeg) | media | 151 MiB |
| `cpp lint` / `cpp test` (gcc/g++/clang) | cpp | 357 MiB |
| `go lint` / `go test` (go) | go | 221 MiB |
| `java lint` / `java test` (openjdk/maven/gradle) | java | 394 MiB |
| `rust lint` / `rust test` (cargo) | rust | 304 MiB |

## How to see coverage

`cli integration list` prints the tool → image table; `cli integration check`
reports what the current image has and which image provides anything missing.

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
`size` field), refreshed on each release. Measured at `1.8.0`.

| Command / tool | Owning image | Image size |
| --- | --- | --- |
| `sh lint` (shellcheck) | orphanage | 475 MiB |
| `actions lint` (actionlint) | orphanage | 475 MiB |
| `dockerfile lint` (`docker build --check`, needs socket) | orphanage | 475 MiB |
| `structure lint` / `ignore lint` (bash) | orphanage | 475 MiB |
| `url` (lychee) | orphanage | 475 MiB |
| `pdf lint` (qpdf / pdfinfo) | orphanage | 475 MiB |
| `tex build` (latexmk / texlive) | orphanage | 475 MiB |
| `git` / `gh` / `docker` | orphanage | 475 MiB |
| `opencode` | ai | 95 MiB |
| `md lint` / `md link` / `md table` (markdownlint-cli) | node | 41 MiB |
| `json lint` / `tasks lint` (node) | node | 41 MiB |
| `tree generate/validate` (node) | node | 41 MiB |
| `repo lint` (composite) | node | 41 MiB |
| `typescript` / `javascript` / `node` / `npm` / `npx` | node | 41 MiB |
| `yml lint` (yamllint) | python | 22 MiB |
| `python lint` / `python test` (python3) | python | 22 MiB |
| `png/jpg/… lint` (identify) / `mp4/…` (ffmpeg) | media | 56 MiB |
| `cpp lint` / `cpp test` (gcc/g++/clang) | cpp | 267 MiB |
| `go lint` / `go test` (go) | go | 130 MiB |
| `java lint` / `java test` (openjdk/maven/gradle) | java | 304 MiB |
| `rust lint` / `rust test` (cargo) | rust | 206 MiB |

## How to see coverage

`cli integration list` prints the tool → image table; `cli integration check`
reports what the current image has and which image provides anything missing.

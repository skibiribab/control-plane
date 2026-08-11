# Validation reference

Every validation tool, the language it was **written in**, and the **owning
image** that provides it. A tool's own implementation language is irrelevant to
placement — what matters is the thing being validated (see the placement rule).

## Placement rule

1. If the thing being validated matches a supported language image (rust, node,
   python, media, cpp, go, java), the tool lives **in that image** (native).
2. Cross-cutting validators with no language home stay in **base** as pinned
   lightweight binaries/pip.
3. A tool written in X but validating something else does **not** move to the X
   image (e.g. lychee is Rust but validates URLs → `-rust` because lychee is the
   rust image's tool; actionlint is Go but validates workflows → base).

## Table

| Command | Tool | Written in | Owning image |
| --- | --- | --- | --- |
| `sh lint` | shellcheck | Haskell | base |
| `dockerfile lint` | `docker build --check` | Go (BuildKit) | base (needs socket) |
| `structure lint` | (bash) | bash | base |
| `ignore lint` | (bash) | bash | base |
| `git` / `gh` / `docker` / `opencode` | git / gh / docker / opencode | Go / Go / Go / TS | base |
| `url` | lychee | Rust | rust |
| `rust lint` / `rust test` | cargo clippy / cargo test | Rust | rust |
| `md lint` | markdownlint-cli | JavaScript | node |
| `json lint` / `tasks lint` | jq | C | node |
| `typescript` / `javascript` / `node` | tsc/npm / eslint/node | TypeScript/JavaScript | node |
| `yml lint` | yamllint | Python | python |
| `python lint` / `python test` | py_compile / pytest | Python | python |
| `pdf lint` | pdfinfo (poppler) | C++ | media |
| `png/jpg/… lint` | identify (ImageMagick) | C | media |
| `mp4/… scan` / `compress` | ffprobe / ffmpeg | C | media |
| `cpp lint` / `cpp test` | clang-format / g++ | C++ | cpp |
| `go lint` / `go test` | gofmt/vet / go test | Go | go |
| `java lint` / `java test` | mvn checkstyle / mvn test | Java | java |

## How to see coverage

`cli integration list` prints the tool → image table; `cli integration check`
reports what the current image has and which image provides anything missing.

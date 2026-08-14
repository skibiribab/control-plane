# Commands

Model: **`cli <noun> <verb>`** — noun = file extension · language · concept.

Run `cli <noun> --help` for details. If a command's tool is missing from the
current image, `cli` fails and recommends the owning image.

## File-type nouns

| Noun | Verb | Tool | Image |
| --- | --- | --- | --- |
| `sh` | lint | shellcheck | orphanage |
| `actions` | lint | actionlint | orphanage |
| `dockerfile` | lint | `docker build --check` (needs socket) | orphanage |
| `structure` | lint | `config/tree.json` (node) or `config/tree.txt` | orphanage |
| `whitespace` | lint | trailing-whitespace scan | orphanage |
| `ignore` | lint | enforce `.gitignore` allowlist + `.dockerignore` (`.git` only) | orphanage |
| `url` | (default) | lychee | orphanage |
| `pdf` | lint | qpdf / pdfinfo (poppler) | orphanage |
| `tex` | build | latexmk over `*.tex` | orphanage |
| `check` | (default) | image-adaptive: run every generic-lint verb the current image has, skip missing tools | current image |
| `md` | lint / link / table | markdownlint-cli · internal links · marked tables | node |
| `json` | lint | node (`JSON.parse`) | node |
| `tasks` | lint | node (`tasks/tasks.pairs.json`) | node |
| `tree` | generate / validate | sha256/size layout manifest | node |
| `repo` | lint | composite: md lint+link+table, json, structure, whitespace | node |
| `yml` / `yaml` | lint | yamllint | python |
| `png` `jpg` `jpeg` `gif` `webp` `svg` `bmp` | lint | identify (ImageMagick) | media |
| `mp4` `mov` `mkv` `webm` | scan / compress | ffprobe / ffmpeg | media |

## Language nouns

| Noun | lint | test | Image |
| --- | --- | --- | --- |
| `rust` | cargo clippy | cargo test | rust |
| `cpp` | clang-format | g++ compile | cpp |
| `go` | gofmt + go vet | go test | go |
| `java` | mvn checkstyle / gradle check | mvn/gradle test | java |
| `python` | py_compile | pytest | python |
| `typescript` | tsc/npm run lint | npm test | node |
| `javascript` | node --check / eslint | npm test | node |
| `node` | runtime passthrough (`version`, `check`, npm) | — | node |

## Ops nouns

| Noun | What |
| --- | --- |
| `git` | git passthrough + `branch`/`log`/`diff`/`rev-list` composites + `zip`/`backup`/`restore`/`export` |
| `gh` | passthrough + issue CRUD (`create`/`update`/`delete`/`comment`) + recipes (`issue pick`/`plan`/`craft pr`) + Projects v2 (`project list/view/create/update/delete` + `item list/add/remove`) + `release`/`policy list` |
| `docker` | monitor/cleanup (`ps` `containers` `images` `stats` `df` `stop` `reset` …) |
| `opencode` | setup / `plan` `summarize` `code` `categorize` / chat sessions (ai image) |
| `integration` | `list` (tool→image) / `check` (current image coverage) |

## Common flags

- `[PATH]` — **one** target: a specific file, or a subtree root to scan
  recursively for matching files (default `.`).
- `--config FILE` — a tool-native config path passed through to the tool
  (e.g. `.markdownlint.json`, `.yamllint`, `lychee.toml`, `tree.json`,
  `link-policy.json`). Precedence: `--config` > env > auto-detect.
- `--json` — machine-readable output for lint commands.
- `--yes` — confirm write operations (`cli docker …`).

Every file-type lint finds files under `PATH`, lists them, and validates each
one individually, reporting per-file findings (`cli repo lint` runs the whole
markdown/notes suite in the `-node` image).

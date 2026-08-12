# Architecture

`cli` is a **bash** CLI: a thin dispatcher plus thin wrappers around existing
tools. There is no application framework and no Python.

## Layout

```
cli              dispatcher: resolves the noun, sources its file(s), runs cli_<noun>_main
lib/             shared bash libraries (no command logic)
  common.sh      logging, exit codes, version (VERSION file)
  env.sh         pure-env config lookup + defaults
  json.sh        printf-based JSON emit + bounded contract extractor
  tools.sh       tool -> owning-image registry + require_tool
  report.sh      ok/skipped/fail/result (text + JSON)
  files.sh       iter_files / noun_args / collect_files
  media.sh       pdf/png/video lint/scan/compress helpers
src/commands/    one file per noun, grouped by owning image
  base/          sh.sh dockerfile.sh structure.sh ignore.sh git.sh gh.sh docker.sh opencode.sh integration.sh
  rust/ node/ python/ media/ cpp/ go/ java/
docker/          Dockerfiles (multi-stage) + runtime/install-*.sh + versions.env
scripts/         build/release/PR pipeline helpers (bash)
```

## Dispatch

`cli <noun> <verb>` → `cli` sources every `src/commands/*/<noun>.sh`, then calls
`cli_<noun>_main "$@"`. A noun file's `cli_<noun>_main` switches on the verb
(`lint`/`test`/`scan`/`compress` or a passthrough command).

## Tool routing

- `lib/tools.sh` maps each binary to the image that owns it.
- `require_tool <bin>` fails with an image recommendation when the binary is
  missing (e.g. `cli md lint` in `-base` → "Use the node image").
- Each Dockerfile bakes `ENV CLI_RUNTIME=<image>` so messages know the current
  image.
- `cli integration check` reports the current image's coverage from the same
  registry.

## Images

Alpine base (version-pinned) → `docker/{base,rust,node,python,media,cpp,go,java}.dockerfile`.
Multi-stage: a `src` stage does `COPY . .` (whole context); the `final` stage
installs the toolchain (`docker/runtime/install-*.sh`, pinned in `versions.env`)
and copies only the relevant artifacts (`/cli /lib /commands /VERSION`) to
`/opt/cli`, then symlinks `/usr/local/bin/cli`. The binary exists only inside
the built image; the repo carries source only.

## Ignore-file policy

`cli ignore lint` enforces the repo's own `.gitignore` / `.dockerignore`
contract: `.dockerignore` ignores only `.git`; `.gitignore` is a forbid-all
(`*`) allowlist with paired `!dir/` + `!dir/**` entries.

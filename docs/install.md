# Install

The CLI ships **in Docker images** (bash, no Python). There is no pip/PyPI
package. Versioned tags are published to Docker Hub as
`binarylifter/gardusig-cli`.

## Docker (recommended)

Pull the image for the toolchain you need and run `cli` against a mounted repo:

```bash
alias cli='docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0'
alias cli-node='docker run --rm -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0-node'

cli git status
cli-node md lint .
```

Tags: `:1.2.0` (base) and `-rust`, `-node`, `-python`, `-media`, `-cpp`, `-go`,
`-java`. See [docker.md](docker.md) for the full table.

## Configuration (env only)

Everything is an environment variable with a built-in default — no config
files. Common ones:

| Variable | Purpose |
| --- | --- |
| `GITHUB_TOKEN` / `GH_TOKEN` | GitHub auth (`cli gh`) |
| `DEEPSEEK_API_KEY` | opencode/gh AI recipes |
| `OPENCODE_CONFIG` | opencode config path |
| `CLI_OPENCODE_MODEL` | default model |
| `CLI_GH_MAX_ROUNDS` | gh plan round cap (legacy; use `CLI_GH_PLAN_ROUNDS`) |
| `CLI_GH_PLAN_ROUNDS` | opencode plan rounds (default 3, max 5) |
| `CLI_GH_EXEC_RUNS` | opencode execution passes (default 3, max 5) |
| `CLI_GH_MAX_PR` | max open PRs (default 3) |
| `CLI_GH_MAX_COMMITS_PR` | max commits per PR (default 10) |
| `CLI_GH_MAX_COMMENTS_PR` | max comments per PR (default 5) |
| `CLI_GH_MAX_COMMENTS_ISSUE` | max comments per issue (default 32) |
| `CLI_GH_MAX_PARENTS` | max parent (epic) issues (default 8) |
| `CLI_GH_MAX_CHILDREN` | max children per parent (default 16) |
| `CLI_COMPRESS_CRF` | video compress quality |
| `CLI_MD_CONFIG` | markdownlint config path (`md lint`) |
| `CLI_YML_CONFIG` | yamllint config path (`yml lint`) |
| `CLI_URL_CONFIG` | lychee config path (`url`) |
| `CLI_LINK_POLICY` | cross-folder link policy (`md link`) |
| `CLI_TREE` | layout manifest (`structure lint`) |
| `CLI_JSON=1` | JSON output for lint commands |
| `CLI_RUNTIME` | baked-in image variant (base/rust/node/…) |

Config precedence: `--config FILE` flag > env var > the tool's native auto-detect.

In Docker, pass with `-e`:

```bash
docker run --rm -e GITHUB_TOKEN="$GITHUB_TOKEN" -v "$PWD:/repo" -w /repo \
  binarylifter/gardusig-cli:1.2.0 gh issue pick
```

## Using gh locally

`cli gh` uses the `gh` CLI and its local auth (`gh auth login`) or
`GITHUB_TOKEN`/`GH_TOKEN` — no separate CLI config is needed.

## Requirements per command

Each command needs its owning image's tools. `cli integration check` reports
what's present in the current image and which image provides anything missing.

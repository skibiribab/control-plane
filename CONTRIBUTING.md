# Contributing

Thanks for contributing to `control-plane`.

## Conventions

- Editor rules live in `.editorconfig` + `.vscode/settings.json`.
- CLI model is `cli <noun> <verb>`; commands are thin wrappers over existing tools.
- Bash scripts: `set -euo pipefail`, shellcheck-clean.
- Reusable stage workflows must keep the self-guard (`github.repository != 'gardusig/control-plane'`).

## PR workflow

1. Branch from `main`.
2. Make a focused change.
3. `test.yml` gates pull requests — keep it green.
4. Open a PR into `main`.

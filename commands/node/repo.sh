#!/usr/bin/env bash
# cli repo lint — composite markdown/notes validation (node image).
# Runs md lint + md link + md table + json lint + structure lint +
# whitespace lint over one PATH.
set -euo pipefail

cli_repo_help() {
  cat <<'EOF'
cli repo lint [PATH] [--config FILE] [--json] — run all markdown/notes checks:
  md lint · md link · md table · json lint · structure lint · whitespace lint
Runs in the -node image. PATH: a single file or a subtree root (default ".").
EOF
}

cli_repo_main() {
  case "${1:-}" in
    -h|--help) cli_repo_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli repo lint [PATH] [--config FILE] [--json]"
  fi
  shift

  # shellcheck source=/dev/null
  source "${CLI_ROOT}/commands/node/md.sh"
  # shellcheck source=/dev/null
  source "${CLI_ROOT}/commands/node/json.sh"
  # shellcheck source=/dev/null
  source "${CLI_ROOT}/commands/base/structure.sh"
  # shellcheck source=/dev/null
  source "${CLI_ROOT}/commands/base/whitespace.sh"

  local overall=0
  cli_md_main lint "$@" || overall=1
  cli_md_main link "$@" || overall=1
  cli_md_main table "$@" || overall=1
  cli_json_main lint "$@" || overall=1
  cli_structure_main lint "$@" || overall=1
  cli_whitespace_main lint "$@" || overall=1
  if ((overall == 0)); then
    cli_ok "repo lint ok"
  fi
  return "$overall"
}

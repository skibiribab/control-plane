#!/usr/bin/env bash
# cli repo lint|publish-tag — composite validation + release tagging (node image).
set -euo pipefail

cli_repo_help() {
  cat <<'EOF'
cli repo lint [PATH] [--config FILE] [--json] — run all markdown/notes checks:
  md lint · md link · md table · json lint · structure lint · whitespace lint
cli repo publish-tag — create a unique timestamp tag, push it, and verify it
             landed at the latest commit.
Runs in the -node image. PATH: a single file or a subtree root (default ".").
EOF
}

cli_repo_main() {
  case "${1:-}" in
    -h|--help) cli_repo_help; return 0 ;;
    lint) shift ;;
    publish-tag)
      require_tool node
      node "$CLI_ROOT/lib/validators/publish-tag.js" "$PWD" publish
      return 0
      ;;
    *) cli_die "usage: cli repo lint [PATH] [--config FILE] [--json] | cli repo publish-tag" ;;
  esac

  # shellcheck source=/dev/null
  source "${CLI_ROOT}/commands/node/md.sh"
  # shellcheck source=/dev/null
  source "${CLI_ROOT}/commands/node/json.sh"
  # shellcheck source=/dev/null
  source "${CLI_ROOT}/commands/orphanage/structure.sh"
  # shellcheck source=/dev/null
  source "${CLI_ROOT}/commands/orphanage/whitespace.sh"

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

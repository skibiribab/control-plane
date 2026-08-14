#!/usr/bin/env bash
# cli whitespace lint — trailing whitespace over text files (orphanage image).
# shellcheck disable=SC2317,SC2034  # callbacks invoked via lint_each
set -euo pipefail

cli_whitespace_help() {
  cat <<'EOF'
cli whitespace lint [PATH] [--config FILE] [--json] — trailing whitespace check
over .md .js .json .yml .yaml .txt (orphanage image).
--config: file listing paths to skip (one per line).
PATH: a single file or a subtree root to scan (default ".").
EOF
}

cli_whitespace_main() {
  case "${1:-}" in
    -h|--help) cli_whitespace_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli whitespace lint [PATH] [--config FILE] [--json]"
  fi
  shift
  noun_args "$@"

  ws_check_one() {
    local rel="$1" line_no=0 line last
    while IFS= read -r line; do
      line_no=$((line_no + 1))
      last="${line: -1}"
      if [[ "$last" == " " || "$last" == $'\t' ]]; then
        FAIL_MSG="trailing whitespace at line ${line_no}"
        return 1
      fi
    done < "${WS}/${rel}"
  }

  lint_each "whitespace lint" ws_check_one "*.md" "*.js" "*.json" "*.yml" "*.yaml" "*.txt"
}

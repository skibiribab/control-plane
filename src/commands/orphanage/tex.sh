#!/usr/bin/env bash
# cli tex build — latexmk -pdf over *.tex (orphanage image, TeX stack).
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

cli_tex_help() {
  cat <<'EOF'
cli tex build [PATH] [--json] — latexmk -pdf over *.tex (orphanage image).
PATH: a single file or a subtree root to scan (default ".").
EOF
}

cli_tex_main() {
  case "${1:-}" in
    -h|--help) cli_tex_help; return 0 ;;
  esac
  if [[ "${1:-}" != "build" ]]; then
    cli_die "usage: cli tex build [PATH] [--json]"
  fi
  shift
  noun_args "$@"
  require_tool latexmk

  tex_build_one() {
    local rel="$1"
    lint_capture "$WS" latexmk -pdf -interaction=nonstopmode -halt-on-error "$rel"
  }

  lint_each "tex build" tex_build_one "*.tex"
}

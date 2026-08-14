#!/usr/bin/env bash
# cli pdf lint — PDF openability (qpdf) + readability (pdfinfo) over *.pdf
# (orphanage image). Used by `cli check` and as the PDF pass for `cli tree`.
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

cli_pdf_help() {
  cat <<'EOF'
cli pdf lint [PATH] [--json] — qpdf --check + pdfinfo over *.pdf (orphanage image).
PATH: a single file or a subtree root to scan (default ".").
EOF
}

cli_pdf_main() {
  case "${1:-}" in
    -h|--help) cli_pdf_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli pdf lint [PATH] [--json]"
  fi
  shift
  noun_args "$@"
  require_tool qpdf
  require_tool pdfinfo

  pdf_check_one() {
    local rel="$1"
    if ! qpdf --check --password= "$rel" >/dev/null 2>&1; then
      printf 'bad pdf (qpdf --check): %s\n' "$rel" >&2
      return 1
    fi
    lint_capture "$WS" pdfinfo "$rel"
  }

  lint_each "pdf lint" pdf_check_one "*.pdf"
}

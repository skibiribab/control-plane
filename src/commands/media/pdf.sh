#!/usr/bin/env bash
# cli pdf lint — pdfinfo over *.pdf (media image).
set -euo pipefail

cli_pdf_help() {
  printf 'cli pdf lint [PATH] [--json] — pdfinfo over *.pdf (media image).\n'
}

cli_pdf_main() {
  case "${1:-}" in
    -h|--help) cli_pdf_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli pdf lint [PATH] [--json]"
  fi
  shift
  media_pdf_lint "$@"
}

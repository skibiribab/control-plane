#!/usr/bin/env bash
# cli bmp lint — identify integrity over *.bmp (media image).
set -euo pipefail

cli_bmp_help() {
  printf 'cli bmp lint [PATH] [--json] — identify over *.bmp (media image).\n'
}

cli_bmp_main() {
  case "${1:-}" in
    -h|--help) cli_bmp_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli bmp lint [PATH] [--json]"
  fi
  shift
  media_image_lint "bmp" "$@"
}

#!/usr/bin/env bash
# cli jpeg lint — identify integrity over *.jpeg (media image).
set -euo pipefail

cli_jpeg_help() {
  printf 'cli jpeg lint [PATH] [--json] — identify over *.jpeg (media image).\n'
}

cli_jpeg_main() {
  case "${1:-}" in
    -h|--help) cli_jpeg_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli jpeg lint [PATH] [--json]"
  fi
  shift
  media_image_lint "jpeg" "$@"
}

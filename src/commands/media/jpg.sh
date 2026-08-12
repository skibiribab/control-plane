#!/usr/bin/env bash
# cli jpg lint — identify integrity over *.jpg (media image).
set -euo pipefail

cli_jpg_help() {
  printf 'cli jpg lint [PATH] [--json] — identify over *.jpg (media image).\n'
}

cli_jpg_main() {
  case "${1:-}" in
    -h|--help) cli_jpg_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli jpg lint [PATH] [--json]"
  fi
  shift
  media_image_lint "jpg" "$@"
}

#!/usr/bin/env bash
# cli png lint — identify integrity over *.png (media image).
set -euo pipefail

cli_png_help() {
  printf 'cli png lint [PATH] [--json] — identify over *.png (media image).\n'
}

cli_png_main() {
  case "${1:-}" in
    -h|--help) cli_png_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli png lint [PATH] [--json]"
  fi
  shift
  media_image_lint "png" "$@"
}

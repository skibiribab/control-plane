#!/usr/bin/env bash
# cli svg lint — identify integrity over *.svg (media image).
set -euo pipefail

cli_svg_help() {
  printf 'cli svg lint [PATH] [--json] — identify over *.svg (media image).\n'
}

cli_svg_main() {
  case "${1:-}" in
    -h|--help) cli_svg_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli svg lint [PATH] [--json]"
  fi
  shift
  media_image_lint "svg" "$@"
}

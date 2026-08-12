#!/usr/bin/env bash
# cli gif lint — identify integrity over *.gif (media image).
set -euo pipefail

cli_gif_help() {
  printf 'cli gif lint [PATH] [--json] — identify over *.gif (media image).\n'
}

cli_gif_main() {
  case "${1:-}" in
    -h|--help) cli_gif_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli gif lint [PATH] [--json]"
  fi
  shift
  media_image_lint "gif" "$@"
}

#!/usr/bin/env bash
# cli webp lint — identify integrity over *.webp (media image).
set -euo pipefail

cli_webp_help() {
  printf 'cli webp lint [PATH] [--json] — identify over *.webp (media image).\n'
}

cli_webp_main() {
  case "${1:-}" in
    -h|--help) cli_webp_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli webp lint [PATH] [--json]"
  fi
  shift
  media_image_lint "webp" "$@"
}

#!/usr/bin/env bash
# cli webm scan|compress — ffprobe/ffmpeg over *.webm (media image).
set -euo pipefail

cli_webm_help() {
  printf 'cli webm scan|compress [PATH] [--crf N] — ffprobe/ffmpeg over *.webm (media image).\n'
}

cli_webm_main() {
  case "${1:-}" in
    -h|--help) cli_webm_help; return 0 ;;
    scan) shift; media_video_scan "webm" "$@" ;;
    compress) shift; media_video_compress "webm" "$@" ;;
    *) cli_die "usage: cli webm scan|compress [PATH]" ;;
  esac
}

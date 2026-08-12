#!/usr/bin/env bash
# cli mkv scan|compress — ffprobe/ffmpeg over *.mkv (media image).
set -euo pipefail

cli_mkv_help() {
  printf 'cli mkv scan|compress [PATH] [--crf N] — ffprobe/ffmpeg over *.mkv (media image).\n'
}

cli_mkv_main() {
  case "${1:-}" in
    -h|--help) cli_mkv_help; return 0 ;;
    scan) shift; media_video_scan "mkv" "$@" ;;
    compress) shift; media_video_compress "mkv" "$@" ;;
    *) cli_die "usage: cli mkv scan|compress [PATH]" ;;
  esac
}

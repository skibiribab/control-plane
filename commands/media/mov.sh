#!/usr/bin/env bash
# cli mov scan|compress — ffprobe/ffmpeg over *.mov (media image).
set -euo pipefail

cli_mov_help() {
  printf 'cli mov scan|compress [PATH] [--crf N] — ffprobe/ffmpeg over *.mov (media image).\n'
}

cli_mov_main() {
  case "${1:-}" in
    -h|--help) cli_mov_help; return 0 ;;
    scan) shift; media_video_scan "mov" "$@" ;;
    compress) shift; media_video_compress "mov" "$@" ;;
    *) cli_die "usage: cli mov scan|compress [PATH]" ;;
  esac
}

#!/usr/bin/env bash
# cli mp4 scan|compress — ffprobe/ffmpeg over *.mp4 (media image).
set -euo pipefail

cli_mp4_help() {
  printf 'cli mp4 scan|compress [PATH] [--crf N] — ffprobe/ffmpeg over *.mp4 (media image).\n'
}

cli_mp4_main() {
  case "${1:-}" in
    -h|--help) cli_mp4_help; return 0 ;;
    scan) shift; media_video_scan "mp4" "$@" ;;
    compress) shift; media_video_compress "mp4" "$@" ;;
    *) cli_die "usage: cli mp4 scan|compress [PATH]" ;;
  esac
}

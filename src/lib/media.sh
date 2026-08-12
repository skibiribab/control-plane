#!/usr/bin/env bash
# Shared helpers for media nouns (pdf/png/jpg/.../mp4/...). Thin per-extension
# wrappers live in commands/media/ and delegate here.
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

# media_image_lint <ext> [PATH] [--json] — identify integrity over *.<ext>.
media_image_lint() {
  local ext="$1"
  shift
  noun_args "$@"
  require_tool identify

  image_check_one() {
    local rel="$1"
    lint_capture "$WS" identify "$rel"
  }

  lint_each "${ext} lint" image_check_one "*.${ext}"
}

# media_pdf_lint [PATH] [--json] — pdfinfo readability over *.pdf.
media_pdf_lint() {
  noun_args "$@"
  require_tool pdfinfo

  pdf_check_one() {
    local rel="$1"
    lint_capture "$WS" pdfinfo "$rel"
  }

  lint_each "pdf lint" pdf_check_one "*.pdf"
}

# media_video_scan <ext> [PATH] — ffprobe over *.<ext>.
media_video_scan() {
  local ext="$1"
  shift
  noun_args "$@"
  require_tool ffprobe

  scan_check_one() {
    local rel="$1"
    lint_capture "$WS" ffprobe -v error -show_entries format=duration,size \
      -of default=noprint_wrappers=1 "$rel"
  }

  lint_each "${ext} scan" scan_check_one "*.${ext}"
}

# media_video_compress <ext> [PATH] [--crf N] — ffmpeg recompress *.<ext>.
media_video_compress() {
  local ext="$1"
  shift
  local crf
  crf="$(env_or CLI_COMPRESS_CRF 28)"
  local target="."
  while (($# > 0)); do
    case "$1" in
      --crf) crf="$2"; shift 2 ;;
      *) target="$1"; shift ;;
    esac
  done
  noun_args "$target"
  require_tool ffmpeg

  compress_check_one() {
    local rel="$1" out
    out="${rel%.*}.h264.${ext}"
    lint_capture "$WS" ffmpeg -y -i "$rel" -c:v libx264 -crf "$crf" -preset medium "$out"
  }

  lint_each "${ext} compress" compress_check_one "*.${ext}"
}

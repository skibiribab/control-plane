#!/usr/bin/env bash
# Install the media domain: ffmpeg + imagemagick (image lint) + poppler (pdf lint).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "ffmpeg=${APK_FFMPEG}" \
  "imagemagick=${APK_IMAGEMAGICK}" \
  "poppler-utils=${APK_POPPLER_UTILS}"

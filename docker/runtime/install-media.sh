#!/usr/bin/env bash
# Install the media domain: ffmpeg (video) + imagemagick (image).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "ffmpeg=${APK_FFMPEG}" \
  "imagemagick=${APK_IMAGEMAGICK}"

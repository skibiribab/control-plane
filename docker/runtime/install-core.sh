#!/usr/bin/env bash
# Install the minimal core shared by every image: bash shelling + curl/coreutils.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "coreutils=${APK_COREUTILS}" \
  "curl=${APK_CURL}" \
  "ca-certificates=${APK_CA_CERTIFICATES}"

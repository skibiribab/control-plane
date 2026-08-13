#!/usr/bin/env bash
# Install the python domain: python3 + yamllint.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "python3=${APK_PYTHON3}" \
  "yamllint=${APK_YAMLLINT}"

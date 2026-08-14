#!/usr/bin/env bash
# Install the rust domain: rust/cargo toolchain.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "rust=${APK_RUST}" \
  "cargo=${APK_CARGO}"

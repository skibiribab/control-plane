#!/usr/bin/env bash
# Install the go domain: golang toolchain.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache "go=${APK_GO}"

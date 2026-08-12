#!/usr/bin/env bash
# Install the cpp domain: gcc/g++/make/cmake/clang-format.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "gcc=${APK_GCC}" \
  "g++=${APK_GPP}" \
  "make=${APK_MAKE}" \
  "cmake=${APK_CMAKE}" \
  "clang19=${APK_CLANG}" \
  "clang19-extra-tools=${APK_CLANG_EXTRA_TOOLS}"

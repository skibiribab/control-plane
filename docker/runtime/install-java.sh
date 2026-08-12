#!/usr/bin/env bash
# Install the java domain: OpenJDK 21 / Maven / Gradle.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "openjdk21-jdk=${APK_OPENJDK21}" \
  "maven=${APK_MAVEN}" \
  "gradle=${APK_GRADLE}"

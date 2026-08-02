#!/usr/bin/env bash
# Install the base tier: core shelling tools + the no-language validators.
# Everything comes from apk (musl-native) except opencode (static binary).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "bash=${APK_BASH}" \
  "git=${APK_GIT}" \
  "curl=${APK_CURL}" \
  "ca-certificates=${APK_CA_CERTIFICATES}" \
  "coreutils=${APK_COREUTILS}" \
  "zip=${APK_ZIP}" \
  "unzip=${APK_UNZIP}" \
  "tar=${APK_TAR}" \
  "docker-cli=${APK_DOCKER_CLI}" \
  "github-cli=${APK_GITHUB_CLI}" \
  "shellcheck=${APK_SHELLCHECK}" \
  "actionlint=${APK_ACTIONLINT}"

# Let git operate on host-mounted repositories regardless of ownership.
git config --global --add safe.directory '*'

# Pinned static binary (version-pinned release).
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

_install_opencode() {
  local url="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64.tar.gz"
  curl --fail --location --silent --show-error -o "$tmp/opencode.tar.gz" "$url"
  tar -xzf "$tmp/opencode.tar.gz" -C "$tmp"
  install -m 0755 "$tmp/opencode" /usr/local/bin/opencode
}

_install_opencode

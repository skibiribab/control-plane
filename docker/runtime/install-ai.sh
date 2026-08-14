#!/usr/bin/env bash
# Install the AI agent set: opencode (the code-gen engine) plus the ops CLIs the
# agent loop needs (pull → plan → build → git → gh). Language toolchains are NOT
# included — the agent shells out to skibiribab/cli:<v>-<lang> images via docker.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

# libstdc++ is opencode's only runtime dependency on Alpine (musl build links
# libstdc++/libgcc); git/gh/docker-cli are shelled-out commands, not deps.
apk add --no-cache \
  "git=${APK_GIT}" \
  "github-cli=${APK_GITHUB_CLI}" \
  "docker-cli=${APK_DOCKER_CLI}" \
  "libstdc++=${APK_LIBSTDCXX}"

# Let git operate on host-mounted repositories regardless of ownership.
git config --global --add safe.directory '*'

# opencode: pinned static binary (no node runtime needed). Alpine is musl, so
# use the musl build.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# _download <url> <out> — retry on transient failures (the default bridge
# network's DNS is flaky; "Could not resolve host" must not abort image builds).
_download() {
  local url="$1" out="$2"
  local attempt=1
  while (( attempt <= 5 )); do
    if curl --fail --location --silent --show-error -o "$out" "$url"; then
      return 0
    fi
    echo "download attempt ${attempt}/5 failed: ${url}" >&2
    attempt=$((attempt + 1))
    (( attempt <= 5 )) && sleep "$((attempt * 2))"
  done
  return 1
}

_install_opencode() {
  local url="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64-musl.tar.gz"
  _download "$url" "$tmp/opencode.tar.gz"
  tar -xzf "$tmp/opencode.tar.gz" -C "$tmp"
  install -m 0755 "$tmp/opencode" /usr/local/bin/opencode
}

_install_opencode

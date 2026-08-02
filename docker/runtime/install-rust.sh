#!/usr/bin/env bash
# Install the rust domain: rust/cargo toolchain + lychee (musl binary).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "rust=${APK_RUST}" \
  "cargo=${APK_CARGO}"

# lychee: pinned musl build (no Alpine apk package).
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl --fail --location --silent --show-error \
  -o "$tmp/lychee.tar.gz" \
  "https://github.com/lycheeverse/lychee/releases/download/lychee-v${LYCHEE_VERSION}/lychee-x86_64-unknown-linux-musl.tar.gz"
tar -xzf "$tmp/lychee.tar.gz" -C "$tmp"
install -m 0755 "$tmp/lychee-x86_64-unknown-linux-musl/lychee" /usr/local/bin/lychee

#!/usr/bin/env bash
# Install the node domain: node/npm + markdownlint + jq (JSON validation).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "nodejs=${APK_NODEJS}" \
  "npm=${APK_NPM}" \
  "jq=${APK_JQ}"

npm install --global --no-audit --no-fund \
  "markdownlint-cli@${MARKDOWNLINT_CLI_VERSION}"

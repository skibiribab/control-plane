#!/usr/bin/env bash
# Install the python domain: python3/pip + codespell, yamllint.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "python3=${APK_PYTHON3}" \
  "py3-pip=${APK_PY3_PIP}" \
  "yamllint=${APK_YAMLLINT}"

pip install --break-system-packages --no-cache-dir \
  "codespell==${CODESPELL_VERSION}" \
  "chardet==${CODESPELL_CHARDET}" \
  "tomli==${CODESPELL_TOMLI}"

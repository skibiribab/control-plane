#!/usr/bin/env bash
# Install the orphanage set: language-agnostic standalone CLIs — ops passthroughs,
# generic linters, JSON/PDF/link utilities, and the TeX typesetting stack.
# Everything is a self-contained CLI (apk or pinned static binary).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/versions.env"

apk add --no-cache \
  "git=${APK_GIT}" \
  "github-cli=${APK_GITHUB_CLI}" \
  "docker-cli=${APK_DOCKER_CLI}" \
  "zip=${APK_ZIP}" \
  "unzip=${APK_UNZIP}" \
  "tar=${APK_TAR}" \
  "shellcheck=${APK_SHELLCHECK}" \
  "actionlint=${APK_ACTIONLINT}" \
  "jq=${APK_JQ}" \
  "qpdf=${APK_QPDF}" \
  "poppler-utils=${APK_POPPLER_UTILS}"

# TeX stack. texlive's post-install runs `fmtutil --all`, which tries to build
# every format in the tree; a few exotic ones (pTeX/upTeX family, pdftex
# variants like mex/csplain/jadetex) fail because their engine/macro packages
# are not installed. Those formats are not needed — pdflatex/xelatex/lualatex
# and latexmk build fine. Tolerate that post-install failure and verify the
# binaries afterwards so a real install failure still aborts.
apk add --no-cache \
  "texlive=${APK_TEXLIVE}" \
  "texlive-luatex=${APK_TEXLIVE_LUATEX}" \
  "texlive-xetex=${APK_TEXLIVE_XETEX}" \
  "texlive-binextra=${APK_TEXLIVE_BINEXTRA}" \
  "texlive-dvi=${APK_TEXLIVE_DVI}" \
  || true
command -v pdflatex >/dev/null || { echo "pdflatex missing after texlive install" >&2; exit 1; }
command -v latexmk >/dev/null || { echo "latexmk missing after texlive install" >&2; exit 1; }

# Let git operate on host-mounted repositories regardless of ownership.
git config --global --add safe.directory '*'

# Pinned static binaries (version-pinned release).
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

# lychee: pinned musl build (no Alpine apk package).
_install_lychee() {
  local url="https://github.com/lycheeverse/lychee/releases/download/lychee-v${LYCHEE_VERSION}/lychee-x86_64-unknown-linux-musl.tar.gz"
  _download "$url" "$tmp/lychee.tar.gz"
  tar -xzf "$tmp/lychee.tar.gz" -C "$tmp"
  install -m 0755 "$tmp/lychee-x86_64-unknown-linux-musl/lychee" /usr/local/bin/lychee
}

# docker-buildx: pinned static binary, installed as the docker CLI plugin so
# `docker build --check` (cli dockerfile lint) works from inside the image.
_install_buildx() {
  local url="https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64"
  _download "$url" "$tmp/docker-buildx"
  mkdir -p /usr/local/lib/docker/cli-plugins
  install -m 0755 "$tmp/docker-buildx" /usr/local/lib/docker/cli-plugins/docker-buildx
}

_install_lychee
_install_buildx

#!/usr/bin/env bash
# Smoke a runtime image variant: pinned tools present + variant lint paths +
# distinctness (no other language/ops toolchains).
#   Usage: bash src/scripts/release/runtime-smoke.sh <image> <variant>
#   variant: orphanage | node | python | rust | cpp | go | java | media | ai
set -euo pipefail

image="${1:?image required}"
variant="${2:?variant required}"
fixtures="${RUNTIME_FIXTURES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../tests/fixtures/runtime" && pwd)}"

_in_container() {
  docker run --rm \
    -v "${fixtures}:/repo:ro" \
    -w /repo \
    --entrypoint bash \
    "${image}" \
    -ec "${1}"
}

# assert_present <marker>... — the image must provide each tool.
_assert_present() {
  local marker
  for marker in "$@"; do
    _in_container "command -v ${marker} >/dev/null 2>&1" \
      || { echo "missing tool in ${variant} image: ${marker}" >&2; exit 1; }
  done
}

# assert_absent <marker>... — distinctness gate: must NOT carry other
# language/ops toolchains.
_assert_absent() {
  local marker
  for marker in "$@"; do
    if _in_container "command -v ${marker} >/dev/null 2>&1"; then
      echo "unexpected tool present in ${variant} image: ${marker}" >&2
      exit 1
    fi
  done
}

_in_container 'cli --version >/dev/null'

case "$variant" in
  orphanage)
    _assert_present git gh docker jq shellcheck actionlint qpdf pdfinfo lychee latexmk curl zip tar
    _assert_absent node python3 go rustc cargo g++ java ffmpeg opencode markdownlint
    _in_container 'cli sh lint .'
    ;;
  node)
    _assert_present node npm markdownlint
    _assert_absent git gh docker jq qpdf shellcheck actionlint lychee python3 go rustc cargo g++ java ffmpeg opencode
    _in_container 'cli json lint good.json'
    _in_container 'cli md lint README.md'
    ;;
  python)
    _assert_present python3 yamllint
    _assert_absent node git gh docker qpdf shellcheck actionlint go rustc cargo g++ java ffmpeg markdownlint opencode
    _in_container 'cli yml lint good.yaml'
    if _in_container 'cli yml lint bad.yaml' >/dev/null 2>&1; then
      echo "expected failure on bad.yaml but lint passed" >&2
      exit 1
    fi
    ;;
  rust)
    _assert_present rustc cargo
    _assert_absent node python3 go g++ java ffmpeg lychee git gh markdownlint opencode
    ;;
  cpp)
    _assert_present g++ gcc make cmake clang-format
    _assert_absent node python3 go rustc cargo java ffmpeg git markdownlint opencode
    ;;
  go)
    _assert_present go
    _assert_absent node python3 rustc cargo g++ java ffmpeg git markdownlint opencode
    ;;
  java)
    _assert_present java mvn gradle
    _assert_absent node python3 go rustc cargo g++ ffmpeg git markdownlint opencode
    ;;
  media)
    _assert_present ffmpeg identify
    _assert_absent node python3 go rustc cargo g++ java pdfinfo qpdf git markdownlint opencode
    ;;
  ai)
    _assert_present opencode git gh docker
    _assert_absent node python3 go rustc cargo g++ java ffmpeg markdownlint qpdf jq lychee shellcheck actionlint
    _in_container 'opencode --version >/dev/null 2>&1'
    ;;
  *)
    echo "unknown variant: ${variant}" >&2
    exit 2
    ;;
esac

# markdown lint must NOT work in non-node images (missing-tool recommendation)
if [[ "$variant" != "node" ]]; then
  if _in_container 'cli md lint README.md' >/dev/null 2>&1; then
    echo "expected missing-tool failure for cli md lint in ${variant}" >&2
    exit 1
  fi
fi

echo "runtime smoke ok: ${image} (${variant})"

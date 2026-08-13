#!/usr/bin/env bash
# Smoke a runtime image variant: pinned tools present + variant lint paths +
# distinctness (no other language toolchains).
#   Usage: bash src/scripts/release/runtime-smoke.sh <image> [variant]
#   variant: base (default) | rust | node | python | cpp | go | media | java
set -euo pipefail

image="${1:?image required}"
variant="${2:-base}"
fixtures="${RUNTIME_FIXTURES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../tests/fixtures/runtime" && pwd)}"

_in_container() {
  docker run --rm \
    -v "${fixtures}:/repo:ro" \
    -w /repo \
    --entrypoint bash \
    "${image}" \
    -ec "${1}"
}

# assert_absent <marker>... — distinctness gate: the image must NOT contain
# other language toolchains. Guards against accidental cross-contamination.
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

# base tools (inherited by every variant)
for tool in \
  "git --version" \
  "gh --version" \
  "docker --version" \
  "zip --version" \
  "tar --version" \
  "shellcheck --version" \
  "actionlint --version"; do
  _in_container "${tool} >/dev/null 2>&1"
done

case "$variant" in
  base)
    _in_container 'cli integration list >/dev/null'
    _in_container 'cli gh policy list | grep -Fq pr-merge'
    _in_container 'cli sh lint .'
    _assert_absent node python3 go rustc cargo g++ javac mvn gradle ffmpeg markdownlint lychee
    ;;
  rust)
    for tool in "cargo --version" "rustc --version" "lychee --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _in_container 'cli url'
    _assert_absent node python3 go javac mvn gradle ffmpeg markdownlint
    ;;
  node)
    for tool in "node --version" "npm --version" "markdownlint --version" "jq --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _in_container 'cli json lint good.json'
    _in_container 'cli md lint README.md'
    _assert_absent python3 go rustc cargo g++ javac mvn gradle ffmpeg lychee
    ;;
  python)
    for tool in "python3 --version" "yamllint --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _in_container 'cli yml lint good.yaml'
    if _in_container 'cli yml lint bad.yaml' >/dev/null 2>&1; then
      echo "expected failure on bad.yaml but lint passed" >&2
      exit 1
    fi
    _assert_absent node go rustc cargo g++ javac mvn gradle ffmpeg lychee markdownlint
    ;;
  cpp)
    for tool in "g++ --version" "cmake --version" "clang-format --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _assert_absent node python3 go rustc cargo javac mvn gradle ffmpeg lychee markdownlint
    ;;
  go)
    _in_container 'go version'
    _assert_absent node python3 rustc cargo javac mvn gradle ffmpeg lychee markdownlint
    ;;
  media)
    for tool in "ffmpeg -version" "identify -version" "pdfinfo -v"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _assert_absent node python3 go rustc cargo g++ javac mvn gradle lychee markdownlint
    ;;
  java)
    for tool in "java -version" "mvn --version" "gradle --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _assert_absent node python3 go rustc cargo g++ ffmpeg lychee markdownlint
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

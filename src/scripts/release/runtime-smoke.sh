#!/usr/bin/env bash
# Smoke a runtime image variant: pinned tools present + variant lint paths.
#   Usage: bash scripts/release/runtime-smoke.sh <image> [variant]
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
    ;;
  rust)
    for tool in "cargo --version" "rustc --version" "lychee --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _in_container 'cli url'
    ;;
  node)
    for tool in "node --version" "npm --version" "markdownlint --version" "jq --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _in_container 'cli json lint good.json'
    _in_container 'cli md lint README.md'
    ;;
  python)
    for tool in "python3 --version" "yamllint --version" "codespell --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    _in_container 'cli yml lint good.yaml'
    if _in_container 'cli yml lint bad.yaml' >/dev/null 2>&1; then
      echo "expected failure on bad.yaml but lint passed" >&2
      exit 1
    fi
    ;;
  cpp)
    for tool in "g++ --version" "cmake --version" "clang-format --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    ;;
  go)
    _in_container 'go version'
    ;;
  media)
    for tool in "ffmpeg -version" "identify -version" "pdfinfo -v"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
    ;;
  java)
    for tool in "java -version" "mvn --version" "gradle --version"; do
      _in_container "${tool} >/dev/null 2>&1"
    done
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

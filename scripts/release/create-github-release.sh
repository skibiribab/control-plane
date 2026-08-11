#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

# Create GitHub release for tag vX.Y.Z (PyPI/Docker use X.Y.Z without v).

tag="${RELEASE_TAG:?RELEASE_TAG required}"
version="${CLI_VERSION:?CLI_VERSION required}"

if command -v gh >/dev/null 2>&1 && [[ -n "${GH_TOKEN:-}" ]]; then
  gh_args=()
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    gh_args+=(-R "$GITHUB_REPOSITORY")
  fi
  if gh release view "$tag" "${gh_args[@]}" >/dev/null 2>&1; then
    echo "GitHub release already exists: $tag"
    exit 0
  fi
  gh release create "$tag" \
    "${gh_args[@]}" \
    --title "$tag" \
    --notes "Release **gardusig-cli ${version}**

- Docker: \`${RUNTIME_IMAGE:-binarylifter/gardusig-cli}:${version}\` (+ \`-base\`/\`-rust\`/\`-node\`/\`-python\`/\`-cpp\`/\`-go\`/\`-media\`/\`-java\`)"
  echo "Created GitHub release $tag"
  exit 0
fi

echo "Install gh and set GH_TOKEN to create release automatically."
echo "Tag ${tag} — publish gardusig-cli ${version} at ${RUNTIME_IMAGE:-binarylifter/gardusig-cli}:${version} on Docker Hub."

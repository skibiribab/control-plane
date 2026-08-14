#!/usr/bin/env bash
# Build every runtime image variant (versioned tags only, no :latest).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

version="${CLI_VERSION:?CLI_VERSION required}"
root="$(gh_repo_root)"
cd "$root"

for variant in "${RUNTIME_VARIANTS[@]}"; do
  docker build -f "$(runtime_variant_dockerfile "$variant")" \
    -t "$(runtime_variant_tag "$version" "$variant")" .
done

echo "built runtime images: ${RUNTIME_IMAGE}:${version}-* (${RUNTIME_VARIANTS[*]})"

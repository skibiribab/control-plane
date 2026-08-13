#!/usr/bin/env bash
# Ensure skibiribab-cli inside the runtime image matches the Docker version tag.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

expected="${CLI_VERSION:?CLI_VERSION required}"
if command -v docker >/dev/null 2>&1 && [[ -n "${RUNTIME_IMAGE:-}" ]]; then
  got="$(docker run --rm "${RUNTIME_IMAGE}:${expected}" --version)"
else
  got="$(cli --version)"
fi
if [[ "$got" != "$expected" ]]; then
  echo "runtime version mismatch: tag ${expected}, cli --version ${got}" >&2
  exit 1
fi
echo "runtime version ok: ${expected}"

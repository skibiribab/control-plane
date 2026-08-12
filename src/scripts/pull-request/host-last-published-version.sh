#!/usr/bin/env bash
# Host-only helper: print the greatest version tag (v?X.Y.Z) in this repo
# (empty when none yet). Used as BASE_VERSION for the version gate.
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

git tag --sort=-v:refname 2>/dev/null \
  | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' \
  | head -n1 \
  | sed 's/^v//' \
  || true

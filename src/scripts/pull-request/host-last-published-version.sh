#!/usr/bin/env bash
# Host-only helper: print the greatest release tag (bare X.Y.Z, no v prefix)
# in this repo (empty when none yet). Used as the git side of the version gate.
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

git tag --sort=-v:refname 2>/dev/null \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | head -n1 \
  || true

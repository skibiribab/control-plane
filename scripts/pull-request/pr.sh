#!/usr/bin/env bash
# PR publish path: version gate → bats unit tests.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$dir/version-check.sh"
bash "$dir/unit-test.sh"

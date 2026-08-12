#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

stage_run_with_timeout "${CI_UNIT_TIMEOUT:-5m}" bats --print-output-on-failure tests

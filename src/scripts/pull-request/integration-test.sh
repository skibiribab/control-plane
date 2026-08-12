#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

stage_ensure_dev
stage_run_with_timeout "${CI_INTEGRATION_TIMEOUT}" bash "$(dirname "${BASH_SOURCE[0]}")/integration-smoke.sh"

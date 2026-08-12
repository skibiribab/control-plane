#!/usr/bin/env bash
# Read-only integration smoke — assumes `cli` is installed on PATH.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/_smoke.sh"

smoke_run_all

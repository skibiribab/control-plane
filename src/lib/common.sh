#!/usr/bin/env bash
# Common helpers: logging, exit codes, version.
set -euo pipefail

CLI_VERSION_FILE="${CLI_ROOT}/VERSION"

cli_version() {
  if [[ -f "${CLI_VERSION_FILE}" ]]; then
    tr -d '[:space:]' < "${CLI_VERSION_FILE}"
  else
    echo "unknown"
  fi
}

cli_log() {
  printf '%s\n' "$*" >&2
}

cli_die() {
  cli_log "cli: $*"
  exit 1
}

cli_ok() {
  printf 'ok: %s\n' "$*"
}

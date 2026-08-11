#!/usr/bin/env bash
# cli node — node.js runtime passthrough (node image).
set -euo pipefail

cli_node_help() {
  cat <<'EOF'
cli node — node.js runtime passthrough.

Usage: cli node version | check <file> | <node-args...>
  cli node version            print node/npm versions
  cli node check <file>       node --check a JS file
  cli node <args...>          passthrough to node
EOF
}

cli_node_main() {
  if (($# == 0)); then
    cli_node_help
    return 0
  fi
  case "$1" in
    -h|--help) cli_node_help; return 0 ;;
    version) require_tool node; node --version; npm --version ;;
    check) require_tool node; node --check "${2:?file required}" ;;
    *) require_tool node; node "$@" ;;
  esac
}

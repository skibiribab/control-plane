#!/usr/bin/env bash
# Pure-env configuration: every setting is an env var with a built-in default.
# No config files, no JSON, no jq. In a container, pass values with -e.
set -euo pipefail

# env_or <var> <default> — print the env value or the default.
env_or() {
  local var="$1" default="${2:-}"
  if [[ -n "${!var:-}" ]]; then
    printf '%s' "${!var}"
  else
    printf '%s' "$default"
  fi
}

# env_bool <var> <default:0|1> — true when value is 1/true/yes/on.
env_bool() {
  local var="$1" default="${2:-0}"
  case "${!var:-}" in
    1|true|yes|on) return 0 ;;
    *) [[ "$default" == "1" ]] && return 0 || return 1 ;;
  esac
}

# env_int <var> <default> — print an integer env value or the default.
env_int() {
  local v="${!1:-}"
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    printf '%s' "$v"
  else
    printf '%s' "${2:-0}"
  fi
}

# env_capped <var> <default> <max> — integer env clamped to a hard max.
env_capped() {
  local v
  v="$(env_int "$1" "$2")"
  if ((v > ${3:-999})); then
    v="${3}"
  fi
  printf '%s' "$v"
}

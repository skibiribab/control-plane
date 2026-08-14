#!/usr/bin/env bash
# cli opencode — AI prompts, chat sessions, setup (orphanage image).
set -euo pipefail

cli_opencode_help() {
  cat <<'EOF'
cli opencode — AI interactions through the opencode CLI.

Usage: cli opencode <command> [args...]

  setup                      print the env vars to export (API key + model)
  plan|summarize|code|categorize "prompt"    one-shot prompt tiers
  chat new <name>            start a chat session
  chat distill <session>     distill a session
  chat categorize <session>  categorize a session
  <opencode-args...>         passthrough to opencode

Env: DEEPSEEK_API_KEY, OPENCODE_CONFIG, CLI_OPENCODE_MODEL.
EOF
}

opencode_require() {
  require_tool opencode
}

opencode_setup() {
  local model
  model="$(env_or CLI_OPENCODE_MODEL deepseek/deepseek-reasoner)"
  if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
    printf 'export OPENCODE_CONFIG=%s\n' "${OPENCODE_CONFIG:-}"
    printf 'export CLI_OPENCODE_MODEL=%s\n' "$model"
    cli_ok "DEEPSEEK_API_KEY is set — opencode will use it"
  else
    printf '# paste your key: export DEEPSEEK_API_KEY=<your-key>\n'
    printf 'export CLI_OPENCODE_MODEL=%s\n' "$model"
    cli_die "DEEPSEEK_API_KEY is not set — export it (or run: cli opencode setup)"
  fi
}

opencode_tier() {
  shift
  opencode_require
  local prompt="$1"
  shift || true
  opencode run "$prompt" "${@}"
}

opencode_chat() {
  local sub="${1:-}"
  case "$sub" in
    ""|-h|--help) cli_opencode_help; return 0 ;;
    new) opencode_require; opencode chat --continue "${2:?session name required}" ;;
    distill) opencode_require; opencode chat --continue --distill "${2:?session required}" ;;
    categorize) opencode_require; opencode chat --continue --categorize "${2:?session required}" ;;
    *) cli_die "unknown opencode chat subcommand: ${sub}" ;;
  esac
}

cli_opencode_main() {
  if (($# == 0)); then
    cli_opencode_help
    return 0
  fi
  case "$1" in
    -h|--help) cli_opencode_help; return 0 ;;
    setup) opencode_setup ;;
    plan|summarize|code|categorize) opencode_tier "$1" "${@:2}" ;;
    chat) shift; opencode_chat "$@" ;;
    *) opencode_require; opencode "$@" ;;
  esac
}

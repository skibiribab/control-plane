#!/usr/bin/env bash
# cli check — run every generic-lint verb the current image supports, skipping
# any whose tool isn't present (image-adaptive). Generic lints only: language
# test/build stay explicit verbs (`cli <lang> test`). This is the universal
# "validate this repo as thoroughly as this image can" entrypoint.
set -euo pipefail

cli_check_help() {
  cat <<'EOF'
cli check [PATH] [--json] — run every generic lint the current image provides.
PATH: a single file or a subtree root to scan (default ".").
Missing tools are skipped with a "use the X image" hint.
EOF
}

cli_check_main() {
  case "${1:-}" in
    -h|--help) cli_check_help; return 0 ;;
  esac
  noun_args "$@"

  local overall=0 noun tool owner cli_bin
  cli_bin="${CLI_ROOT}/cli"
  for noun in $(check_verbs "$CLI_RUNTIME"); do
    tool="$(verb_required_tool "$noun")"
    if [[ -n "$tool" ]] && ! command -v "$tool" >/dev/null 2>&1; then
      owner="$(tool_image "$tool")"
      printf 'check skip: %s lint — use the %s image (skibiribab/cli:%s-%s)\n' \
        "$noun" "$owner" "$(cli_version)" "$owner"
      continue
    fi
    if "$cli_bin" "$noun" lint "$@"; then
      :
    else
      printf 'check fail: %s lint\n' "$noun" >&2
      overall=1
    fi
  done
  if ((overall == 0)); then
    cli_ok "check ok (${CLI_RUNTIME})"
  fi
  return "$overall"
}

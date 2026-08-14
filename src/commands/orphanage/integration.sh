#!/usr/bin/env bash
# cli integration — per-image tool/language coverage introspection.
set -euo pipefail

cli_integration_help() {
  cat <<'EOF'
cli integration — per-image tool/language coverage.

Usage: cli integration list | check

  list    print the tool -> owning image table + the per-image cli verb sets
  check   report tools present/missing in this image and which image provides
          each missing tool
EOF
}

cli_integration_main() {
  local cmd="${1:-}"
  case "$cmd" in
    ""|-h|--help) cli_integration_help; return 0 ;;
    list)
      printf 'image\ttool\n'
      all_tools | sort
      printf '\nimage\tverbs (cli <verb> lint ...)\n'
      all_verbs | sort
      ;;
    check)
      printf 'current image: %s\n' "$CLI_RUNTIME"
      printf 'present:\n'
      local image tool
      local -a present=() missing=()
      while IFS=$'\t' read -r image tool; do
        if command -v "$tool" >/dev/null 2>&1; then
          present+=("  ${tool} (${image})")
        else
          missing+=("  ${tool} -> ${image} image")
        fi
      done < <(all_tools)
      printf '%s\n' "${present[@]:-  (none)}"
      if ((${#missing[@]} > 0)); then
        printf 'missing (use the owning image):\n%s\n' "${missing[@]}"
      else
        cli_ok "all tools for this image are present"
      fi
      printf 'check verbs for this image: %s\n' "$(check_verbs "$CLI_RUNTIME")"
      ;;
    *) cli_die "unknown integration command: ${cmd}" ;;
  esac
}

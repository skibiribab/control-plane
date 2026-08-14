#!/usr/bin/env bash
# cli structure lint — enforce a layout manifest (orphanage image).
# Supports config/tree.txt (bash) and config/tree.json (node validator).
set -euo pipefail

cli_structure_help() {
  cat <<'EOF'
cli structure lint [PATH] [--config FILE] [--json] — enforce layout manifest.
--config: tree.json or tree.txt (tool-native); default config/tree.json then
          config/tree.txt.
PATH: a single file or a subtree root to scan (default ".").
EOF
}

cli_structure_main() {
  case "${1:-}" in
    -h|--help) cli_structure_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli structure lint [PATH] [--config FILE] [--json]"
  fi
  shift
  noun_args "$@"

  local manifest
  if [[ -n "$CONFIG" ]]; then
    manifest="$CONFIG"
  else
    manifest="$(env_or CLI_TREE "")"
    if [[ -z "$manifest" ]]; then
      if [[ -f "${WS}/config/tree.json" ]]; then
        manifest="${WS}/config/tree.json"
      else
        manifest="${WS}/config/tree.txt"
      fi
    fi
  fi

  # No tree manifest configured -> skip (a repo without the convention isn't a
  # failure; `repo lint`/`cli check` stay a safe generic default for any repo).
  if [[ -z "$manifest" || ! -e "$manifest" ]]; then
    printf 'structure lint skipped: no tree manifest (config/tree.json|txt)\n'
    return 0
  fi

  if [[ "$manifest" == *.json ]]; then
    require_tool node
    if [[ ! -f "$manifest" ]]; then
      report_fail "structure lint" "tree.json not found: ${manifest}"
      return 1
    fi
    if lint_capture "$WS" node "$CLI_ROOT/lib/validators/tree.js" "$WS" "$manifest"; then
      report_ok "structure lint" 0
    else
      report_result "structure lint" 0 "$FAIL_MSG"
      return 1
    fi
    return 0
  fi

  # tree.txt (bash)
  if [[ ! -f "$manifest" ]]; then
    report_fail "structure lint" "tree.txt not found: ${manifest}"
    return 1
  fi
  local -a errors=() roots=()
  local in_root=0 line root
  while IFS= read -r line; do
    if [[ "$line" == "root:" ]]; then in_root=1; continue; fi
    if [[ "$line" =~ ^[a-z] ]]; then in_root=0; fi
    if ((in_root)) && [[ "$line" == "  - "* ]]; then roots+=("${line#  - }"); fi
  done < "$manifest"
  for root in "${roots[@]}"; do
    [[ -e "${WS}/${root}" ]] || errors+=("missing required root: ${root}")
  done
  local name entry
  for entry in "${WS}"/*; do
    [[ -e "$entry" ]] || continue
    name="${entry##*/}"
    [[ "$name" == ".git" ]] && continue
    if ! [[ " ${roots[*]} " == *" $name "* ]]; then
      errors+=("unexpected top-level entry: ${name}")
    fi
  done
  if ((${#errors[@]})); then
    printf '%s\n' "${errors[@]}" >&2
    report_fail "structure lint" "layout violations"
    return 1
  fi
  report_ok "structure lint" "${#roots[@]}"
}

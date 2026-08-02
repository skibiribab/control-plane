#!/usr/bin/env bash
# cli ignore lint — validate .gitignore (allowlist) and .dockerignore (only .git).
set -euo pipefail

cli_ignore_help() {
  cat <<'EOF'
cli ignore lint [PATH] [--json] — validate .gitignore + .dockerignore policy.

Policy:
  .dockerignore  effective patterns (non-comment) must be exactly `.git`.
  .gitignore     forbid-all `*` first, then only `!` allowlist entries;
                 every `!dir/` needs a matching `!dir/**` (and vice versa);
                 allowed roots must exist in the repo.
EOF
}

# ignore_violations <workspace> — fills VIOLATIONS with "file<TAB>message".
ignore_violations() {
  VIOLATIONS=()
  local ws="$1" f line lineno seen_star entry
  local -a dir_entries=() glob_entries=() allow=()
  local -a seen=()

  # --- .dockerignore ---
  f="${ws}/.dockerignore"
  if [[ ! -f "$f" ]]; then
    VIOLATIONS+=(".dockerignore\tmissing file")
  else
    lineno=0
    while IFS= read -r line; do
      lineno=$((lineno + 1))
      [[ -z "$line" ]] && continue
      [[ "$line" == \#* ]] && continue
      if [[ "$line" != ".git" ]]; then
        VIOLATIONS+=(".dockerignore\tline ${lineno}: only '.git' allowed, got: ${line}")
      fi
    done < "$f"
  fi

  # --- .gitignore ---
  f="${ws}/.gitignore"
  if [[ ! -f "$f" ]]; then
    VIOLATIONS+=(".gitignore\tmissing file")
    return 0
  fi
  lineno=0
  seen_star=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    if [[ "$seen_star" -eq 0 ]]; then
      if [[ "$line" == "*" ]]; then
        seen_star=1
      else
        VIOLATIONS+=(".gitignore\tline ${lineno}: must start with '*' (forbid-all)")
      fi
      continue
    fi
    if [[ "$line" != !* ]]; then
      VIOLATIONS+=(".gitignore\tline ${lineno}: only allowlist '!' entries allowed after '*': ${line}")
      continue
    fi
    entry="${line#!}"
    if [[ " ${seen[*]} " == *" $entry "* ]]; then
      VIOLATIONS+=(".gitignore\tduplicate allowlist entry: ${entry}")
    else
      seen+=("$entry")
    fi
    if [[ ! -e "${ws}/${entry%%/*}" ]]; then
      VIOLATIONS+=(".gitignore\tallowed root does not exist: ${entry%%/*}")
    fi
    if [[ "$entry" == */\*\* ]]; then
      glob_entries+=("${entry%/**}")
      allow+=("${line}")
    elif [[ "$entry" == */ ]]; then
      dir_entries+=("${entry%/}")
      allow+=("${line}")
    else
      allow+=("${line}")
    fi
  done < "$f"
  if [[ "$seen_star" -eq 0 ]]; then
    VIOLATIONS+=(".gitignore\tmissing '*' forbid-all")
  fi

  local d
  for d in "${dir_entries[@]}"; do
    if ! printf '%s\n' "${glob_entries[@]}" | grep -qx "$d"; then
      VIOLATIONS+=(".gitignore\t'!${d}/' has no matching '!${d}/**'")
    fi
  done
  for d in "${glob_entries[@]}"; do
    if ! printf '%s\n' "${dir_entries[@]}" | grep -qx "$d"; then
      VIOLATIONS+=(".gitignore\t'!${d}/**' has no matching '!${d}/'")
    fi
  done
}

cli_ignore_main() {
  case "${1:-}" in
    -h|--help) cli_ignore_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli ignore lint [PATH] [--json]"
  fi
  shift
  noun_args "$@"
  ignore_violations "$WS"
  local failures="" v
  for v in "${VIOLATIONS[@]}"; do
    failures+="$(printf '%s\n' "$v")"
  done
  report_result "ignore lint" 2 "$failures"
}

#!/usr/bin/env bash
# cli cpp lint|test — clang-format / g++ (cpp image).
set -euo pipefail

cli_cpp_help() {
  cat <<'EOF'
cli cpp lint [PATH] — clang-format --dry-run --Werror over C/C++ sources.
cli cpp test [PATH] — g++ compile (or smoke) of C/C++ sources.
EOF
}

cli_cpp_main() {
  case "${1:-}" in
    -h|--help) cli_cpp_help; return 0 ;;
    lint)
      shift
      noun_args "$@"
      require_tool clang-format
      collect_files "*.cpp" "*.hpp" "*.h" "*.c" "*.cc" "*.cxx"
      if ((${#FILES[@]} == 0)); then report_skipped "cpp lint"; return 0; fi
      local failures="" rel f
      for f in "${FILES[@]}"; do
        rel="${f#"$WS"/}"
        if ! (cd "$WS" && clang-format --dry-run --Werror "$rel") >/dev/null 2>&1; then
          failures+="$(printf '%s\tclang-format needed\n' "$rel")"
        fi
      done
      report_result "cpp lint" "${#FILES[@]}" "$failures"
      ;;
    test)
      shift
      noun_args "$@"
      require_tool g++
      local src
      src="$(iter_files "$WS" "*.cpp" | head -n1)"
      if [[ -z "$src" ]]; then report_skipped "cpp test"; return 0; fi
      (cd "$WS" && g++ -fsyntax-only "${src#"$WS"/}") || { printf 'cpp test failed\n' >&2; return 1; }
      cli_ok "cpp test ok"
      ;;
    *) cli_die "usage: cli cpp lint|test [PATH]" ;;
  esac
}

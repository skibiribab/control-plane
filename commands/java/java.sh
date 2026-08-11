#!/usr/bin/env bash
# cli java lint|test — mvn checkstyle / gradle check + tests (java image).
set -euo pipefail

cli_java_help() {
  cat <<'EOF'
cli java lint [PATH] — mvn checkstyle:check or gradle check.
cli java test [PATH] — mvn test or gradle test.
EOF
}

cli_java_main() {
  case "${1:-}" in
    -h|--help) cli_java_help; return 0 ;;
    lint)
      shift
      noun_args "$@"
      if [[ -f "${WS}/pom.xml" ]]; then
        require_tool mvn
        (cd "$WS" && mvn -q checkstyle:check)
      elif [[ -f "${WS}/build.gradle" || -f "${WS}/build.gradle.kts" ]]; then
        require_tool gradle
        (cd "$WS" && gradle check --no-daemon)
      else
        cli_die "no java build file found (pom.xml or build.gradle)"
      fi
      cli_ok "java lint ok"
      ;;
    test)
      shift
      noun_args "$@"
      if [[ -f "${WS}/pom.xml" ]]; then
        require_tool mvn
        (cd "$WS" && mvn -q test)
      else
        require_tool gradle
        (cd "$WS" && gradle test --no-daemon)
      fi
      cli_ok "java test ok"
      ;;
    *) cli_die "usage: cli java lint|test [PATH]" ;;
  esac
}

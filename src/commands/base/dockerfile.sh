#!/usr/bin/env bash
# cli dockerfile lint — `docker build --check` (base image, docker socket).
set -euo pipefail

cli_dockerfile_help() {
  cat <<'EOF'
cli dockerfile lint [PATH] [--json] — validate Dockerfiles via `docker build --check`.
Requires the docker daemon socket: mount /var/run/docker.sock.
EOF
}

cli_dockerfile_main() {
  case "${1:-}" in
    -h|--help) cli_dockerfile_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli dockerfile lint [PATH] [--json]"
  fi
  shift
  noun_args "$@"
  require_tool docker
  if ! docker info >/dev/null 2>&1; then
    cli_die "docker daemon not reachable: mount the docker socket (-v /var/run/docker.sock:/var/run/docker.sock)"
  fi
  collect_files "Dockerfile" "Dockerfile.*" "*.dockerfile"
  if ((${#FILES[@]} == 0)); then report_skipped "dockerfile lint"; return 0; fi
  local failures="" rel f
  for f in "${FILES[@]}"; do
    rel="${f#"$WS"/}"
    if ! (cd "$WS" && docker build --check -f "$rel" .) >/dev/null 2>&1; then
      failures+="$(printf '%s\t' "$rel")"
    fi
  done
  report_result "dockerfile lint" "${#FILES[@]}" "$failures"
}

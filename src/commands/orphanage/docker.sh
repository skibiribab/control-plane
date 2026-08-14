#!/usr/bin/env bash
# cli docker — monitor/cleanup via the docker CLI (orphanage image, socket).
set -euo pipefail

cli_docker_help() {
  cat <<'EOF'
cli docker — docker monitor and cleanup.

Usage: cli docker <command> [args...] [--format json|table] [--yes]

Read:
  ps           running containers (--name FILTER)
  containers   all containers (--status exited, --name FILTER)
  images       images (--repository REPO)
  stats        top CPU/memory consumers
  df           disk usage summary

Cleanup (require --yes):
  stop                 stop running containers
  container-delete     docker rm -f (names/ids)
  image-delete         prune unused images
  reset                stop + remove all + prune
EOF
}

docker_require_daemon() {
  require_tool docker
  docker info >/dev/null 2>&1 || cli_die "docker daemon not reachable: mount the socket"
}

docker_confirm() {
  if [[ "${CLI_YES:-0}" != "1" ]]; then
    cli_die "$1 requires --yes"
  fi
}

docker_ps() {
  docker_require_daemon
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' "$@"
}

docker_containers() {
  docker_require_daemon
  docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}' "$@"
}

docker_images() {
  docker_require_daemon
  docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' "$@"
}

docker_stats() {
  docker_require_daemon
  docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
}

docker_df() {
  docker_require_daemon
  docker system df
}

docker_stop() {
  docker_require_daemon
  docker_confirm "docker stop"
  local ids id
  ids="$(docker ps -q)"
  if [[ -z "$ids" ]]; then
    cli_ok "no running containers to stop"
    return 0
  fi
  for id in $ids; do
    docker stop "$id"
  done
  cli_ok "stopped running containers"
}

docker_container_delete() {
  docker_require_daemon
  docker_confirm "docker container-delete"
  local ids id
  ids="$(docker ps -aq)"
  if [[ -z "$ids" ]]; then
    cli_ok "no containers to delete"
    return 0
  fi
  for id in $ids; do
    docker rm -f "$id"
  done
  cli_ok "removed containers"
}

docker_image_delete() {
  docker_require_daemon
  docker_confirm "docker image-delete"
  docker image prune -af
  cli_ok "pruned unused images"
}

docker_reset() {
  docker_require_daemon
  docker_confirm "docker reset"
  local ids id
  ids="$(docker ps -aq)"
  if [[ -n "$ids" ]]; then
    for id in $ids; do
      docker stop "$id" >/dev/null 2>&1 || true
    done
    for id in $ids; do
      docker rm -f "$id" >/dev/null 2>&1 || true
    done
  fi
  docker image prune -af
  cli_ok "docker reset complete"
}

cli_docker_main() {
  CLI_YES=0
  local -a passthru=()
  while (($# > 0)); do
    case "$1" in
      --yes) CLI_YES=1; shift ;;
      --format) shift 2 ;;
      *) passthru+=("$1"); shift ;;
    esac
  done
  local cmd="${passthru[0]:-}"
  unset 'passthru[0]' || true
  case "$cmd" in
    ""|-h|--help) cli_docker_help; return 0 ;;
    ps) docker_ps "${passthru[@]}" ;;
    containers) docker_containers "${passthru[@]}" ;;
    images) docker_images "${passthru[@]}" ;;
    stats) docker_stats "${passthru[@]}" ;;
    df) docker_df "${passthru[@]}" ;;
    stop) docker_stop ;;
    container-delete) docker_container_delete ;;
    image-delete) docker_image_delete ;;
    reset) docker_reset ;;
    *) cli_die "unknown docker command: ${cmd} (run 'cli docker --help')" ;;
  esac
}

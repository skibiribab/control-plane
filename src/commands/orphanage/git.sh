#!/usr/bin/env bash
# cli git — git passthrough + archive/backup operations (orphanage image).
set -euo pipefail

cli_git_help() {
  cat <<'EOF'
cli git — passthrough to git (orphanage image).

Usage: cli git <git-args...>
  cli git status · cli git log --oneline -10
  cli git branch current | list
  cli git log oneline [--base X --head Y]
  cli git diff stat [--base X --head Y]
  cli git rev-list count [--base X --head Y]
  cli git zip <tag>                  git archive zip into dist/
  cli git backup [PATH] [--password P] [--out F]    zip archive of a tree
  cli git restore <archive> [--into DIR] [--password P]   extract archive
  cli git export [--tag T] [--out F] git archive tar.gz of the repo
EOF
}

cli_git_main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cli_git_help
    return 0
  fi
  # CLI_GIT_ROOT targets a specific repo (e.g. the integration smoke's temp
  # repo); unset = operate on the current directory.
  if [[ -n "${CLI_GIT_ROOT:-}" ]]; then
    cd "$CLI_GIT_ROOT" 2>/dev/null || cli_die "CLI_GIT_ROOT not accessible: ${CLI_GIT_ROOT}"
  fi
  if (($# == 0)); then
    git status
    return $?
  fi
  case "$1" in
    zip)
      local tag="${2:?tag required}"
      mkdir -p dist
      git archive --format=zip -o "dist/${tag}.zip" "$tag"
      cli_ok "git zip ${tag}"
      ;;
    backup)
      shift
      local target="." pass="" out=""
      while (($# > 0)); do
        case "$1" in
          --password) pass="$2"; shift 2 ;;
          --out) out="$2"; shift 2 ;;
          *) target="$1"; shift ;;
        esac
      done
      require_tool zip
      local ws stamp
      ws="$(realpath "$target" 2>/dev/null || realpath -m "$target")"
      [[ -d "$ws" ]] || cli_die "backup target is not a directory: ${target}"
      mkdir -p dist
      stamp="$(date +%Y%m%d-%H%M%S)"
      out="${out:-dist/backup-${stamp}.zip}"
      if [[ -n "$pass" ]]; then
        (cd "$ws" && zip -qr -P "$pass" "$OLDPWD/${out}" .)
      else
        (cd "$ws" && zip -qr "$OLDPWD/${out}" .)
      fi
      cli_ok "backup written to ${out}"
      ;;
    restore)
      shift
      local archive="" into="." pass=""
      while (($# > 0)); do
        case "$1" in
          --password) pass="$2"; shift 2 ;;
          --into) into="$2"; shift 2 ;;
          *) archive="$1"; shift ;;
        esac
      done
      [[ -n "$archive" ]] || cli_die "restore requires an archive path"
      [[ -f "$archive" ]] || cli_die "archive not found: ${archive}"
      mkdir -p "$into"
      case "$archive" in
        *.zip)
          require_tool unzip
          if [[ -n "$pass" ]]; then unzip -P "$pass" -o "$archive" -d "$into"
          else unzip -o "$archive" -d "$into"; fi
          ;;
        *.tar.gz|*.tgz|*.tar)
          require_tool tar
          tar -xf "$archive" -C "$into"
          ;;
        *) cli_die "unsupported archive type: ${archive}" ;;
      esac
      cli_ok "restored ${archive} into ${into}"
      ;;
    export)
      shift
      local tag="" out=""
      while (($# > 0)); do
        case "$1" in
          --tag) tag="$2"; shift 2 ;;
          --out) out="$2"; shift 2 ;;
          *) cli_die "unknown export arg: $1" ;;
        esac
      done
      require_tool git
      git rev-parse --show-toplevel >/dev/null 2>&1 || cli_die "not a git repository"
      local ref="${tag:-HEAD}"
      mkdir -p dist
      out="${out:-dist/repo-${ref}.tar.gz}"
      git archive --format=tar.gz -o "$out" "$ref"
      cli_ok "exported ${ref} to ${out}"
      ;;
    branch)
      case "${2:-}" in
        current) git rev-parse --abbrev-ref HEAD ;;
        list) git branch --list ;;
        *) git branch "${@:2}" ;;
      esac
      ;;
    log)
      if [[ "${2:-}" == "oneline" ]]; then
        shift 2
        local base="" head=""
        while (($# > 0)); do
          case "$1" in
            --base) base="$2"; shift 2 ;;
            --head) head="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        if [[ -n "$base" && -n "$head" ]]; then git log --oneline "$base..$head"
        else git log --oneline; fi
      else
        git log "${@:2}"
      fi
      ;;
    diff)
      if [[ "${2:-}" == "stat" ]]; then
        shift 2
        local base="" head=""
        while (($# > 0)); do
          case "$1" in
            --base) base="$2"; shift 2 ;;
            --head) head="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        git diff --stat "$base" "$head"
      else
        git diff "${@:2}"
      fi
      ;;
    rev-list)
      if [[ "${2:-}" == "count" ]]; then
        shift 2
        local base="" head=""
        while (($# > 0)); do
          case "$1" in
            --base) base="$2"; shift 2 ;;
            --head) head="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        git rev-list --count "$base..$head"
      else
        git rev-list "${@:2}"
      fi
      ;;
    *) git "$@" ;;
  esac
}

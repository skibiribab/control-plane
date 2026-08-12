#!/usr/bin/env bash
# cli tree generate|validate — integrity manifest over a subtree (node image).
# shellcheck disable=SC2317  # callbacks invoked via cli_tree_main
set -euo pipefail

cli_tree_help() {
  cat <<'EOF'
cli tree generate [PATH] [--manifest FILE] — write an integrity manifest
             (path, sha256, size) for every file under PATH.
cli tree validate [PATH] [--manifest FILE] [--pdf] [--images] — verify the
             manifest: hashes + sizes, PDF openability (qpdf, --pdf), and
             image signatures (--images).

PATH: subtree root to scan (default ".").
--manifest: manifest path (default scripts/tree.json).
EOF
}

cli_tree_main() {
  local verb="${1:-}"
  case "$verb" in
    -h|--help) cli_tree_help; return 0 ;;
    generate|validate) shift ;;
    *) cli_die "usage: cli tree generate|validate [PATH] [--manifest FILE] [--pdf] [--images]" ;;
  esac

  TREE_MANIFEST="${CLI_TREE_MANIFEST:-scripts/tree.json}"
  local tree_pdf=0 tree_images=0 args=()
  while (($# > 0)); do
    case "$1" in
      --manifest) TREE_MANIFEST="${2:-}"; shift 2 ;;
      --pdf) tree_pdf=1; shift ;;
      --images) tree_images=1; shift ;;
      *) args+=("$1"); shift ;;
    esac
  done
  noun_args "${args[@]}"

  [[ "$TREE_MANIFEST" != /* ]] && TREE_MANIFEST="${PWD}/${TREE_MANIFEST}"

  require_tool node
  if [[ "$verb" == "generate" ]]; then
    node "$CLI_ROOT/lib/validators/generate-tree.js" "$WS" "$TREE_MANIFEST"
  else
    local -a flags=()
    ((tree_pdf)) && flags+=(--pdf)
    ((tree_images)) && flags+=(--images)
    node "$CLI_ROOT/lib/validators/validate-tree.js" "$WS" "$TREE_MANIFEST" "${flags[@]}"
  fi
}

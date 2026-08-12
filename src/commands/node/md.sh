#!/usr/bin/env bash
# cli md lint|link|table — markdown checks (node image).
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

cli_md_help() {
  cat <<'EOF'
cli md lint  [PATH] [--config FILE] [--json] — markdownlint over *.md.
cli md link [PATH] [--config FILE] [--json] — internal link integrity (targets
             exist, #anchors resolve; optional cross-folder link policy).
cli md table [PATH] [--json] — validate <!-- begin/end table --> regions.

PATH: a single file or a subtree root to scan (default ".").
--config: tool-native config (markdownlint config / link-policy.json).
EOF
}

md_lint() {
  require_tool markdownlint
  md_lint_one() {
    local rel="$1"
    if [[ -n "$CONFIG" ]]; then
      lint_capture "$WS" markdownlint --config "$CONFIG" "$rel"
    else
      lint_capture "$WS" markdownlint "$rel"
    fi
  }
  lint_each "md lint" md_lint_one "*.md" "*.mdx"
}

md_link() {
  require_tool node
  md_link_one() {
    local rel="$1"
    if [[ -n "$CONFIG" ]]; then
      lint_capture "$WS" node "$CLI_ROOT/lib/validators/links.js" "$WS" "$rel" "$CONFIG"
    else
      lint_capture "$WS" node "$CLI_ROOT/lib/validators/links.js" "$WS" "$rel"
    fi
  }
  lint_each "md link" md_link_one "*.md" "*.mdx"
}

md_table() {
  require_tool node
  md_table_one() {
    local rel="$1"
    lint_capture "$WS" node "$CLI_ROOT/lib/validators/tables.js" "$WS" "$rel"
  }
  lint_each "md table" md_table_one "*.md" "*.mdx"
}

cli_md_main() {
  case "${1:-}" in
    -h|--help) cli_md_help; return 0 ;;
    lint) shift; noun_args "$@"; md_lint ;;
    link) shift; noun_args "$@"; md_link ;;
    table) shift; noun_args "$@"; md_table ;;
    *) cli_die "usage: cli md lint|link|table [PATH] [--config FILE] [--json]" ;;
  esac
}

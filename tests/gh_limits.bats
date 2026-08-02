#!/usr/bin/env bats
# Tests for the credit-based rate limiters (lib/gh_limits.sh) with a mocked gh.

ROOT="${BATS_TEST_DIRNAME}/.."

setup() {
  export CLI_ROOT="$ROOT"
  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
  # shellcheck source=lib/env.sh
  source "$ROOT/lib/env.sh"
  # shellcheck source=lib/gh_limits.sh
  source "$ROOT/lib/gh_limits.sh"
}

mock_gh() {
  # $1 = pr-count, $2 = comment-count
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *"pr list"*) echo "${1:-0}" ;;
  *"issue view"*) echo "${2:-0}" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "require_credit passes below the limit" {
  run require_credit "x" 2 3
  [ "$status" -eq 0 ]
}

@test "require_credit aborts at the limit" {
  run require_credit "x" 3 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"limit reached"* ]]
}

@test "gh_credit_open_prs passes under the limit" {
  mock_gh 2
  export CLI_GH_MAX_PR=3
  run gh_credit_open_prs
  [ "$status" -eq 0 ]
}

@test "gh_credit_open_prs aborts at the limit" {
  mock_gh 3
  export CLI_GH_MAX_PR=3
  run gh_credit_open_prs
  [ "$status" -eq 1 ]
  [[ "$output" == *"open PR limit reached"* ]]
}

@test "gh_credit_issue_comments aborts at the limit" {
  mock_gh 0 32
  export CLI_GH_MAX_COMMENTS_ISSUE=32
  run gh_credit_issue_comments 5
  [ "$status" -eq 1 ]
  [[ "$output" == *"issue comments"* ]]
}

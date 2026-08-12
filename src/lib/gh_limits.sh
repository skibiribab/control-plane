#!/usr/bin/env bash
# Credit-based rate limiters for cli gh writes. Every mutating gh operation
# checks its limit BEFORE doing any work (crafting AI text or sending) so we
# never waste resources on a write that would be rejected.
set -euo pipefail

# require_credit <resource> <used> <limit> — abort when used >= limit.
require_credit() {
  local resource="$1" used="$2" limit="$3"
  if ((used >= limit)); then
    cli_die "${resource} limit reached (${used}/${limit})"
  fi
}

# gh_credit_open_prs — open PRs must be under CLI_GH_MAX_PR.
gh_credit_open_prs() {
  local limit used
  limit="$(env_int CLI_GH_MAX_PR 3)"
  used="$(gh pr list --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo 0)"
  require_credit "open PR" "$used" "$limit"
}

# gh_credit_issue_comments <N> — comments on an issue under CLI_GH_MAX_COMMENTS_ISSUE.
gh_credit_issue_comments() {
  local issue="$1" limit used
  limit="$(env_int CLI_GH_MAX_COMMENTS_ISSUE 32)"
  used="$(gh issue view "$issue" --json comments --jq '.comments | length' 2>/dev/null || echo 0)"
  require_credit "issue comments (#${issue})" "$used" "$limit"
}

# gh_credit_pr_comments <N> — review + issue comments on a PR under CLI_GH_MAX_COMMENTS_PR.
gh_credit_pr_comments() {
  local pr="$1" limit used reviews
  limit="$(env_int CLI_GH_MAX_COMMENTS_PR 5)"
  reviews="$(gh pr view "$pr" --json reviews --jq '.reviews | length' 2>/dev/null || echo 0)"
  used="$reviews"
  require_credit "PR comments (#${pr})" "$used" "$limit"
}

# gh_credit_commits [base] — commits on the branch under CLI_GH_MAX_COMMITS_PR.
gh_credit_commits() {
  local base="${1:-origin/main}" limit used
  limit="$(env_int CLI_GH_MAX_COMMITS_PR 10)"
  used="$(git rev-list --count "${base}..HEAD" 2>/dev/null || echo 0)"
  require_credit "commits/PR" "$used" "$limit"
}

# gh_credit_parents — open parent (epic) issues under CLI_GH_MAX_PARENTS.
gh_credit_parents() {
  local limit used epic titled
  limit="$(env_int CLI_GH_MAX_PARENTS 8)"
  epic="$(gh issue list --state open --label epic --limit 100 --json number --jq 'length' 2>/dev/null || echo 0)"
  titled="$(gh issue list --state open --limit 100 --json title --jq '[.[] | select(.title | test("^[0-9]+ — "))] | length' 2>/dev/null || echo 0)"
  used=$((epic + titled))
  require_credit "parent issues" "$used" "$limit"
}

# gh_credit_children <parent> — children under a parent under CLI_GH_MAX_CHILDREN.
gh_credit_children() {
  local parent="$1" limit used labeled titled
  limit="$(env_int CLI_GH_MAX_CHILDREN 16)"
  labeled="$(gh issue list --state open --label "child-of:${parent}" --limit 100 --json number --jq 'length' 2>/dev/null || echo 0)"
  titled="$(gh issue list --state open --limit 100 --json title --jq '.[].title' 2>/dev/null | grep -c "^${parent}\." || true)"
  used=$((labeled + titled))
  require_credit "children of #${parent}" "$used" "$limit"
}

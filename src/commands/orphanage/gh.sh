#!/usr/bin/env bash
# cli gh — GitHub passthrough + recipes + issue CRUD + Projects v2 (orphanage image).
# Deterministic git/gh operations; AI text via the opencode CLI when requested.
# Limits act as pre-flight rate limiters (lib/gh_limits.sh) before any write.
set -euo pipefail

cli_gh_help() {
  cat <<'EOF'
cli gh — GitHub CLI passthrough + recipes + issue CRUD + Projects v2.

Usage: cli gh <command> [args...]

Recipes:
  gh issue pick                      pick the next open issue
  gh issue plan --issue N [--rounds N]  opencode plan loop (default 3 rounds)
  gh craft pr [--issue N]            plan(3x) -> exec(3x) -> commit -> PR -> comment

Issue CRUD (typed wrappers over gh issue create/edit/delete):
  gh issue create --title T [--body B] [--label L] [--assignee A] [--repo R]
  gh issue update <N> [--title T] [--body B] [--add-label L] [--remove-label L]
                 [--state open|closed] [--repo R]
  gh issue delete <N> [--repo R]
  gh issue comment <N> --body B [--repo R]     (credit-checked before sending)

Projects v2 (via gh api graphql):
  gh project list [--owner O]
  gh project view <N> [--owner O]
  gh project create --title T [--owner O]
  gh project update <N> --title T [--owner O]
  gh project delete <N> [--owner O]
  gh project item list <N> [--owner O]
  gh project item add <N> --issue <issueN> [--repo R] [--owner O]
  gh project item remove <N> <itemId> [--owner O]

Passthrough: any other `gh <args...>` runs directly.

Env: GITHUB_TOKEN/GH_TOKEN or `gh auth login`. AI needs DEEPSEEK_API_KEY.
AI quantities (defaults, capped): CLI_GH_PLAN_ROUNDS=3 (max 5),
CLI_GH_EXEC_RUNS=3 (max 5).
Limits: CLI_GH_MAX_PR=3, CLI_GH_MAX_COMMITS_PR=10, CLI_GH_MAX_COMMENTS_PR=5,
CLI_GH_MAX_COMMENTS_ISSUE=32, CLI_GH_MAX_PARENTS=8, CLI_GH_MAX_CHILDREN=16.
EOF
}

gh_require() {
  require_tool gh
  if ! gh auth status >/dev/null 2>&1; then
    cli_die "gh is not authenticated: run 'gh auth login' or set GH_TOKEN"
  fi
}

# gh_cmd <subcmd...> — run `gh [--repo R] <subcmd...>`.
gh_cmd() {
  local -a cmd=(gh)
  if [[ -n "${REPO:-}" ]]; then
    cmd+=(--repo "$REPO")
  fi
  cmd+=("$@")
  "${cmd[@]}"
}

# gh_pick_arg <name> <args...> — pop "-name VALUE" pairs, store into global OUT.
gh_pick_arg() {
  local name="$1"
  shift
  OUT=""
  local out_args=()
  while (($# > 0)); do
    if [[ "$1" == "$name" ]]; then
      OUT="${2:-}"
      shift 2
    else
      out_args+=("$1")
      shift
    fi
  done
  # shellcheck disable=SC2034
  REST=("${out_args[@]}")
}

# gh_owner [owner] — default owner from the current repo.
gh_owner() {
  local owner="${1:-}"
  if [[ -z "$owner" ]]; then
    owner="$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")"
  fi
  [[ -n "$owner" ]] || cli_die "could not resolve owner (use --owner O)"
  printf '%s' "$owner"
}

# =============================================================================
# AI recipes
# =============================================================================

gh_issue_pick() {
  gh_require
  local rows
  rows="$(gh issue list --state open --limit 30 --json number,title,labels)"
  if [[ -z "$rows" || "$rows" == "[]" ]]; then
    cli_ok "no open issues to pick"
    return 0
  fi
  local number title
  number="$(printf '%s\n' "$rows" | gh api --jq '.[0].number' 2>/dev/null || echo "")"
  title="$(printf '%s\n' "$rows" | gh api --jq '.[0].title' 2>/dev/null || echo "")"
  [[ -n "$number" ]] || cli_die "could not parse issue list (gh api --jq unavailable?)"
  printf 'issue %s: %s\n' "$number" "$title"
}

# gh_plan_loop <issue> — run CLI_GH_PLAN_ROUNDS (default 3) refining rounds and
# print the final single-execution plan.
gh_plan_loop() {
  local issue="$1" rounds
  rounds="$(env_capped CLI_GH_PLAN_ROUNDS 3 5)"
  command -v opencode >/dev/null 2>&1 || cli_die "opencode is required for gh plan"
  local body round
  body="$(gh issue view "$issue" --json title,body --jq '.title + "\n\n" + .body')"
  for ((round = 1; round <= rounds; round++)); do
    printf 'plan round %s/%s\n' "$round" "$rounds" >&2
    body="$(opencode run "Plan this GitHub issue. Produce ONE complete, executable implementation plan that contains EVERY instruction needed to implement the change in a single run — do not defer any step to a second run. Do not include running linters, tests, or formatting checks. Refine the previous plan and output only the final full plan.\n\nIssue:\n${body}" 2>/dev/null)"
  done
  printf '%s\n' "$body"
}

# gh_exec_loop <plan-file> — run CLI_GH_EXEC_RUNS (default 3) implementation
# passes over the plan; no lint/test.
gh_exec_loop() {
  local plan_file="$1" runs plan
  runs="$(env_capped CLI_GH_EXEC_RUNS 3 5)"
  plan="$(cat "$plan_file" 2>/dev/null || echo "")"
  [[ -n "$plan" ]] || cli_die "no plan to execute (${plan_file} missing)"
  command -v opencode >/dev/null 2>&1 || cli_die "opencode is required for gh build"
  local run
  for ((run = 1; run <= runs; run++)); do
    printf 'exec pass %s/%s\n' "$run" "$runs" >&2
    opencode run "Implement the following plan COMPLETELY in the working tree in a single run. Do NOT run linters, tests, or formatting checks. When done, run \`git add -A\` and show \`git status --short\`.\n\nPlan:\n${plan}" 2>/dev/null \
      || cli_die "opencode exec pass ${run} failed"
  done
}

gh_issue_plan() {
  gh_require
  local issue="" rounds
  while (($# > 0)); do
    case "$1" in
      --issue) issue="$2"; shift 2 ;;
      --rounds) rounds="$2"; shift 2 ;;
      *) cli_die "unknown gh plan arg: $1" ;;
    esac
  done
  [[ -n "$issue" ]] || cli_die "gh issue plan requires --issue N"
  local body
  body="$(gh_plan_loop "$issue")"
  printf '%s\n' "$body"
  cli_ok "gh plan ${issue} done"
}

gh_craft_pr() {
  gh_require
  local issue="" repo=""
  while (($# > 0)); do
    case "$1" in
      --issue) issue="$2"; shift 2 ;;
      --repo) repo="$2"; shift 2 ;;
      *) cli_die "unknown gh craft pr arg: $1" ;;
    esac
  done
  REPO="$repo"
  if [[ -z "$issue" ]]; then
    issue="$(gh_issue_pick | sed 's/issue \([0-9]*\).*/\1/')"
  fi
  git rev-parse --show-toplevel >/dev/null 2>&1 || cli_die "not a git repository"
  [[ -z "$(git status --porcelain)" ]] || cli_die "working tree is not clean"

  # Limits pre-flight (read-only counts) before any AI or write work.
  gh_credit_open_prs
  gh_credit_issue_comments "$issue"

  local plan_file="issue-${issue}-plan.md"
  gh_plan_loop "$issue" > "$plan_file"

  local branch="issue-${issue}"
  git checkout -b "$branch" >/dev/null 2>&1 || true

  gh_exec_loop "$plan_file"

  gh_credit_commits
  git add -A
  git diff --cached --quiet && cli_die "no changes produced — aborting"
  git commit -m "feat: address issue #${issue}" >/dev/null 2>&1 || true

  gh_credit_open_prs
  git push -u origin "$branch" >/dev/null 2>&1 || cli_die "push failed"
  gh pr create --fill --base main --head "$branch" 2>/dev/null || true

  gh_credit_issue_comments "$issue"
  gh issue comment "$issue" --body "PR created for this issue: #$(gh pr view "$branch" --json number --jq .number 2>/dev/null || echo '?')" >/dev/null 2>&1 || true
  cli_ok "gh craft pr ${issue}"
}

# =============================================================================
# Issue CRUD (typed wrappers over gh issue create/edit/delete)
# =============================================================================

gh_issue_create() {
  gh_require
  gh_pick_arg --title "$@"
  local title="$OUT"
  local -a rest=("${REST[@]}")
  gh_pick_arg --body "${rest[@]}"
  local body="$OUT"
  rest=("${REST[@]}")
  gh_pick_arg --label "${rest[@]}"
  local label="$OUT"
  rest=("${REST[@]}")
  gh_pick_arg --assignee "${rest[@]}"
  local assignee="$OUT"
  rest=("${REST[@]}")
  gh_pick_arg --repo "${rest[@]}"
  local repo="$OUT"
  REPO="$repo"

  [[ -n "$title" ]] || cli_die "issue create requires --title T"

  # Parent/child credit when the issue is structured as an epic or a child.
  if [[ "$title" =~ ^[0-9]+[.-][0-9]+[[:space:]-] ]]; then
    local parent
    parent="${title%%.*}"
    gh_credit_children "$parent"
  elif [[ "$title" =~ ^[0-9]+[[:space:]]- ]]; then
    gh_credit_parents
  fi

  local -a args=()
  args+=(issue create --title "$title")
  [[ -n "$body" ]] && args+=(--body "$body")
  [[ -n "$label" ]] && args+=(--label "$label")
  [[ -n "$assignee" ]] && args+=(--assignee "$assignee")
  gh_cmd "${args[@]}"
}

gh_issue_update() {
  gh_require
  local number="${1:?issue number required}"
  shift
  local -a args=(issue edit "$number")
  local repo=""
  while (($# > 0)); do
    case "$1" in
      --title) args+=(--title "$2"); shift 2 ;;
      --body) args+=(--body "$2"); shift 2 ;;
      --add-label) args+=(--add-label "$2"); shift 2 ;;
      --remove-label) args+=(--remove-label "$2"); shift 2 ;;
      --state) args+=(--state "$2"); shift 2 ;;
      --repo) repo="$2"; shift 2 ;;
      *) cli_die "unknown gh issue update arg: $1" ;;
    esac
  done
  REPO="$repo"
  gh issue view "$number" --json number >/dev/null 2>&1 || cli_die "issue #${number} not found"
  gh_cmd "${args[@]}"
}

gh_issue_delete() {
  gh_require
  local number="${1:?issue number required}"
  local repo=""
  shift || true
  while (($# > 0)); do
    case "$1" in
      --repo) repo="$2"; shift 2 ;;
      *) cli_die "unknown gh issue delete arg: $1" ;;
    esac
  done
  REPO="$repo"
  gh issue view "$number" --json number >/dev/null 2>&1 || cli_die "issue #${number} not found"
  gh_cmd issue delete "$number" --yes
}

gh_issue_comment() {
  gh_require
  local number="${1:?issue number required}"
  shift
  local body="" repo=""
  while (($# > 0)); do
    case "$1" in
      --body) body="$2"; shift 2 ;;
      --repo) repo="$2"; shift 2 ;;
      *) cli_die "unknown gh issue comment arg: $1" ;;
    esac
  done
  [[ -n "$body" ]] || cli_die "issue comment requires --body B"
  REPO="$repo"
  gh_credit_issue_comments "$number"
  gh_cmd issue comment "$number" --body "$body"
}

# =============================================================================
# Projects v2 (via gh api graphql)
# =============================================================================

# gh_project_graphql <query> [vars...] — run gh api graphql with -f/-F vars.
gh_project_graphql() {
  local query="$1"
  shift
  local -a args=(api graphql -f "query=${query}")
  while (($# > 0)); do
    case "$1" in
      -f) args+=(-f "$2"); shift 2 ;;
      -F) args+=(-F "$2"); shift 2 ;;
      *) cli_die "bad graphql var: $1" ;;
    esac
  done
  gh "${args[@]}"
}

# gh_project_resolve_id <owner> <number> — Projects v2 node id by number.
gh_project_resolve_id() {
  local owner="$1" number="$2" id
  id="$(gh api graphql -f query="query(\$login: String!){ organization(login: \$login){ projectsV2(first: 100){ nodes { number id } } } user(login: \$login){ projectsV2(first: 100){ nodes { number id } } } }" -F login="$owner" \
    --jq "[.data.organization.projectsV2.nodes // [] | .[] | select(.number == ${number}) | .id] + [.data.user.projectsV2.nodes // [] | .[] | select(.number == ${number}) | .id] | .[0]")"
  [[ -n "$id" && "$id" != "null" ]] || cli_die "project #${number} not found for owner ${owner}"
  printf '%s' "$id"
}

gh_project_list() {
  gh_require
  local owner=""
  while (($# > 0)); do
    case "$1" in
      --owner) owner="$2"; shift 2 ;;
      *) cli_die "unknown gh project list arg: $1" ;;
    esac
  done
  owner="$(gh_owner "$owner")"
  gh api graphql -f query="query(\$login: String!){ organization(login: \$login){ projectsV2(first: 20){ nodes { id number title url } } } user(login: \$login){ projectsV2(first: 20){ nodes { id number title url } } } }" \
    -F login="$owner" \
    --jq '(.data.organization.projectsV2.nodes // []) + (.data.user.projectsV2.nodes // []) | .[] | "\(.number)\t\(.title)\t\(.id)"'
}

gh_project_view() {
  gh_require
  local number="${1:?project number required}" owner=""
  shift || true
  while (($# > 0)); do
    case "$1" in
      --owner) owner="$2"; shift 2 ;;
      *) cli_die "unknown gh project view arg: $1" ;;
    esac
  done
  owner="$(gh_owner "$owner")"
  local pid
  pid="$(gh_project_resolve_id "$owner" "$number")"
  gh api graphql -f query="query(\$id: ID!){ node(id: \$id){ ... on ProjectV2 { number title url items(first: 100){ nodes { id content { ... on Issue { number title } } } } } } }" \
    -F id="$pid" \
    --jq '.data.node | { number, title, url, items: [.items.nodes[] | { itemId: .id, issue: (.content.number // null), title: (.content.title // null) }] }'
}

gh_project_create() {
  gh_require
  local title="" owner=""
  while (($# > 0)); do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --owner) owner="$2"; shift 2 ;;
      *) cli_die "unknown gh project create arg: $1" ;;
    esac
  done
  [[ -n "$title" ]] || cli_die "project create requires --title T"
  owner="$(gh_owner "$owner")"
  local owner_id
  owner_id="$(gh api graphql -f query="query(\$login: String!){ organization(login: \$login){ id } user(login: \$login){ id } }" -F login="$owner" \
    --jq '.data.organization.id // .data.user.id')"
  [[ -n "$owner_id" && "$owner_id" != "null" ]] || cli_die "owner not found: ${owner}"
  gh api graphql -f query="mutation(\$oid: ID!, \$title: String!){ createProjectV2(input:{ ownerId: \$oid, title: \$title }){ projectV2{ id number title } } }" \
    -F oid="$owner_id" -f title="$title" \
    --jq '.data.createProjectV2.projectV2 | "\(.number)\t\(.title)\t\(.id)"'
}

gh_project_update() {
  gh_require
  local number="${1:?project number required}" title="" owner=""
  shift || true
  while (($# > 0)); do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --owner) owner="$2"; shift 2 ;;
      *) cli_die "unknown gh project update arg: $1" ;;
    esac
  done
  [[ -n "$title" ]] || cli_die "project update requires --title T"
  owner="$(gh_owner "$owner")"
  local pid
  pid="$(gh_project_resolve_id "$owner" "$number")"
  gh api graphql -f query="mutation(\$id: ID!, \$title: String!){ updateProjectV2(input:{ projectV2Id: \$id, title: \$title }){ projectV2{ id title } } }" \
    -F id="$pid" -f title="$title" \
    --jq '.data.updateProjectV2.projectV2 | "\(.id)\t\(.title)"'
}

gh_project_delete() {
  gh_require
  local number="${1:?project number required}" owner=""
  shift || true
  while (($# > 0)); do
    case "$1" in
      --owner) owner="$2"; shift 2 ;;
      *) cli_die "unknown gh project delete arg: $1" ;;
    esac
  done
  owner="$(gh_owner "$owner")"
  local pid
  pid="$(gh_project_resolve_id "$owner" "$number")"
  gh api graphql -f query="mutation(\$id: ID!){ deleteProjectV2(input:{ projectV2Id: \$id }){ deletedProjectV2Number } }" \
    -F id="$pid" --jq '.data.deleteProjectV2.deletedProjectV2Number'
}

gh_project_item_list() {
  gh_project_view "$@"
}

gh_project_item_add() {
  gh_require
  local number="${1:?project number required}" issue="" owner="" repo=""
  shift || true
  while (($# > 0)); do
    case "$1" in
      --issue) issue="$2"; shift 2 ;;
      --owner) owner="$2"; shift 2 ;;
      --repo) repo="$2"; shift 2 ;;
      *) cli_die "unknown gh project item add arg: $1" ;;
    esac
  done
  [[ -n "$issue" ]] || cli_die "project item add requires --issue N"
  owner="$(gh_owner "$owner")"
  REPO="$repo"
  local pid content_id
  pid="$(gh_project_resolve_id "$owner" "$number")"
  content_id="$(gh api graphql -f query="query(\$o: String!, \$r: String!, \$n: Int!){ repository(owner: \$o, name: \$r){ issue(number: \$n){ id } } }" -F o="$owner" -F r="${REPO:-$(gh repo view --json name --jq .name 2>/dev/null)}" -F n="$issue" \
    --jq '.data.repository.issue.id')"
  [[ -n "$content_id" && "$content_id" != "null" ]] || cli_die "issue #${issue} not found"
  gh api graphql -f query="mutation(\$p: ID!, \$c: ID!){ addProjectV2ItemById(input:{ projectId: \$p, contentId: \$c }){ item{ id } } }" \
    -F p="$pid" -F c="$content_id" --jq '.data.addProjectV2ItemById.item.id'
}

gh_project_item_remove() {
  gh_require
  local number="${1:?project number required}" item_id="${2:?itemId required}" owner=""
  shift 2 || true
  while (($# > 0)); do
    case "$1" in
      --owner) owner="$2"; shift 2 ;;
      *) cli_die "unknown gh project item remove arg: $1" ;;
    esac
  done
  owner="$(gh_owner "$owner")"
  local pid
  pid="$(gh_project_resolve_id "$owner" "$number")"
  gh api graphql -f query="mutation(\$p: ID!, \$i: ID!){ deleteProjectV2Item(input:{ projectId: \$p, itemId: \$i }){ deletedItemId } }" \
    -F p="$pid" -F i="$item_id" --jq '.data.deleteProjectV2Item.deletedItemId'
}

# =============================================================================
# Dispatch
# =============================================================================

cli_gh_main() {
  if (($# == 0)); then
    cli_gh_help
    return 0
  fi
  case "$1" in
    -h|--help) cli_gh_help; return 0 ;;
    policy)
      case "${2:-}" in
        list) printf 'pr-merge\n' ;;
        *) gh "$@" ;;
      esac
      ;;
    issue)
      case "${2:-}" in
        pick) shift 2; gh_issue_pick "$@" ;;
        plan) shift 2; gh_issue_plan "$@" ;;
        create) shift 2; gh_issue_create "$@" ;;
        update) shift 2; gh_issue_update "$@" ;;
        delete) shift 2; gh_issue_delete "$@" ;;
        comment) shift 2; gh_issue_comment "$@" ;;
        close) gh_require; gh issue close "${3:?issue number required}" ;;
        *) gh "$@" ;;
      esac
      ;;
    craft) shift; gh_craft_pr "$@" ;;
    release) shift; gh_release "$@" ;;
    project)
      case "${2:-}" in
        list) shift 2; gh_project_list "$@" ;;
        view) shift 2; gh_project_view "$@" ;;
        create) shift 2; gh_project_create "$@" ;;
        update) shift 2; gh_project_update "$@" ;;
        delete) shift 2; gh_project_delete "$@" ;;
        item)
          case "${3:-}" in
            list) shift 3; gh_project_item_list "$@" ;;
            add) shift 3; gh_project_item_add "$@" ;;
            remove) shift 3; gh_project_item_remove "$@" ;;
            *) cli_die "unknown gh project item subcommand: ${3:-}" ;;
          esac
          ;;
        *) cli_die "unknown gh project subcommand: ${2:-}" ;;
      esac
      ;;
    *) gh "$@" ;;
  esac
}

gh_release() {
  gh_require
  local tag="${1:?tag required}" version="${2:?version required}"
  local image
  image="$(env_or RUNTIME_IMAGE skibiribab/cli)"
  gh release create "$tag" \
    --title "skibiribab-cli ${version}" \
    --notes "Docker images: ${image}:${version} (+ -orphanage/-ai/-node/-python/-rust/-cpp/-go/-java/-media)"
  cli_ok "created GitHub release ${tag}"
}

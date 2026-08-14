#!/usr/bin/env bash
# Regenerate the per-repo status table in the profile README and open/update a PR.
# usage: env GH_TOKEN=... [STATUS_OWNER=...] [STATUS_TARGET_REPO=...] \
#          bash src/scripts/status/update-status.sh
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

if [[ -z "${GH_TOKEN:-}" ]]; then
  if command -v gh >/dev/null 2>&1; then
    if GH_TOKEN="$(gh auth token 2>/dev/null)"; then
      [[ -n "$GH_TOKEN" ]] && export GH_TOKEN
    fi
  fi
fi
: "${GH_TOKEN:?GH_TOKEN required — set GH_TOKEN or run in an authenticated gh environment}"
OWNER="${STATUS_OWNER:-skibiribab}"
TARGET_REPO="${STATUS_TARGET_REPO:-${OWNER}/skibiribab}"
PR_BRANCH="${STATUS_PR_BRANCH:-chore/repo-status}"
PR_TITLE="${STATUS_PR_TITLE:-chore: refresh repo status}"

# Ordered by theme number (0-5); the profile repo itself is intentionally absent.
REPOS=(
  "0|private"
  "1|control-plane"
  "2|interview"
  "3|browser-extensions"
  "4|radar-alerts"
  "5|browser-games"
)

# repo_ci <repo> — "pass" if HEAD has >=1 successful check-run and no failed
# ones; "fail" otherwise (including no runs at all).
repo_ci() {
  local repo="$1" sha conclusions successes bad
  sha="$(gh api "repos/${OWNER}/${repo}/commits" --jq '.[0].sha')"
  conclusions="$(gh api "repos/${OWNER}/${repo}/commits/${sha}/check-runs" --jq '[.check_runs[].conclusion]')"
  successes="$(printf '%s' "$conclusions" | jq '[.[] | select(. == "success")] | length')"
  bad="$(printf '%s' "$conclusions" \
    | jq '[.[] | select(. == "failure" or . == "cancelled" or . == "timed_out" or . == "action_required")] | length')"
  if (( successes > 0 )) && (( bad == 0 )); then
    echo "pass"
  else
    echo "fail"
  fi
}

# repo_field <repo> — print the status row for one repo.
repo_row() {
  local repo="$1" latest tags commits date ci
  latest="$(gh api "repos/${OWNER}/${repo}/tags" --jq '.[0].name // ""')"
  [[ -n "$latest" ]] && latest="\`${latest}\`" || latest="—"
  tags="$(gh api --paginate "repos/${OWNER}/${repo}/tags" --jq 'length' | awk '{s+=$1} END {print s}')"
  commits="$(gh api --paginate "repos/${OWNER}/${repo}/commits" --jq 'length' | awk '{s+=$1} END {print s}')"
  date="$(gh api "repos/${OWNER}/${repo}/commits" --jq '.[0].commit.committer.date[0:10]')"
  ci="$(repo_ci "$repo")"
  echo "| ${num} | ${repo} | ${latest} | ${tags} | ${commits} | ${date} | ${ci} |"
}

build_table() {
  echo "| # | Repo | Latest tag | Tags | Commits | Last commit | CI |"
  echo "|---|---|---|---|---|---|---|"
  local entry num repo
  for entry in "${REPOS[@]}"; do
    num="${entry%%|*}"
    repo="${entry##*|}"
    repo_row "$repo"
  done
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "cloning ${TARGET_REPO}..."
git clone --quiet --depth 1 "https://github.com/${TARGET_REPO}.git" "${tmp}/repo"
cd "${tmp}/repo"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout --quiet -B "${PR_BRANCH}" origin/main

begin_line="$(grep -n 'BEGIN status-table' README.md | head -n1 | cut -d: -f1)"
end_line="$(grep -n 'END status-table' README.md | head -n1 | cut -d: -f1)"
if [[ -z "$begin_line" || -z "$end_line" || "$begin_line" -ge "$end_line" ]]; then
  echo "status-table markers not found in README.md (expected BEGIN/END status-table)" >&2
  exit 1
fi

{
  sed -n "1,${begin_line}p" README.md
  build_table
  sed -n "${end_line},\$p" README.md
} > README.md.new
mv README.md.new README.md

if git diff --quiet -- README.md; then
  echo "repo status unchanged — no PR"
  exit 0
fi

git add README.md
git commit --quiet -m "${PR_TITLE}"
git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${TARGET_REPO}.git"
git push --force --quiet origin "${PR_BRANCH}"

pr_number="$(gh pr list -R "${TARGET_REPO}" --base main --head "${PR_BRANCH}" --json number --jq '.[0].number // ""')"
if [[ -n "$pr_number" ]]; then
  echo "updated PR ${TARGET_REPO}#${pr_number}"
else
  gh pr create -R "${TARGET_REPO}" --base main --head "${PR_BRANCH}" \
    --title "${PR_TITLE}" --body "Automated refresh of the repo-status table." >/dev/null
  echo "created PR in ${TARGET_REPO} (${PR_BRANCH})"
fi

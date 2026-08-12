#!/usr/bin/env bats
# Dispatch tests for `cli gh` issue CRUD + Projects v2 with a recording mock gh.
# The mock records every invocation and answers the read-only queries that the
# credit limiters and resolvers depend on.

CLI="${BATS_TEST_DIRNAME}/../cli"

setup() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export GH_LOG
  : > "$GH_LOG"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'MOCK'
#!/usr/bin/env bash
LOG="${GH_LOG:?}"
printf '%s\n' "$*" >> "$LOG"
jq=""
prev=""
for a in "$@"; do
  if [[ "$prev" == "--jq" ]]; then jq="$a"; fi
  prev="$a"
done

if [[ " $* " == *" auth status "* ]]; then exit 0; fi
if [[ " $* " == *" repo view "* ]]; then
  case "$jq" in
    *owner.login*) echo "testowner" ;;
    *) echo "testrepo" ;;
  esac
  exit 0
fi
if [[ " $* " == *" pr list "* ]]; then echo "${GH_OPEN_PRS:-0}"; exit 0; fi
if [[ " $* " == *" issue list "* ]]; then
  if [[ " $* " == *" --json title "* ]]; then
    echo "${GH_TITLED:-0}"
  else
    echo "${GH_ISSUE_COUNT:-0}"
  fi
  exit 0
fi
if [[ " $* " == *" issue view "* ]]; then
  case "$jq" in
    *comments*) echo "${GH_ISSUE_COMMENTS:-0}" ;;
    *) echo "{}" ;;
  esac
  exit 0
fi
if [[ " $* " == *" api graphql "* ]]; then
  case "$jq" in
    *select\(.number*) echo "PVT_proj" ;;
    *organization.id*) echo "O_test" ;;
    *createProjectV2*) printf '1\tMy Project\tPVT_new\n' ;;
    *updateProjectV2*) printf 'PVT_up\tNew Title\n' ;;
    *deleteProjectV2*) echo "1" ;;
    *addProjectV2ItemById*) echo "PVT_item" ;;
    *deleteProjectV2Item*) echo "PVT_item" ;;
    *.data.node*) echo '{"number":1,"title":"Proj","url":"https://x","items":[]}' ;;
    *repository*) echo "I_issue" ;;
    *) echo "UNKNOWN_JQ" ;;
  esac
  exit 0
fi
exit 0
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "gh issue create requires --title" {
  run "$CLI" gh issue create
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires --title"* ]]
}

@test "gh issue create builds gh issue create" {
  run "$CLI" gh issue create --title "My issue" --body "desc" --label bug
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_LOG")" == *"issue create --title My issue --body desc --label bug"* ]]
}

@test "gh issue create is credit-guarded for child titles" {
  export GH_ISSUE_COUNT=16 CLI_GH_MAX_CHILDREN=16
  run "$CLI" gh issue create --title "123.4 - child task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"limit reached"* ]]
}

@test "gh issue update builds gh issue edit" {
  run "$CLI" gh issue update 5 --state closed --add-label reviewed
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_LOG")" == *"issue view 5 --json number"* ]]
  [[ "$(cat "$GH_LOG")" == *"issue edit 5 --state closed --add-label reviewed"* ]]
}

@test "gh issue delete builds gh issue delete --yes" {
  run "$CLI" gh issue delete 5
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_LOG")" == *"issue delete 5 --yes"* ]]
}

@test "gh issue comment is credit-checked before sending" {
  export GH_ISSUE_COMMENTS=32 CLI_GH_MAX_COMMENTS_ISSUE=32
  run "$CLI" gh issue comment 5 --body "ship it"
  [ "$status" -eq 1 ]
  [[ "$output" == *"limit reached"* ]]
  [[ "$(cat "$GH_LOG")" != *"issue comment"* ]]
}

@test "gh issue comment sends when under the limit" {
  export GH_ISSUE_COMMENTS=0
  run "$CLI" gh issue comment 5 --body "ship it"
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_LOG")" == *"issue comment 5 --body ship it"* ]]
}

@test "gh project create runs the createProjectV2 mutation" {
  run "$CLI" gh project create --title "Roadmap"
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_LOG")" == *"repo view --json owner"* ]]
  [[ "$(cat "$GH_LOG")" == *"createProjectV2"* ]]
  [[ "$output" == *"1	My Project	PVT_new"* ]]
}

@test "gh project item add runs addProjectV2ItemById" {
  run "$CLI" gh project item add 1 --issue 5
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_LOG")" == *"-F n=5"* ]]
  [[ "$(cat "$GH_LOG")" == *"addProjectV2ItemById"* ]]
}

@test "gh project item remove runs deleteProjectV2Item" {
  run "$CLI" gh project item remove 1 PVT_item
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_LOG")" == *"deleteProjectV2Item"* ]]
}

@test "gh project rejects unknown subcommands" {
  run "$CLI" gh project bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown gh project subcommand"* ]]
  run "$CLI" gh project item bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown gh project item subcommand"* ]]
}

#!/usr/bin/env bats
# Tests for the cli dispatcher + thin command wrappers that run in any image.

CLI="${BATS_TEST_DIRNAME}/../cli"
ROOT="${BATS_TEST_DIRNAME}/.."

@test "cli --version prints VERSION file" {
  run "$CLI" --version
  [ "$status" -eq 0 ]
  [ "$output" = "$(tr -d '[:space:]' < "$ROOT/VERSION")" ]
}

@test "cli --help lists commands" {
  run "$CLI" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"sh lint"* ]]
  [[ "$output" == *"gh"* ]]
}

@test "cli unknown command errors" {
  run "$CLI" no-such-group
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown command"* ]]
}

@test "cli integration list maps images" {
  run "$CLI" integration list
  [ "$status" -eq 0 ]
  [[ "$output" == *"node"* ]]
  [[ "$output" == *"python"* ]]
}

@test "cli ignore lint passes on this repo" {
  run "$CLI" ignore lint "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "cli gh policy list is deterministic" {
  run "$CLI" gh policy list
  [ "$status" -eq 0 ]
  [[ "$output" == *"pr-merge"* ]]
}

@test "cli git passthrough runs git" {
  run "$CLI" git --version
  [ "$status" -eq 0 ]
  [[ "$output" == "git version "* ]]
}

@test "cli git honors CLI_GIT_ROOT for composite commands" {
  git init -q -b main "$BATS_TEST_TMPDIR/repo"
  git -C "$BATS_TEST_TMPDIR/repo" config user.email "t@t"
  git -C "$BATS_TEST_TMPDIR/repo" config user.name "T"
  touch "$BATS_TEST_TMPDIR/repo/f"
  git -C "$BATS_TEST_TMPDIR/repo" add -A
  git -C "$BATS_TEST_TMPDIR/repo" commit -q -m init
  export CLI_GIT_ROOT="$BATS_TEST_TMPDIR/repo"
  run "$CLI" git branch current
  [ "$status" -eq 0 ]
  [ "$output" = "main" ]
}

@test "missing tool recommends the owning image" {
  # markdownlint only exists in the node image; base must recommend it.
  if command -v markdownlint >/dev/null 2>&1; then
    skip "markdownlint present"
  fi
  run "$CLI" md lint .
  [ "$status" -eq 1 ]
  [[ "$output" == *"node image"* ]]
  [[ "$output" == *"binarylifter/gardusig-cli:"* ]]
}

@test "missing docker daemon recommends the socket" {
  if ! command -v docker >/dev/null 2>&1; then
    skip "docker not present in this image"
  fi
  run "$CLI" dockerfile lint .
  [ "$status" -eq 1 ]
  [[ "$output" == *"docker socket"* ]]
}

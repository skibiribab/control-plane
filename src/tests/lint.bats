#!/usr/bin/env bats
# Tests for file-type lint commands (cli <noun> lint) that run with orphanage
# tools (bash, shellcheck).

CLI="${BATS_TEST_DIRNAME}/../cli"
ROOT="${BATS_TEST_DIRNAME}/.."

setup() {
  TMP="$(mktemp -d)"
}
teardown() {
  rm -rf "$TMP"
}

@test "sh lint passes on a clean script" {
  printf '#!/bin/sh\necho hi\n' > "$TMP/ok.sh"
  run "$CLI" sh lint "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "sh lint reports a missing file" {
  run "$CLI" sh lint "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}

@test "sh lint fails on a syntax error" {
  printf 'if then fi\n' > "$TMP/bad.sh"
  run "$CLI" sh lint "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed"* ]]
}

@test "sh lint honors --json" {
  printf '#!/bin/sh\necho hi\n' > "$TMP/ok.sh"
  run "$CLI" sh lint "$TMP" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"command":"sh lint"'* ]]
  [[ "$output" == *'"ok":true'* ]]
}

@test "structure lint skips without a tree manifest" {
  run "$CLI" structure lint "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}

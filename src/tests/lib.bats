#!/usr/bin/env bats
# Tests for lib/ helpers (json, env, tools) directly.

ROOT="${BATS_TEST_DIRNAME}/.."

setup() {
  export CLI_ROOT="$ROOT"
  # shellcheck source=lib/json.sh
  source "$ROOT/lib/json.sh"
  # shellcheck source=lib/env.sh
  source "$ROOT/lib/env.sh"
  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
}

@test "json_object builds a flat JSON object" {
  out="$(json_object "a" "1" "b" '"x"')"
  [[ "$out" == '{"a":1,"b":"x"}' ]]
}

@test "json_str escapes quotes and backslashes" {
  out="$(json_str 'a"b\c')"
  [[ "$out" == '"a\"b\\c"' ]]
}

@test "json_field extracts a string value" {
  out="$(json_field '{"title": "hello", "ok": true}' title)"
  [ "$out" = "hello" ]
}

@test "json_field extracts a scalar value" {
  out="$(json_field '{"count": 7, "ok": false}' count)"
  [ "$out" = "7" ]
}

@test "env_or uses the default when unset" {
  unset CLI_SOME_VAR
  [ "$(env_or CLI_SOME_VAR fallback)" = "fallback" ]
}

@test "env_or honors an explicit value" {
  CLI_SOME_VAR="real"
  [ "$(env_or CLI_SOME_VAR fallback)" = "real" ]
}

#!/usr/bin/env bash
# Reporting helpers for file-type/language commands. Emit either plain text or a
# flat JSON summary ({"command":...,"ok":...,"files_checked":...,"failures":[]}).
# The label is the full verb-noun phrase, e.g. "sh lint", "md lint", "test rust".
set -euo pipefail

# report_json <label> <ok:0|1> <files_checked> <failures or empty>
# failures are newline-separated "rel<TAB>message" lines -> [{"file":..,"message":..}]
report_json() {
  local label="$1" ok="$2" checked="$3" failures="${4:-}"
  local ok_str="false"
  [[ "$ok" == "0" ]] && ok_str="true"
  local failures_json="[]"
  if [[ -n "$failures" ]]; then
    failures_json="["
    local first=1 line rel msg
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      rel="${line%%$'\t'*}"
      msg="${line#*$'\t'}"
      if ((first)); then first=0; else failures_json+=","; fi
      failures_json+="$(json_object "file" "$(json_str "$rel")" "message" "$(json_str "$msg")")"
    done <<< "$failures"
    failures_json+="]"
  fi
  json_object \
    "command" "$(json_str "$label")" \
    "ok" "$ok_str" \
    "files_checked" "$checked" \
    "failures" "$failures_json"
}

# json_output — 1 when JSON output requested.
json_output() {
  [[ "${CLI_JSON:-0}" == "1" ]]
}

report_ok() {
  local label="$1" count="$2"
  local plural=""
  [[ "$count" != "1" ]] && plural="s"
  if json_output; then
    report_json "$label" 0 "$count" ""
  else
    printf '%s ok (%s file%s)\n' "$label" "$count" "$plural"
  fi
  return 0
}

report_skipped() {
  local label="$1"
  if json_output; then
    report_json "$label" 0 0 ""
  else
    printf '%s skipped: no files\n' "$label"
  fi
  return 0
}

report_fail() {
  local label="$1" message="$2"
  if json_output; then
    report_json "$label" 1 0 "$(printf '%s\t%s' '' "$message")"
  else
    printf '%s failed: %s\n' "$label" "$message" >&2
  fi
  return 1
}

report_result() {
  local label="$1" checked="$2" failures="$3"
  if [[ -n "$failures" ]]; then
    if json_output; then
      report_json "$label" 1 "$checked" "$failures"
    else
      printf '%s\n' "$failures" >&2
      printf '%s failed\n' "$label" >&2
    fi
    return 1
  fi
  report_ok "$label" "$checked"
}

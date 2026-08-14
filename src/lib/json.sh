#!/usr/bin/env bash
# JSON emit helpers (printf-based; jq lives only in the orphanage image, so the
# library does not depend on it) plus a bounded field extractor for our
# controlled contract shapes (openode/AI plan JSON, validate --json summaries).
set -euo pipefail

# json_escape <value> — escape for a JSON string.
json_escape() {
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g; s/\n/\\n/g'
}

# json_str <value> — print a JSON string literal.
json_str() {
  printf '"%s"' "$(json_escape "$1")"
}

# json_object <key> <jsonval> [<key> <jsonval> ...] — build a flat JSON object.
json_object() {
  local out="{" first=1
  while (($# >= 2)); do
    local key="$1" val="$2"
    shift 2
    if ((first)); then first=0; else out+=","; fi
    out+="$(printf '"%s":%s' "$key" "$val")"
  done
  printf '%s}\n' "$out"
}

# json_field <json> <key> — extract a string or scalar field value for a flat
# object with shape `"key": "value"` or `"key": true|false|123`. Bounded to our
# own contract shapes; not a general JSON parser.
json_field() {
  local data="$1" key="$2" match
  match="$(printf '%s\n' "$data" \
    | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    | head -n1)"
  if [[ -n "$match" ]]; then
    printf '%s\n' "$match"
    return 0
  fi
  printf '%s\n' "$data" \
    | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\(true\|false\|null\|-\?[0-9][0-9]*\).*/\1/p" \
    | head -n1
}

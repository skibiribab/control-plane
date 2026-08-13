#!/usr/bin/env bash
# Tool -> owning image variant registry, plus require_tool which fails with a
# recommendation to use the image that provides the missing tool.
set -euo pipefail

# Runtime image variant, baked in as ENV CLI_RUNTIME by each Dockerfile.
CLI_RUNTIME="${CLI_RUNTIME:-base}"

# tool_image <bin> — owning image variant for a tool (base unless listed).
tool_image() {
  case "$1" in
    lychee|rustc|cargo) echo "rust" ;;
    node|npm|npx|markdownlint|remark|mermaid|jq|tsc|eslint) echo "node" ;;
    python3|yamllint|pytest) echo "python" ;;
    ffmpeg|ffprobe|identify|pdfinfo) echo "media" ;;
    gcc|g++|cc|make|cmake|clang|clang-format) echo "cpp" ;;
    go|gofmt) echo "go" ;;
    java|javac|mvn|gradle) echo "java" ;;
    *) echo "base" ;;
  esac
}

# all_tools — canonical "image<TAB>tool" registry (single source of truth for
# `cli integration list/check`).
all_tools() {
  cat <<'EOF'
base	shellcheck
base	actionlint
base	docker
base	gh
base	git
base	curl
base	opencode
rust	lychee
rust	cargo
rust	rustc
node	markdownlint
node	jq
node	node
node	npm
node	tsc
node	eslint
python	yamllint
python	python3
python	pytest
media	ffmpeg
media	ffprobe
media	identify
media	pdfinfo
cpp	g++
cpp	clang-format
cpp	cmake
go	go
go	gofmt
java	java
java	mvn
java	gradle
EOF
}

# require_tool <bin> — error out (with an image recommendation) if missing.
require_tool() {
  local tool="$1" image
  image="$(tool_image "$tool")"
  if command -v "$tool" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$image" != "base" ]]; then
    cli_die "${tool} is required but not in this image (${CLI_RUNTIME}). " \
      "Use the ${image} image: skibiribab/cli:$(cli_version)-${image}"
  fi
  cli_die "${tool} is required but not in this image (${CLI_RUNTIME})."
}

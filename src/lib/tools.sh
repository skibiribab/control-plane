#!/usr/bin/env bash
# Tool -> owning image variant registry, plus require_tool which fails with a
# recommendation to use the image that provides the missing tool.
#
# Placement rule:
#   1. Standalone self-contained CLIs (no language runtime) -> orphanage.
#   2. Tools that are a dependency of a language ecosystem -> that language image.
#   3. Domain CLIs (video/image) -> media.
#   4. The AI agent engine (opencode) -> ai.
set -euo pipefail

# Runtime image variant, baked in as ENV CLI_RUNTIME by each Dockerfile.
CLI_RUNTIME="${CLI_RUNTIME:-orphanage}"

# tool_image <bin> — owning image variant for a tool (orphanage unless listed).
tool_image() {
  case "$1" in
    node|npm|npx|markdownlint|tsc|eslint) echo "node" ;;
    python3|yamllint|pytest) echo "python" ;;
    ffmpeg|ffprobe|identify) echo "media" ;;
    gcc|g++|cc|make|cmake|clang|clang-format) echo "cpp" ;;
    rustc|cargo) echo "rust" ;;
    go|gofmt) echo "go" ;;
    java|javac|mvn|gradle) echo "java" ;;
    opencode) echo "ai" ;;
    *) echo "orphanage" ;;
  esac
}

# all_tools — canonical "image<TAB>tool" registry (single source of truth for
# `cli integration list/check`).
all_tools() {
  cat <<'EOF'
orphanage	shellcheck
orphanage	actionlint
orphanage	docker
orphanage	gh
orphanage	git
orphanage	curl
orphanage	jq
orphanage	qpdf
orphanage	pdfinfo
orphanage	lychee
node	markdownlint
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
cpp	g++
cpp	clang-format
cpp	cmake
rust	cargo
rust	rustc
go	go
go	gofmt
java	java
java	mvn
java	gradle
ai	opencode
EOF
}

# require_tool <bin> — error out (with an image recommendation) if missing.
require_tool() {
  local tool="$1" image
  image="$(tool_image "$tool")"
  if command -v "$tool" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$image" != "orphanage" ]]; then
    cli_die "${tool} is required but not in this image (${CLI_RUNTIME}). " \
      "Use the ${image} image: skibiribab/cli:$(cli_version)-${image}"
  fi
  cli_die "${tool} is required but not in this image (${CLI_RUNTIME})."
}

#!/usr/bin/env bash
# Per-image verb registry — the "set of cli commands" each image provides.
# Single source of truth surfaced by `cli integration list` and consumed by
# `cli check`. Grouped by owning image; a noun may appear in more than one image
# when its tool is available there (e.g. whitespace/structure are CLI-internal).
set -euo pipefail

# all_verbs — canonical "image<TAB>noun" registry (every cli noun per image).
all_verbs() {
  cat <<'EOF'
orphanage	sh
orphanage	actions
orphanage	dockerfile
orphanage	pdf
orphanage	url
orphanage	tex
orphanage	whitespace
orphanage	structure
orphanage	ignore
orphanage	git
orphanage	gh
orphanage	docker
node	md
node	json
node	tree
node	tasks
node	javascript
node	typescript
node	repo
node	whitespace
node	structure
python	yml
python	python
python	whitespace
python	structure
rust	rust
rust	whitespace
rust	structure
cpp	cpp
cpp	whitespace
cpp	structure
go	go
go	whitespace
go	structure
java	java
java	whitespace
java	structure
media	png
media	jpg
media	jpeg
media	gif
media	webp
media	svg
media	bmp
media	mp4
media	mkv
media	mov
media	webm
media	whitespace
media	structure
ai	opencode
EOF
}

# check_verbs <image> — the generic-lint nouns `cli check` runs for an image
# (lint/syntax only; build/test/passthrough/composite verbs excluded).
check_verbs() {
  local image="$1"
  case "$image" in
    orphanage) echo "sh actions dockerfile pdf whitespace structure" ;;
    node) echo "md json javascript whitespace structure" ;;
    python) echo "yml python whitespace structure" ;;
    rust) echo "rust whitespace structure" ;;
    cpp) echo "cpp whitespace structure" ;;
    go) echo "go whitespace structure" ;;
    java) echo "java whitespace structure" ;;
    media) echo "png jpg jpeg gif webp svg bmp whitespace structure" ;;
    ai) echo "" ;;
    *) echo "" ;;
  esac
}

# verb_required_tool <verb> — the tool a verb needs (empty = CLI-internal).
verb_required_tool() {
  case "$1" in
    sh) echo "shellcheck" ;;
    actions) echo "actionlint" ;;
    dockerfile) echo "docker" ;;
    pdf) echo "qpdf" ;;
    url) echo "lychee" ;;
    tex) echo "latexmk" ;;
    md) echo "markdownlint" ;;
    json|tree|tasks|javascript|typescript) echo "node" ;;
    yml) echo "yamllint" ;;
    python) echo "python3" ;;
    rust) echo "cargo" ;;
    cpp) echo "g++" ;;
    go) echo "go" ;;
    java) echo "mvn" ;;
    png|jpg|jpeg|gif|webp|svg|bmp) echo "identify" ;;
    opencode) echo "opencode" ;;
    git) echo "git" ;;
    gh) echo "gh" ;;
    docker) echo "docker" ;;
    *) echo "" ;;
  esac
}

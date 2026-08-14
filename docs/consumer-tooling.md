# Consumer-repo tooling

Control-plane images ship the **language basics plus shared tooling** only (see
[docker.md](docker.md) for the exact per-image dependency list). Anything a
single repo needs on top — a particular linter, a build step, a niche check —
belongs **in that repo**, declared as plain `package.json` / `Makefile` scripts
and run through the image's runtime. No `.sh` files, no image changes.

This keeps images small ("a startup with the basics") while letting each repo
own exactly the tooling it needs.

## How to run repo scripts

Mount the repo into the owning image and execute the script:

```bash
# node repo
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-node npm run lint:md

# python repo
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-python make lint

# go repo
docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-go make test
```

## Templates

### Node (`package.json` scripts)

markdownlint is already shared in the node image; a repo that needs stricter or
extra checks adds them as npm scripts with local devDependencies:

```json
{
  "name": "my-repo",
  "private": true,
  "scripts": {
    "lint": "npm run lint:md && npm run lint:json",
    "lint:md": "markdownlint . --config .markdownlint.json",
    "lint:json": "node scripts/lint-json.mjs .",
    "check:links": "npx lychee '**/*.md'"
  },
  "devDependencies": {
    "markdownlint-cli": "0.49.1"
  }
}
```

Run: `docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-node npm ci && npm run lint`.

### Python (`pyproject.toml` + `Makefile`)

<!-- markdownlint-disable MD010 -->
```make
.PHONY: lint test
lint:
	python3 -m ruff check .
test:
	python3 -m pytest
```
<!-- markdownlint-enable MD010 -->

```toml
[project.optional-dependencies]
dev = ["ruff", "pytest"]
```

Run: `docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-python make lint`.

### Go (`Makefile`)

<!-- markdownlint-disable MD010 -->
```make
.PHONY: lint test
lint:
	gofmt -l . && go vet ./...
test:
	go test ./...
```
<!-- markdownlint-enable MD010 -->

Run: `docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-go make test`.

### Shell / workflows (`Makefile`)

Generic ops tooling (shellcheck, actionlint, dockerfile lint) is shared in the
orphanage image via `cli check .`. Repo-specific shell tasks go in a Makefile:

<!-- markdownlint-disable MD010 -->
```make
.PHONY: lint
lint:
	cli sh lint .
	cli actions lint .
```
<!-- markdownlint-enable MD010 -->

Run: `docker run --rm -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-orphanage make lint`.

## Rules

- **Shared = image, specific = repo.** Add to an image only what many repos
  consume; otherwise declare it in the consumer repo.
- **Scripts, not wrappers.** Repo tooling is plain `npm run` / `make` targets —
  no custom `.sh` entrypoints.
- **Pin what you add.** Repo-side tooling is pinned in the repo (`devDependencies`,
  requirements, `go.mod`) just like image deps are pinned in `versions.env`.
- When a script needs a tool from another image, run it in that image
  (`-orphanage` for shellcheck/actionlint, `-node` for npm, …).

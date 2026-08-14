# cli documentation

1. [Install](install.md) — Docker images, env config
2. [Docker images](docker.md) — image tree, tags, rules, sizes
3. [Commands](commands.md) — `cli <noun> <verb>` reference
4. [Validation reference](validation.md) — tool → written-in → owning image
5. [Git commands](git.md) — `cli git` reference
6. [GitHub](gh.md) — `cli gh` passthrough + recipes + release
7. [OpenCode](opencode.md) — `cli opencode` AI entry point
8. [Secrets](secrets.md) — env-based credential handling
9. [CI workflows](ci-workflows.md) — PR and release Docker pipelines
10. [PR pipeline spec](pull-request-spec.md) — `.github/pull-request.yaml` contract for target repos
11. [Consumer tooling](consumer-tooling.md) — repo-side scripts for specific tooling
12. [Architecture](architecture.md) — bin/lib/commands layout
13. [Development](development.md) — contributor setup and local Docker CI

**CI:** Pull requests and releases are validated in-repo via [`.github/workflows/`](../.github/workflows/). See [ci-workflows.md](ci-workflows.md).

# Secrets

The CLI uses **environment variables only** — no credential files, no `cli
configure`. Set them when running a container with `-e`, or in your shell.

| Env var | Used by |
| --- | --- |
| `GITHUB_TOKEN` / `GH_TOKEN` | `cli gh` |
| `DEEPSEEK_API_KEY` | `cli opencode`, gh AI recipes |
| `OPENCODE_CONFIG` | opencode config path (optional) |

```bash
docker run --rm -e GITHUB_TOKEN="$GITHUB_TOKEN" -e DEEPSEEK_API_KEY="$DEEPSEEK_API_KEY" \
  -v "$PWD:/repo" -w /repo skibiribab/cli:1.8.0-orphanage gh issue pick
```

For local use, export in your shell or add to `~/.profile`; inside GitHub
Actions, use secrets directly as env (`-e GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}`).

## Repository secrets (GitHub Actions)

Set on `skibiribab/control-plane`:

| Secret | Value | Used by |
| --- | --- | --- |
| `DOCKERHUB_USERNAME` | Docker Hub username (`skibiribab`) | `release.yml` — `docker/login-action` |
| `DOCKERHUB_TOKEN` | Docker Hub **access token** (`dckr_pat_…`, create in Docker Hub → Account Settings → Security) | `release.yml` — `docker/login-action` |
| `PAT_TOKEN` | Fine-grained GitHub PAT, `Contents: read/write` on this repo | `release.yml` — the `auto-tag` job pushes the version tag with it so the tag push triggers the publish workflow (`GITHUB_TOKEN` pushes do not fire workflow events) |

Set them from the CLI without echoing the value:

```bash
gh secret set DOCKERHUB_USERNAME --body "skibiribab"
printf '%s' "$DOCKER_HUB_PAT" | gh secret set DOCKERHUB_TOKEN
printf '%s' "$GITHUB_PAT"     | gh secret set PAT_TOKEN
```

**Treat the Docker Hub access token as a credential:** if it ever leaks (e.g. pasted into a chat or log), rotate it in Docker Hub and re-set `DOCKERHUB_TOKEN`.

## Token slots (predefined scheme)

Every public repo carries the same two Actions secrets; `private` is a standalone
repo — no secrets, no dispatch, no protection. Today both slots hold the same
account-wide token (a single master key); the naming is the scheme — when you
tighten access later, fill each slot with its own scoped token and the workflows
already reference the right slot.

| Slot | Meaning | Consumed by |
| --- | --- | --- |
| `GH_TOKEN_REPO_READ` | read this repo | *(reserved)* |
| `GH_TOKEN_REPO_WRITE` | write this repo — the slot used to dispatch/PR into other repos | `update-status.yml` (listener) · `repo-status-notify.yml` + per-repo `update-status.yml` callers (dispatch) · `release.yml` auto-tag |

Set both slots with the current master token on the public repos:

```bash
TOKEN="$(gh auth token)"
for slot in GH_TOKEN_REPO_READ GH_TOKEN_REPO_WRITE; do
  for r in control-plane interview browser-extensions radar-alerts browser-games skibiribab; do
    gh secret set "$slot" -R "skibiribab/$r" --body "$TOKEN"
  done
done
```

`cli repo status` uses `GH_TOKEN` and falls back to the local `gh auth token`, so
local runs need no secret at all.

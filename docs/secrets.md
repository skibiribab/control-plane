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
  -v "$PWD:/repo" -w /repo binarylifter/gardusig-cli:1.2.0 gh issue pick
```

For local use, export in your shell or add to `~/.profile`; inside GitHub
Actions, use secrets directly as env (`-e GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}`).

# OpenCode (`cli opencode`)

All AI interactions go through **`cli opencode`** (base image). Deterministic git
operations stay on **`cli git`**.

## Commands

| Command | Purpose |
| --- | --- |
| `cli opencode setup` | print the env vars to export (API key + model) |
| `cli opencode plan\|summarize\|code\|categorize "prompt"` | one-shot prompt tiers |
| `cli opencode chat new <name>` / `chat distill <s>` / `chat categorize <s>` | chat sessions (local artifacts) |
| `cli opencode <args...>` | passthrough to the opencode CLI |

## Setup (env only)

`cli opencode setup` checks `DEEPSEEK_API_KEY` and prints the `export` lines to
add (default model via `CLI_OPENCODE_MODEL`). No config files are written.

```bash
cli opencode setup
export DEEPSEEK_API_KEY=<your-key>
export CLI_OPENCODE_MODEL=deepseek/deepseek-reasoner
```

In Docker, pass the key with `-e DEEPSEEK_API_KEY=...`. `OPENCODE_CONFIG` may
point at an existing opencode config.

## Related

- [gh.md](gh.md) — AI recipes (`cli gh issue plan`, `cli gh craft pr`). Prompts
  demand a **single complete execution** per pass and forbid running
  linters/tests; plan and exec each repeat 3× (`CLI_GH_PLAN_ROUNDS`,
  `CLI_GH_EXEC_RUNS`).
- [git.md](git.md) — deterministic git commands

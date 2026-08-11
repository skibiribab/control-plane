# GitHub (`cli gh`)

`cli gh` is a passthrough to the `gh` CLI plus AI recipes, issue CRUD, and
Projects v2 management. Runs in the **base** image (git + gh + opencode).

## Passthrough

Any `gh` subcommand works as-is:

```bash
cli gh issue list --state open --limit 10 --json number,title --jq '.[]'
cli gh pr view 5
cli gh api /repos/owner/repo
```

Requires `gh` auth (local `gh auth login`) or `GITHUB_TOKEN`/`GH_TOKEN`.

## Issue CRUD (typed wrappers over `gh issue create/edit/delete`)

| Command | Notes |
| --- | --- |
| `cli gh issue create --title T [--body B] [--label L] [--assignee A] [--repo R]` | parent/child credit-guarded for epic/child titles |
| `cli gh issue update <N> [--title T] [--body B] [--add-label L] [--remove-label L] [--state open\|closed] [--repo R]` | view-first |
| `cli gh issue delete <N> [--repo R]` | |
| `cli gh issue comment <N> --body B [--repo R]` | credit-checked **before** crafting/sending |

## Projects v2 (via `gh api graphql`, no native gh subcommand)

| Command | What it does |
| --- | --- |
| `cli gh project list [--owner O]` | list Projects v2 (id, number, title, url) |
| `cli gh project view <N> [--owner O]` | project + items (issue number/title) |
| `cli gh project create --title T [--owner O]` | create a project |
| `cli gh project update <N> --title T [--owner O]` | rename |
| `cli gh project delete <N> [--owner O]` | delete |
| `cli gh project item list <N> [--owner O]` | list items |
| `cli gh project item add <N> --issue <issueN> [--repo R] [--owner O]` | add an issue to a project |
| `cli gh project item remove <N> <itemId> [--owner O]` | remove an item |

`--owner` defaults to the current repo's owner. Field editing is not included.

## AI recipes

| Command | What it does |
| --- | --- |
| `cli gh issue pick` | deterministic next open issue |
| `cli gh issue plan --issue N [--rounds N]` | opencode plan loop; **default 3 rounds**, final = one single-execution plan (no lint/test) |
| `cli gh craft pr [--issue N]` | plan(3×) → exec(3×) → commit → PR → issue comment; credit-guarded at every write |
| `cli gh release <tag> <version>` | create a GitHub release |
| `cli gh policy list` | print merge policy (`pr-merge`) |

AI needs `opencode` + `DEEPSEEK_API_KEY`. Prompts explicitly forbid running
linters/tests and demand a single complete execution.

```bash
cli opencode setup
cli gh issue pick
cli gh issue plan --issue 5
cli gh craft pr --issue 5
```

## Limits — pre-flight rate limiters

Every write checks its limit **before** doing work (counting is a cheap `gh`
read; crafting AI text / sending only happens with available credit).

| Env | Default | Meaning |
| --- | --- | --- |
| `CLI_GH_PLAN_ROUNDS` | 3 (max 5) | opencode plan rounds |
| `CLI_GH_EXEC_RUNS` | 3 (max 5) | opencode execution passes |
| `CLI_GH_MAX_PR` | 3 | max open PRs |
| `CLI_GH_MAX_COMMITS_PR` | 10 | max commits per PR |
| `CLI_GH_MAX_COMMENTS_PR` | 5 | max comments per PR |
| `CLI_GH_MAX_COMMENTS_ISSUE` | 32 | max comments per issue |
| `CLI_GH_MAX_PARENTS` | 8 | max parent (epic) issues |
| `CLI_GH_MAX_CHILDREN` | 16 | max children per parent |

Parents are detected by the `epic` label **or** a `^N —` title; children by the
`child-of:<N>` label **or** a `^N.` title (both conventions, union).

## See also

- [commands.md](commands.md) · [opencode.md](opencode.md) · [install.md](install.md)

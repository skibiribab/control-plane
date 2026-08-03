# ai-coder build plan — epic & issue tree

Every file below is one epic. Each epic contains its **parent issue body** plus the
full bodies of its **child issues**, shaped to a shared template so they can be
promoted to real GitHub issues 1:1.

Prefix `E##` = recommended working order.

## Index

| File | Epic | Children |
|---|---|---|
| `E01-foundation.md` | Foundation — scaffold & workflow conventions | E01-1..E01-4 |
| `E02-issue-workflows.md` | issue-* — backlog & planning | E02-1..E02-4 |
| `E03-pr-workflows.md` | pr-* — implement, fix, review, janitor | E03-1..E03-4 |
| `E04-distribution.md` | Distribution — onboard any repo | E04-1..E04-3 |
| `E05-ai-layer.md` | AI invocation layer | E05-1..E05-3 |
| `E06-loop-protection.md` | Loop protection & guardrails | E06-1..E06-3 |
| `E07-observability.md` | Observability | E07-1..E07-3 |
| `E08-security.md` | Security & secrets | E08-1..E08-3 |
| `E09-testing.md` | Testing & validation | E09-1..E09-3 |
| `E10-expansion.md` | Expansion backlog | E10-1..E10-2 |

## Shared child-issue template

```markdown
### Context
why it exists, links

### Goal
one sentence

### Tasks (what to do next, ordered)
- [ ] ...

### Acceptance criteria
- [ ] ...

### Depends on
- #E##-##

### Labels
ai/<domain>, ai/<stage>
```

Epic (parent) bodies add a `Children` section listing ids + status.

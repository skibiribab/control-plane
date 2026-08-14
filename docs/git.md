# Git commands (`cli git`)

`cli git` is a passthrough to the `git` CLI plus thin composite helpers and
archive/backup operations. All run in the **orphanage** image.

## Passthrough

Any `git` subcommand works as-is:

```bash
cli git status
cli git log --oneline -10
cli git branch -a
cli git diff HEAD~1 HEAD
```

## Composite helpers

```bash
cli git branch current            # current branch name
cli git branch list               # git branch --list
cli git log oneline --base main --head feature   # git log --oneline main..feature
cli git diff stat --base main --head feature     # git diff --stat main feature
cli git rev-list count --base main --head feature
```

## Archive / backup

```bash
cli git zip <tag>                 # git archive zip -> dist/<tag>.zip
cli git export [--tag T] [--out F]  # git archive tar.gz of the repo
cli git backup [PATH] [--password P] [--out F]  # zip archive of a tree
cli git restore <archive> [--into DIR] [--password P]  # extract zip/tar
```

# Stacked Pull Requests

Use a stack when each reviewable change depends on the layer below it. Prefer GitHub's official `github/gh-stack` extension for same-repository linear stacks. Stacked pull requests and the extension are public preview, so inspect current help before automation.

## Setup

Current GitHub quickstart requires GitHub CLI 2.90.0 or later and Git 2.20 or later.

```bash
gh --version
git --version
gh auth status
gh extension install github/gh-stack
gh stack --help
```

## Native workflow

```bash
# Start first layer from main
gh stack init --base main layer-1
# Make and commit layer-1 changes

# Add dependent layer
gh stack add layer-2
# Make and commit layer-2 changes

# Push branches, create draft PRs with chained bases, and link non-interactively
gh stack submit --auto

# Inspect branch order, PR links, status, and commits
gh stack view
```

To adopt existing branches or PRs, list branches from bottom to top. Missing PRs are created as drafts; `--open` makes them ready for review.
Pass `--open` to `gh stack submit` only when every new PR should be ready for review.

```bash
gh stack link --base main layer-1 layer-2
gh stack link --base main --open layer-1 layer-2
```

Verify every layer's base and head after submission or linking:

```bash
gh pr list --json number,title,baseRefName,headRefName,state
```

## Update and merge

After changing a lower layer, rebase dependent layers, then push the stack:

```bash
gh stack rebase --upstack
gh stack push
```

After layers merge, synchronize local metadata and remove merged branches:

```bash
gh stack sync --prune
```

Merge bottom-up. `gh stack merge <PR>` atomically merges through the selected layer; selecting the top PR merges the whole stack. Merge queues preserve stack order.

## Core `gh pr` fallback

Use chained bases when the preview extension is unavailable:

```bash
git switch -c layer-1 main
# Make, commit, and push layer-1
git push -u origin layer-1
gh pr create --base main --head layer-1

git switch -c layer-2 layer-1
# Make, commit, and push layer-2
git push -u origin layer-2
gh pr create --base layer-1 --head layer-2
```

After a lower PR merges, inspect the next PR, retarget it if needed, then update it from its new base:

```bash
UPPER_PR=456
gh pr view "$UPPER_PR" --json baseRefName,headRefName
gh pr edit "$UPPER_PR" --base main
gh pr update-branch "$UPPER_PR" --rebase
```

## Guardrails

- Native stacks require linear history and branches in one repository; cross-fork stacks and GitHub Desktop are unsupported.
- Changing a PR base can remove commits from the timeline and make review comments outdated. Verify the diff after retargeting.
- Server-side stack rebases create unsigned commits. Use local `gh stack rebase` when commit signatures must remain valid.
- Preview commands may change. Re-check `gh stack --help` and the official command reference before scripting them.
- In a non-interactive session, a diverged `gh stack sync` exits successfully without updating anything. Verify with `gh stack view` after sync.

## Official documentation

- https://docs.github.com/en/pull-requests/get-started/stacked-prs-quickstart
- https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands
- https://docs.github.com/en/pull-requests/reference/stacked-pull-requests
- https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests
- https://cli.github.com/manual/gh_pr_create
- https://cli.github.com/manual/gh_pr_edit
- https://cli.github.com/manual/gh_pr_update-branch

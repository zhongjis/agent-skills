# Stacked Pull Requests

Use a stack when each reviewable change depends on the layer below it. GitHub stacks are native objects, but CLI management uses the separate official `github/gh-stack` extension, not core `gh pr stack`. Stacked pull requests and the extension are public preview; inspect current help before automation. [1][2][3]

## Setup

Current GitHub quickstart requires GitHub CLI 2.90.0 or later and Git 2.20 or later. [1]

```bash
gh --version
git --version
gh auth status
gh extension install github/gh-stack
gh stack --help
```

## Extension workflow

The following creates draft PRs with `--auto`; interactive `gh stack submit` creates new PRs ready for review by default. [2]

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

To adopt existing branches or PRs, list branches from bottom to top. `gh stack link` creates missing PRs as drafts by default. On either `submit` or `link`, `--open` marks both new and existing PRs ready for review; use it only when all affected PRs should be ready. [2]

```bash
gh stack link --base main layer-1 layer-2
gh stack link --base main --open layer-1 layer-2
```

Verify every layer's base and head after submission or linking:

```bash
gh pr list --json number,title,baseRefName,headRefName,state
```

## Update and merge

After changing a lower layer, rebase dependent layers, then push the stack: [2]

```bash
gh stack rebase --upstack
gh stack push
```

After layers merge, synchronize local metadata and remove merged branches: [2]

```bash
gh stack sync --prune
```

Merge bottom-up. `gh stack merge [stack-number|pr-number]` resolves a numeric argument as a stack first, then as a PR. A selected PR atomically merges through that layer; selecting the top PR or the whole stack merges all layers. Confirm the resolved target before proceeding. Merge queues preserve stack order. [2][3]

## Core `gh pr` fallback

Use chained bases when the preview extension is unavailable: [5]

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

After a lower PR merges, inspect the next PR, retarget it if needed, then update it from its new base: [6][7]

```bash
UPPER_PR=456
gh pr view "$UPPER_PR" --json baseRefName,headRefName
gh pr edit "$UPPER_PR" --base main
gh pr update-branch "$UPPER_PR" --rebase
```

## Guardrails

- Native stacks require linear history and branches in one repository; cross-fork stacks and GitHub Desktop are unsupported. [3]
- Changing a PR base can remove commits from the timeline and make review comments outdated. Verify the diff after retargeting. [6]
- Server-side stack rebases create unsigned commits. Use local `gh stack rebase` when commit signatures must remain valid. [4]
- Preview commands may change. Re-check `gh stack --help` and the official command reference before scripting them. [2]
- In a non-interactive session, a diverged `gh stack sync` exits successfully without updating anything. Verify with `gh stack view` after sync. [2]

## Sources:

[1] Stacked PRs quickstart (https://docs.github.com/en/pull-requests/get-started/stacked-prs-quickstart)
[2] Stacked PRs CLI commands (https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands)
[3] Stacked pull requests (https://docs.github.com/en/pull-requests/reference/stacked-pull-requests)
[4] Managing stacked pull requests (https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests)
[5] gh pr create manual (https://cli.github.com/manual/gh_pr_create)
[6] gh pr edit manual (https://cli.github.com/manual/gh_pr_edit)
[7] gh pr update-branch manual (https://cli.github.com/manual/gh_pr_update-branch)

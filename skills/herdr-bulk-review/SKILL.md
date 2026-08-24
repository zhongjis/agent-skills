---
name: herdr-bulk-review
description: "Fan out one pi code-review-v2 agent per pull request across Herdr worktrees — from a Jira/JQL filter or an explicit PR list — then monitor each agent to completion, post its verdict, prune approved worktrees, and re-review PRs that received new commits."
disable-model-invocation: true
---

# Herdr bulk review

Review many PRs at once by giving each its own **worktree-per-PR**: an isolated Herdr worktree checked out at the PR head, running one `pi` agent that reviews with `code-review-v2`. You **dispatch** every PR (worktree + agent + prompt), let each agent **settle** (reach `done`), then fan back in to post verdicts, prune, and re-review.

This layers on the **herdr control skill** (`herdr --skill`): that skill owns the CLI mechanics, this one owns the bulk fan-out and the failure cache that only surfaces at scale. Each dispatched agent loads `code-review-v2` itself — you orchestrate here, you never review.

## Preconditions

- `test "${HERDR_ENV:-}" = 1` — you must run inside a Herdr-managed pane. If it fails, stop: Herdr cannot be driven from outside it.
- `gh auth status` resolves, and `gh api user -q .login` is the identity that will post. GitHub rejects a formal `APPROVE` / `REQUEST_CHANGES` when that login authored the PR, so check `gh pr view <n> --json author` and fall back to `COMMENT` only for self-authored PRs.
- Run from the target repo checkout so `git` and `gh` resolve it. Keep your own orchestrator pane (`$HERDR_PANE_ID`) — never start an agent in it.

## Dispatch recipe (one PR)

The atomic unit. Every command form here is load-bearing — the exact form encodes a failure that bit at scale.

1. **Create the worktree at the PR head.** `git fetch origin --prune`, then `herdr worktree create --branch "$B" --base "origin/$B" --no-focus`, where `B` is the PR head branch (`gh pr view <n> --json headRefName`). Read the new pane from `.result.root_pane.pane_id` and the checkout path from `.result.worktree.path`.
2. **Force HEAD to the PR head.** `worktree create --base` is **ignored when a local branch `$B` already exists** — it checks out that stale local branch instead. So `git -C <path> reset --hard "origin/$B"` after create (a no-op when already correct, safe because the checkout is clean) and confirm `git -C <path> rev-parse HEAD` equals `origin/$B`. Reviewing the wrong commit is the worst silent failure in this workflow.
3. **Start the agent, retrying through warm-up.** `herdr agent start review-<n> --kind pi --pane <pane> --timeout 120000`. A freshly created pane runs shell init (zshrc, direnv) before it is an **available shell**, so a create→start back-to-back returns `agent_pane_busy`. Retry on that error with `sleep 4`, up to ~5 times; the pane becomes available once init finishes.
4. **Submit the prompt — bare.** `herdr agent prompt review-<n> "\$skill:code-review-v2 <pr-url> ulw"` (the literal string, `$` escaped so the shell keeps it). Use the plain form only: `--until working` submits nothing (silent no-op) and `--wait` blocks until the entire review finishes. A bare prompt moves the agent to `working` — confirm with `herdr agent get review-<n>`.

Name every agent `review-<pr-number>` so PR ↔ agent ↔ workspace stays legible through every later phase.

## Run

### 1. Build the PR list

Start from explicit PR numbers, or resolve them from Jira: query the JQL with the `jira-integration` skill, then link each ticket to its PR. Jira's dev-status panel is usually empty — the reliable link is the PR title or branch carrying the ticket key, matched with `gh pr list`.

### 2. Fan out

Dispatch every PR with the recipe above — `references/loops.md` § dispatch runs it as a loop. Sequential is fine: it naturally staggers pi boots and the warm-up retry absorbs the rest.
**Done when:** every PR has a worktree with `HEAD == origin/<branch>` and a `working` agent.

### 3. Monitor and post

pi renders on the terminal's **alt screen**, so read a transcript with `herdr agent read <name> --source visible` — `recent-unwrapped` returns empty. An agent that already ran and now shows `idle`/`done` has **settled**; `code-review-v2` ends on a verdict and then pauses, asking permission before it writes to GitHub. Instruct each settled-but-unposted agent to post one atomic PR review with the event matching its verdict (`references/loops.md` § monitor). Then confirm on GitHub — a review whose `author.login` is your `gh` identity — rather than trusting the agent's self-report.
**Done when:** every agent has settled and every verdict is posted (verified on GitHub).

### 4. Prune approved

Remove the worktrees whose posted verdict is `APPROVED` — they need no follow-up. `herdr worktree list` is scoped to the calling pane and can read empty; `git worktree list` is **ground truth**. Remove by explicit workspace id (map it from `herdr agent list`): `herdr worktree remove --workspace <ws> --force` drops the git worktree, closes the workspace, and kills its agent in one call. Confirm the branch is gone from `git worktree list` and its path is off disk.
**Done when:** every `APPROVED` PR's worktree is absent from `git worktree list`.

### 5. Re-review updated PRs

A kept PR earns another pass once its author pushes fixes: it needs re-review when the PR's newest commit `committedDate` is later than your last posted review's `submittedAt` (`gh pr view <n> --json reviews,commits`). For each, `git fetch`, `git -C <path> reset --hard "origin/<branch>"` to the new head (verify HEAD), then re-prompt the **same** agent with the bare `code-review-v2` prompt. Reusing the agent is deliberate: its prior context lets `code-review-v2` run its incremental path and check whether the earlier findings were addressed.
**Done when:** every PR whose head postdates its last review has been re-dispatched.

## References

- `references/loops.md` — ready-to-run bash loops for each phase (dispatch, monitor + post, prune approved, detect + re-review), parameterized by repo and PR list.

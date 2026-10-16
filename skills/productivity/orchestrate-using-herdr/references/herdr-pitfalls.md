# Herdr pitfalls

Traps that `herdr --skill` and `--help` do not mention, each found in real runs.

- **Read IDs from JSON.** `worktree create` returns the pane at `.result.root_pane.pane_id` and the checkout at `.result.worktree.path`; `pane split` returns `.result.pane.pane_id`.
- **`worktree create --base` is ignored when the local branch already exists**: Herdr checks out the stale local branch. When the worktree must sit at a remote head, `git fetch` first, then `git -C <path> reset --hard origin/<branch>` on the fresh, clean checkout and confirm `git -C <path> rev-parse HEAD` equals `origin/<branch>`.
- **A fresh pane is busy during shell init** (zshrc, direnv). `agent start` right after `worktree create` returns `agent_pane_busy`; retry after ~4 s, up to ~5 times.
- **Prompt bare.** `agent prompt <name> "<text>"` submits and returns. `--until working` submits nothing; `--wait` blocks until the whole task finishes. Confirm with `agent get` that the agent moved to `working`.
- **`herdr worktree list` is scoped to the calling pane** and can read empty; `git worktree list` is ground truth for what exists.
- **Remove by workspace.** `herdr worktree remove --workspace <ws> --force` removes the git worktree, closes the workspace, and kills its agent in one call; map the workspace from `herdr agent list` (the `pane_id` prefix). Confirm the path is gone from `git worktree list` and from disk.
- **Escape `$` in prompts** passed through a shell: `"\$skill:code-review <url>"`.

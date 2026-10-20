# Preflight

Run per task, before its worker works. Each trap below was found in real runs; `herdr --skill` and `--help` do not mention them. **Done when** the worker has accepted its brief and moved to `working`.

1. **Resolve the source.** Run `herdr worktree list` from the current cwd and read `source_checkout_path` (or `source_workspace_id`). The list is scoped to the calling pane and can read empty; then use the parent of `git rev-parse --path-format=absolute --git-common-dir`. Create from that parent source, never from a linked worktree's cwd; use the current worktree only when the user asks. If the source stays unresolved, stop.
2. **Pick the base.** The agreed base, unless the task depends on another. Dependent tasks form one `gh stack` rooted at the agreed base, each branch based on its prerequisite; carry branch and base identities into briefs and maintain the stack as dependencies change. Authorized publication opens PRs from the same branches and worktrees, never a parallel set; keep backup refs when recovery points are needed.
3. **Create the worktree.** Keep the repository's branch convention; name the directory with `--path <stem>` (see Names in `SKILL.md`), give a friendly `--label` (`A2A-140 Cache keys`), and pass `--no-focus`. Read IDs from the JSON: the pane at `.result.root_pane.pane_id`, the checkout at `.result.worktree.path`. `--base` is ignored when the local branch already exists: when the worktree must sit at a remote head, `git fetch`, then `git -C <path> reset --hard origin/<branch>` on the fresh, clean checkout, and confirm `git -C <path> rev-parse HEAD` equals `origin/<branch>`.
4. **Start the worker** in the returned root pane. Read the section for its kind in [agent-quirks.md](agent-quirks.md) first. A fresh pane is busy during shell init (zshrc, direnv): on `agent_pane_busy`, retry after ~4 s, up to ~5 times.
5. **Dispatch** the brief ([delegation-contract.md](delegation-contract.md)) bare: `agent prompt <name> "<text>"` submits and returns (`--until working` submits nothing; `--wait` blocks until the task finishes). Escape `$` for the shell (`"\$skill:code-review <url>"`). Confirm with `agent get` that the worker moved to `working`.

## Failures

A failed or uncertain worktree, startup, or prompt: report the details Herdr returned and stop that task, leaving an uncertain side effect in place.

## Cleanup

`herdr worktree remove --workspace <ws> --force` removes the git worktree, closes the workspace, and kills its agent; map the workspace from the `pane_id` prefix in `herdr agent list`. Confirm the path is gone from `git worktree list` (the ground truth) and from disk.

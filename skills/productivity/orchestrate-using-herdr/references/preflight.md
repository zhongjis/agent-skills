# Preflight

Run per task, before its worker works. Each trap below was found in real runs; `herdr --skill` and `--help` do not mention them. **Done when** the worker has accepted its brief and moved to `working`.

1. **Resolve the source.** Run `herdr worktree list` from the current cwd and read `source_checkout_path` (or `source_workspace_id`). The list is scoped to the calling pane and can read empty; then use the parent of `git rev-parse --path-format=absolute --git-common-dir`. Create from that parent source, never from a linked worktree's cwd; use the current worktree only when the user asks. If the source stays unresolved, stop.
2. **Pick the base.** The agreed base, unless the task depends on another. Dependent tasks follow the landing shape from `land-change`: a GitHub stack when each layer lands alone, otherwise draft layers plus one landing PR. For `gh stack` mechanics, read the gh skill's `stacked-prs.md`. Carry branch and base identities into briefs and maintain dependencies as they change. Authorized publication opens PRs from the same branches and worktrees, never a parallel set; keep backup refs when recovery points are needed.
3. **Create the worktree.** Use `herdr worktree create` with `--branch` following the repository's branch convention, the selected `--base`, a friendly `--label` (`A2A-140 Cache keys`), and `--no-focus`. Never pass `--path` to `herdr worktree create`, and never create a worktree inside the source checkout: relative paths resolve against that checkout. Omit `--path` to use Herdr's default `~/.herdr/worktrees/<repo>/<branch>`. Read the actual checkout location from `.result.worktree.path` and the pane ID from `.result.root_pane.pane_id`; do not predict either. `herdr worktree open` works only for existing worktrees; to check out an existing branch without a worktree, use `herdr worktree create --branch <existing>`. `--base` is ignored when the local branch already exists: when the worktree must sit at a remote head, `git fetch`, then `git -C <path> reset --hard origin/<branch>` on the fresh, clean checkout, and confirm `git -C <path> rev-parse HEAD` equals `origin/<branch>`.
4. **Start the worker** in the returned root pane. Read the section for its kind in [agent-quirks.md](agent-quirks.md) first. A fresh pane is busy during shell init (zshrc, direnv): on `agent_pane_busy`, retry after ~4 s, up to ~5 times.
5. **Dispatch** the brief ([delegation-contract.md](delegation-contract.md)) from a file, bare: `herdr agent prompt <name> "$(cat <brief-file>)"` submits and returns (`agent prompt --until working` submits nothing; `--wait` blocks until the task finishes); command substitution keeps `$skill:` text literal. Confirm with `herdr agent wait <name> --until working --until blocked --timeout 15000`; on timeout, check `agent get` and treat the prompt as uncertain, never re-send.

## Failures

A failed or uncertain worktree, startup, or prompt: report the details Herdr returned and stop that task, leaving an uncertain side effect in place.

## Cleanup

`herdr worktree remove --workspace <ws> --force` removes the git worktree, closes the workspace, and kills its agent; map the workspace from the `pane_id` prefix in `herdr agent list`. Confirm the path is gone from `git worktree list` (the ground truth) and from disk.

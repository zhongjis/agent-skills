# Reap

Closing a worker leaves its detached daemons running (browsers, prettierd, Compose containers), so reap before removing anything. Log `reaped` with what was stopped. `<sel>` is `id:<worktreeId>` from the worktree creation receipt.

- **Keep worker**, for a task that can still get follow-ups (PR open, review or CI pending): `scripts/reap-worker.sh <worktree> <name> --keep-agent` closes the worker's agent-browser namespace, removes Compose projects whose working directory is inside the worktree, and stops listening processes (dev servers) running there. The worker and its worktree stay. Under supervision, retain the dispatch explicitly (`orca orchestration worker-retain --dispatch <id>`) instead of releasing it.
- **Finished**, for a task whose PR merged or closed, or whose result the user accepted:
  1. Under supervision, `orca orchestration worker-release --dispatch <id> --json`. Never substitute `terminal close` for an uncertain release; follow its recovery receipt.
  2. Close the worker's Orca browser tabs: for each `tabs[].browserPageId` from `orca tab list --worktree <sel> --json`, run `orca tab close --worktree <sel> --page <id>`.
  3. `orca terminal close --worktree <sel> --all`.
  4. `scripts/reap-worker.sh <worktree> <name>` also stops every process running inside the worktree.
  5. `orca worktree rm --worktree <sel> --force --json` removes the worktree and its merged local branch; an unmerged branch stays. Confirm the path is gone from `git worktree list` (the ground truth) and from disk.
- Terminal handles are runtime-scoped: after an Orca restart or `terminal_handle_stale`, re-list with `orca terminal list --worktree <sel> --json` and continue with the replacement handle only.
- On any blocker, keep the PR, worktree, and evidence intact.
